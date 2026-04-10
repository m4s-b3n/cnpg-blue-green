# Blue/Green PostgreSQL Deployments with CloudNativePG

Zero-downtime database deployments using [CloudNativePG](https://cloudnative-pg.io/)
distributed topology on Kubernetes.

Built for the conference talk:
**"Blue/Green für Datenbanken: Zero Downtime Deployments mit Kubernetes und CNPG"**

## Architecture

```
┌─────────────────────────── k3d cluster: cnpg-demo ────────────────────────────┐
│                                                                               │
│  ┌─── cnpg-system ───┐     ┌───────── cnpg-demo ──────────────────────────┐   │
│  │  CNPG Operator     │    │                                              │   │
│  └────────────────────┘    │  ┌──────────┐          ┌──────────┐          │   │
│                            │  │ pg-blue  │ ◄──WAL──► │ pg-green │         │   │
│                            │  │ (primary)│  repl.    │ (standby)│         │   │
│                            │  └────┬─────┘          └──────────┘          │   │
│                            │       │                                      │   │
│                            │  ┌────┴─────┐                                │   │
│                            │  │  pg-rw   │  ◄─ routes to active primary   │   │
│                            │  │ (Service)│     via label: active="true"   │   │
│                            │  └────┬─────┘                                │   │
│                            │       │                                      │   │
│                            │  ┌────┴─────┐                                │   │
│                            │  │ demo-app │  INSERT + SELECT every 1s      │   │
│                            │  │          │  logs: WRITE ok | rows=N       │   │
│                            │  └──────────┘                                │   │
│                            └──────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────────────────┘
```

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [k3d](https://k3d.io/) (`brew install k3d` / `curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash`)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Helm](https://helm.sh/docs/intro/install/)

## Quick Start

```bash
# Full setup in one command (~5 min)
make demo

# Watch the app proving zero downtime
make logs

# Trigger blue→green switchover (run again for green→blue)
make switch

# Clean up
make teardown
```

## Step-by-Step Demo Flow

### 1. Setup infrastructure
```bash
make setup          # Creates k3d cluster + installs CNPG operator
```

### 2. Deploy Blue (primary) cluster
```bash
make deploy-blue    # Deploys pg-blue as primary via Helm
```

### 3. Configure replication
```bash
make replication    # Creates streaming_user + replication secrets
```

### 4. Deploy Green (standby) cluster
```bash
make deploy-green   # Deploys pg-green as replica of pg-blue
```

### 5. Deploy the demo app
```bash
make deploy-app     # Builds Go app, deploys to cluster, starts read/write loop
```

### 6. Watch the logs (leave running in separate terminal)
```bash
make logs
# Output:
# [2026-04-10T21:00:01Z] WRITE ok | rows=42 | latency=5ms
# [2026-04-10T21:00:02Z] WRITE ok | rows=43 | latency=4ms
# ...
```

### 7. Trigger switchover! 🎉
```bash
make switch
# Switches blue→green (or green→blue if run again)
# Watch the logs — no interruption!
```

## How It Works

### Distributed Topology Switchover

CNPG's distributed topology enables controlled demotion/promotion using tokens:

1. **Demote** the active cluster (sets `replica.primary` to the target)
2. **Acquire demotion token** from the demoted cluster's `.status.demotionToken`
3. **Promote** the standby using the token (sets `replica.promotionToken`)

The `active` label on pods allows the `pg-rw` Service to seamlessly route
traffic to whichever cluster is currently primary — no DNS changes, no app
restarts.

### Why Zero Downtime?

- PostgreSQL streaming replication keeps both clusters in sync at all times
- The `pg-rw` Kubernetes Service uses label selectors (`active: "true"`)
- During switchover, the Service instantly routes to the new primary pod
- The demo app's connection pool handles the brief TCP reconnect transparently

## Check Status

```bash
make status     # Shows clusters, pods, services, and active labels
```

## Troubleshooting

**Pods restarting during switchover?**
Check CNPG operator logs:
```bash
kubectl logs -n cnpg-system -l app.kubernetes.io/name=cloudnative-pg --tail=100
```

**Replication not working?**
Verify streaming user and secrets:
```bash
kubectl exec -n cnpg-demo $(kubectl get cluster pg-blue -n cnpg-demo -o jsonpath='{.status.currentPrimary}') -- psql -U postgres -c "SELECT * FROM pg_stat_replication;"
```

**App can't connect?**
Check service endpoints:
```bash
kubectl get endpoints pg-rw -n cnpg-demo
```

## References

- [CloudNativePG Documentation](https://cloudnative-pg.io/docs/)
- [CNPG Distributed Topology](https://cloudnative-pg.io/docs/1.25/replica_cluster/#distributed-topology)
- [k3d Documentation](https://k3d.io/)
