# CNPG Blue/Green Switchover — Diagnostic Request for Leonardo Cecchi

**Context:** We met at KubeCon Europe 2026. I'm working on a blue/green PostgreSQL
deployment demo for a conference talk and a customer use case. You mentioned there
should be no noticeable disruption during CNPG distributed topology switchover —
but we observe one and currently work around it with PgBouncer PAUSE/RESUME.
I'd love your help understanding what we're doing wrong.

---

## TL;DR — The Problem

We can't achieve near-zero downtime during switchover without manually pausing
PgBouncer first. Without the PAUSE, the demo app logs `WRITE FAIL` errors for
several seconds during switchover. You said that shouldn't be necessary with
CNPG's distributed topology. **We think something in our configuration is off.**

---

## What We Have

A k3d (local Kubernetes) cluster running two CNPG `Cluster` resources
(`pg-cluster-blue` and `pg-cluster-green`) configured for distributed topology
switchover. A Go demo app writes to PostgreSQL every second via PgBouncer.

### Architecture

```
demo-app (Go, 1 write/s)
    └── pgbouncer (session pool, port 5432)
            └── pg-rw (ClusterIP Service, label selector)
                    ├── pg-cluster-blue  (primary or standby)
                    └── pg-cluster-green (primary or standby)
```

- **CNPG version:** 1.25+
- **PostgreSQL:** 16.6
- **One instance per cluster** (no HA replicas within each cluster, just cross-cluster streaming)
- **Service `pg-rw`** uses `cnpg.io/cluster` label selector — manually patched during switchover

---

## Current Setup in Detail

### Helm Values — Blue Cluster

```yaml
# helm/values/blue-values.yaml
cluster:
  name: pg-cluster-blue
  bootstrapMode: initdb
  imageName: ghcr.io/cloudnative-pg/postgresql:16.6
  instances: 1
  smartShutdownTimeout: 30
  switchoverDelay: 0
  stopDelay: 60
  primaryUpdateMethod: switchover

distributedTopology:
  enabled: true
  primary: pg-cluster-blue    # "I am primary"
  source: pg-cluster-green
  self: pg-cluster-blue
  promotionToken: ""          # set during promote step

externalClusters:
  - name: pg-cluster-blue
    connectionParameters:
      host: pg-cluster-blue-rw.cnpg-demo.svc.cluster.local
      user: streaming_user
      dbname: postgres
      sslmode: disable
    passwordSecret:
      name: pg-cluster-blue-replica-user
      key: password
  - name: pg-cluster-green
    connectionParameters:
      host: pg-cluster-green-rw.cnpg-demo.svc.cluster.local
      user: streaming_user
      dbname: postgres
      sslmode: disable
    passwordSecret:
      name: pg-cluster-green-replica-user
      key: password
```

### Helm Values — Green Cluster

```yaml
# helm/values/green-values.yaml
cluster:
  name: pg-cluster-green
  bootstrapMode: pg_basebackup   # initially bootstrapped from blue
  instances: 1
  # (same timing settings as blue)

distributedTopology:
  enabled: true
  primary: pg-cluster-blue    # "blue is primary"
  source: pg-cluster-blue
  self: pg-cluster-green
  promotionToken: ""
```

### CNPG Cluster CRD (rendered from Helm)

To inspect the raw CRD, run:
```bash
helm template pg-blue helm/pg-cluster -f helm/values/blue-values.yaml
helm template pg-green helm/pg-cluster -f helm/values/green-values.yaml
```

The relevant `spec.replica` section (rendered when `distributedTopology.enabled=true`):
```yaml
spec:
  replica:
    primary: "pg-cluster-blue"   # which cluster is primary
    source: "pg-cluster-green"   # replication source
    self: "pg-cluster-blue"      # this cluster's identity
    # promotionToken: "..."      # set only during promotion
```

### Service `pg-rw` — How Traffic is Routed

**Initial state** (blue is active):
```yaml
spec:
  selector:
    cnpg.io/podRole: instance
    role: primary
    cnpg.io/cluster: pg-cluster-blue   # ← manually patched during switch
```

