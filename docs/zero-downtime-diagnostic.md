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

# 4. Trigger switchover (with PgBouncer pause — currently works)
make switch

# 5. To reproduce the disruption WITHOUT PgBouncer pause/resume:
make switch-no-pause
# You'll see WRITE FAIL errors for ~10–20s
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

### 1. Is manual service patching the right approach?

We patch `pg-rw`'s `cnpg.io/cluster` selector manually after promotion. Is there a
CNPG-native mechanism that should handle this automatically? We saw `inheritedMetadata`
in the docs — should we be using that to keep a stable label on "the current primary
pod" that our service can select without any manual intervention?

### 2. Is there a natural quiescence point we should be targeting?

Between step 2 (demote blue) and step 6 (green writable), there's a window where
no cluster is a writable primary. Does CNPG provide a status condition or event
we should wait for to know "green is now the primary and ready for writes" before
routing traffic? We're currently polling `pg_is_in_recovery()` which feels like a
hack.

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