### PgBouncer Configuration

```
POOL_MODE=session
DB_HOST=pg-rw           # points at the ClusterIP service
AUTH_TYPE=plain
MAX_CLIENT_CONN=100
DEFAULT_POOL_SIZE=25
DNS_MAX_TTL=0           # no DNS caching
```

---

## What the Demo App Does

A Go app (`app/main.go`) connects via PgBouncer and:
1. Inserts a row every second: `INSERT INTO demo_log (msg) VALUES ($1)`
2. Reads the row count: `SELECT count(*) FROM demo_log`
3. Logs `WRITE ok | rows=N | latency=Xms` or `WRITE FAIL | error=...`

Connection pool settings in the app:
```go
db.SetMaxOpenConns(5)
db.SetMaxIdleConns(2)
db.SetConnMaxLifetime(30 * time.Second)
db.SetConnMaxIdleTime(5 * time.Second)
```

---

## What Happens During Switchover (Current Script)

Our switchover script (`scripts/05-switchover.sh`) does this:

```
1. PAUSE PgBouncer  → all client queries queue up (no errors)
2. helm upgrade <blue> --set distributedTopology.primary=pg-cluster-green
   → blue demotes itself
3. Poll .status.demotionToken until available (typically 5–15s)
4. helm upgrade <green> --set distributedTopology.primary=pg-cluster-green \
                         --set distributedTopology.promotionToken=<token>
   → green promotes itself
5. kubectl patch svc pg-rw → change selector to pg-cluster-green
6. Poll until pg-rw endpoint is writable (pg_is_in_recovery() = false)
7. RESUME PgBouncer → queued queries flow to new primary
```

**Total duration:** ~15–30 seconds (most of it waiting for demotion token)

**Without PAUSE:** The app logs `WRITE FAIL` errors for the duration of steps 2–6.
The error is typically `pq: cannot execute INSERT in a read-only transaction` or
a connection error as the old primary becomes read-only before the new one is ready.

---

## Reproduction Steps

### Prerequisites

- Docker, k3d, kubectl, Helm 3

### Full Demo

```bash
# 1. Clone the repo
git clone https://github.com/m4s-b3n/cnpg-blue-green
cd cnpg-blue-green

# 2. Full setup (~5 min)
make demo

# 3. Watch app logs in a separate terminal
make logs
# Expected: [2026-xx-xx] WRITE ok | rows=N | latency=Xms

# Switch to another shell, still watch the shell with the logs

# 4. Trigger switchover (with PgBouncer pause — currently works)
make switch

# 5. To reproduce the disruption WITHOUT PgBouncer pause/resume:
make switch-no-pause
# You'll see WRITE FAIL errors for a few seconds
```

### Inspect the Raw CRDs

```bash
# Render Helm templates to see the exact CNPG Cluster specs
helm template pg-blue helm/pg-cluster -f helm/values/blue-values.yaml

# During a live demo, inspect the actual cluster status
kubectl get cluster pg-cluster-blue -n cnpg-demo -o yaml
kubectl get cluster pg-cluster-green -n cnpg-demo -o yaml

# Watch switchover state change in real time
kubectl get clusters -n cnpg-demo -w

# Check replication status
kubectl exec -n cnpg-demo pg-cluster-blue-1 -c postgres -- \
  psql -U postgres -c "SELECT * FROM pg_stat_replication;"
```

---

## Our Questions for You

We suspect something is misconfigured. Specifically:

### 1. Is there a better way to route traffic to the active primary?

We deploy our own `ClusterIP` Service (`pg-rw`) in front of both clusters so that
PgBouncer has a single stable endpoint. Its selector includes `cnpg.io/cluster: <name>`,
which we manually patch during switchover to point at the newly promoted cluster.
This works, but it's an extra step we have to orchestrate ourselves.

Is there a CNPG-native label or annotation — set automatically on whichever pod is
the distributed topology primary — that we could select on instead, so our service
would follow the active primary without any patching? We noticed `inheritedMetadata`
in the docs — could that be used to propagate a shared label like
`topology-role: primary` onto the active pod across both clusters? And critically:
would changing `inheritedMetadata` on a live cluster take effect without restarting
pods, or would it require a rolling restart?

### 2. How should we detect that promotion is complete?

After we demote the source and pass the promotion token to the target, there's a
window where no cluster is a writable primary. We need to know when the target has
finished promoting before routing traffic. Currently we poll PostgreSQL directly
via `SELECT pg_is_in_recovery()` in a loop — busy-waiting until the new primary
reports `false`.

We monitored `.status.phase` and `.status.conditions[type=Ready]` on both clusters
during a live switchover (green→blue). Here's what we observed:

```
T+0s   GREEN: phase=Applying configuration  ready=False  (demotion helm upgrade applied)
T+2s   GREEN: phase=Cluster in healthy state ready=True   (demoted, now standby)
T+4s   GREEN: demotionToken=SET                           (token available)
T+7s   BLUE:  phase=Promoting to primary cluster ready=False (promotion token applied)
T+11s  BLUE:  phase=Waiting for the instances to become active ready=False
T+27s  BLUE:  phase=Upgrading cluster        ready=False  (rolling restart of replicas)
T+29s  BLUE:  phase=Waiting for the instances to become active ready=False
T+45s  BLUE:  currentPrimary changed (pg-blue-1 → pg-blue-2, internal switchover)
T+70s  BLUE:  phase=Cluster in healthy state ready=True   (fully settled)
```

The primary was actually **writable by ~T+9s** (confirmed via `pg_is_in_recovery()`),
but `Ready=True` didn't appear until **T+70s** — because it waits for all replicas
to finish their rolling restart. So `Ready` is far too late to use as a routing signal.
And `phase=Promoting to primary cluster` is too early (promotion hasn't completed yet).

There doesn't seem to be a condition that means exactly "primary is now accepting
writes." Is there one we're missing, or is polling `pg_is_in_recovery()` the
recommended approach? Is there a Kubernetes event we could `kubectl wait` on instead?

### 3. Are our Cluster timing settings correct?

- `switchoverDelay: 0` — is this appropriate for distributed topology?
- `stopDelay: 60`, `smartShutdownTimeout: 30` — do these affect promotion speed?
- With a single instance per cluster (no local standby), are there settings that
  make the demotion token appear faster?

### 4. PgBouncer POOL_MODE

We use `session` pooling. Would `transaction` pooling handle the brief reconnect
transparently without needing PAUSE? Or is the issue deeper (the TCP connection
to the old primary becoming read-only mid-transaction)?

### 5. `sslmode: disable` in externalClusters

Is this a concern? Should replication be running with TLS? Could it affect
switchover timing?

### 6. Is there an anti-pattern we're missing?

The README claims "zero downtime" and we believe the architecture should support
it — but something is off. If you see an obvious configuration mistake, we'd love
to know.

---

## Repo Structure (Quick Reference)

```
cnpg-blue-green/
├── helm/
│   ├── pg-cluster/          # Helm chart (Chart.yaml, templates/, values.yaml)
│   └── values/
│       ├── blue-values.yaml
│       └── green-values.yaml
├── scripts/
│   ├── 00-setup.sh          # k3d cluster + CNPG operator
│   ├── 01-deploy-blue.sh
│   ├── 02-setup-replication.sh
│   ├── 03-deploy-green.sh
│   ├── 04-deploy-app.sh     # PgBouncer + demo-app + services
│   └── 05-switchover.sh     # The switchover logic
├── app/
│   ├── main.go              # Go demo app (INSERT + SELECT every 1s)
│   └── k8s/
│       ├── deployment.yaml  # demo-app deployment
│       └── pgbouncer.yaml   # PgBouncer deployment
└── Makefile                 # demo / switch / logs / teardown
```

---

Thank you for taking the time to look at this — any guidance would be hugely appreciated!
