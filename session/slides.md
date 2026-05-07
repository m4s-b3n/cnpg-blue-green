---
marp: true
theme: default
paginate: true
size: 16:9
footer: "Blue/Green for Databases — Zero Downtime Deployments with Kubernetes & CNPG"
---

<!-- _class: lead -->
<!-- _paginate: false -->
<!-- _footer: "" -->

# Blue/Green for Databases

## Zero Downtime Deployments with Kubernetes & CNPG

**Speaker Name** — Role, Company
Conference Name — Date

<!--
NOTES-35: Quick intro — name, role, what I do. "Today I'll show you how to do zero-downtime database deployments. With a live demo."
NOTES-60: Same, plus: "We'll go deep into the architecture, the switchover mechanics, connection management with PgBouncer, and I'll share the pitfalls we hit in production. Plus a live demo where we switch a running database with zero downtime."
-->

---

# About Me & Agenda

**Speaker Bio** — 2–3 bullets about your background

### Today's Roadmap

- ❌ The Problem with database deployments
- 🔵🟢 Blue/Green for Databases
- 🏗️ Architecture with CNPG
- 🔄 The Switchover — step by step
- 🎬 **Live Demo**
- 💡 Lessons Learned

<!--
NOTES-35: "Here's the roadmap. We'll move fast — the demo is the star of the show."
NOTES-60: "Here's our agenda. We'll cover each topic in depth, with extra sections on PgBouncer connection management and CI/CD integration. The demo will be more interactive — feel free to shout questions during it."
-->

---

# The Problem: Database Deployments Are Hard

<!-- Visual: CI/CD pipeline diagram with a red "X" at the database step -->

> "Everyone's got CI/CD for their apps.
> But the database? That's where pipelines break."

- Schema changes, data migrations, **stateful** workloads
- Traditional approach: maintenance window → **downtime**
- You can't just `kubectl rollout restart` a database

<!--
NOTES-35: "Everyone's got CI/CD for their apps. But the database? That's where pipelines break. Schema changes, data migrations, stateful workloads — you can't just kubectl rollout restart a database."
NOTES-60: Same opening, plus: "Let me paint the picture: Your app deploys in 30 seconds. Blue/green, canary, rolling — pick your strategy. But then comes the database migration. And suddenly everyone's scheduling a maintenance window at 2 AM on a Saturday. Why? Because databases are stateful. You can't just throw away the old one and spin up a new one. Or can you?"
-->

---

# Why Zero Downtime Matters

| SLA Target | Downtime / Year |
|-----------|----------------|
| 99.9%     | **8.7 hours**  |
| 99.95%    | 4.4 hours      |
| 99.99%    | **52 minutes** |
| 99.999%   | 5.3 minutes    |

- Every minute of downtime costs **money and trust**
- "Zero downtime" = no user-visible interruption

<!--
NOTES-35: "Zero downtime isn't a nice-to-have anymore — it's an SLA requirement. Every minute of downtime costs money and trust."
NOTES-60: "Let's talk numbers. 99.9% uptime sounds great until you realize that's almost 9 hours of downtime per year. For a payments platform or an e-commerce site, a single database migration that takes the system down for 5 minutes during peak hours can cost thousands. The goal isn't perfection — it's making deployments invisible to users."
-->

---

# Traditional Approaches (and Their Limits)

| Approach | Downtime | Rollback | Complexity |
|----------|----------|----------|------------|
| Stop-deploy-start | Minutes | Restore backup | Low |
| Rolling update | Seconds | Tricky | Medium |
| Logical replication | Near-zero | Complex | High |
| **Blue/Green** | **Zero** | **Instant** | **Medium** |

<!--
NOTES-35: "There are several approaches. Blue/Green gives us the best trade-off: zero downtime with instant rollback, at manageable complexity."
NOTES-60: "Let me walk through the alternatives. Stop-deploy-start is the classic: take it down, migrate, bring it back. Simple but painful. Rolling updates work for stateless apps but databases aren't stateless. Logical replication can get you close to zero downtime but it's complex to set up and rollback is non-trivial. Blue/Green hits the sweet spot — and with CloudNativePG, Kubernetes does the heavy lifting."
-->

---

# Blue/Green Deployment: The Concept

<!-- Visual: Classic blue/green diagram -->

```
         ┌──────────────┐
         │  Load Balancer│
         └──────┬───────┘
                │
      ┌─────────┴─────────┐
      ▼                   ▼
 ┌─────────┐        ┌─────────┐
 │  BLUE   │        │  GREEN  │
 │ (active)│        │(standby)│
 └─────────┘        └─────────┘
```

1. Two identical environments: **Blue** (active) + **Green** (standby)
2. Deploy to standby → test → **switch traffic**
3. Old environment becomes new standby
4. Rollback = just flip back

<!--
NOTES-35: "Blue/Green is simple: two environments, one active, one standby. Deploy to standby, verify, flip traffic. The old active becomes the new standby. Instant rollback = just flip back."
NOTES-60: "The Blue/Green pattern has been around for decades for stateless applications. The key insight is: you never deploy to the active system. You always deploy to the standby, verify it works, and then switch. If something goes wrong? Switch back. The standby is still there, unchanged. For stateless apps this is straightforward — spin up new containers, update the load balancer. But for databases, it's a different story..."
-->

---

# But Wait... Databases Are Different

<!-- Visual: Callout boxes with key challenges -->

- 💾 **State** — Data must be synchronized between blue and green
- 🔒 **Consistency** — No lost writes during switchover
- 🔌 **Connections** — Active connections must be handled gracefully
- 📐 **Schema** — Both clusters must be schema-compatible

> These challenges make Blue/Green for databases fundamentally harder
> than for stateless apps.

<!--
NOTES-35: "For databases, Blue/Green is harder because of state. Both clusters need the same data, you can't lose writes during the switch, and existing connections need to be handled."
NOTES-60: "This is where it gets interesting. Unlike stateless apps, databases have data. You need streaming replication to keep blue and green in sync. During switchover, you need to ensure no writes are lost — that means pausing writes briefly or using a connection proxy. And what about the 50 active connections from your app? They're pointing at the old primary. You need a strategy for all of this. That's what CloudNativePG gives us."
-->

---

# Enter CloudNativePG

<!-- Visual: CNPG logo + key features as icon grid -->

- 🐘 **Kubernetes Operator** for PostgreSQL
- 🔄 Full lifecycle: deploy, replicate, failover, backup
- 🌐 **Distributed Topology**: first-class Blue/Green support
- 🔑 Demotion/Promotion **token mechanism** for safe switchover
- 🆓 Open source, CNCF project

<!--
NOTES-35: "CloudNativePG is a Kubernetes operator for PostgreSQL. The key feature for us is Distributed Topology — it provides a built-in mechanism for Blue/Green switchover with demotion and promotion tokens."
NOTES-60: "CloudNativePG — or CNPG — is a Kubernetes operator purpose-built for PostgreSQL. It manages everything: provisioning, replication, failover, backups, monitoring. What makes it special for Blue/Green is its Distributed Topology feature. Instead of hacking together scripts to promote and demote clusters, CNPG provides a proper API: you demote one cluster, get a demotion token that proves replication is caught up, and use that token to promote the other cluster. It's a handshake protocol that guarantees data safety."
-->

---

# Architecture Overview

```
┌──────────────────── Kubernetes Cluster ────────────────────┐
│                                                            │
│  ┌─── cnpg-system ───┐                                    │
│  │   CNPG Operator   │                                    │
│  └────────────────────┘                                    │
│                                                            │
│  ┌──────────────── cnpg-demo namespace ───────────────┐    │
│  │                                                    │    │
│  │  ┌──────────┐    WAL Streaming    ┌──────────┐     │    │
│  │  │ pg-blue  │ ◄════════════════► │ pg-green │     │    │
│  │  │ (primary)│                     │ (standby)│     │    │
│  │  └─────┬────┘                     └──────────┘     │    │
│  │        │                                           │    │
│  │  ┌─────┴────┐     ┌───────────┐     ┌──────────┐  │    │
│  │  │  pg-rw   │ ◄── │ PgBouncer │ ◄── │ demo-app │  │    │
│  │  │ (Service)│     │  (proxy)  │     │  (Go)    │  │    │
│  │  └──────────┘     └───────────┘     └──────────┘  │    │
│  └────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────┘
```

<!--
NOTES-35: "Here's the architecture. Two PostgreSQL clusters managed by CNPG, connected via WAL streaming replication. The app connects through PgBouncer to the pg-rw service, which always points to the active primary. During switchover, we patch the service selector — traffic flips instantly."
NOTES-60: "Let me walk through each component. At the top, the CNPG operator watches our Cluster CRDs and manages the PostgreSQL instances. We have two clusters: pg-blue starts as primary, pg-green as standby. They're connected via PostgreSQL streaming replication — every WAL record from blue is shipped to green in real-time. The pg-rw Service is a standard Kubernetes Service with a label selector pointing to the active cluster. PgBouncer is our connection proxy — it does connection pooling but more importantly, it can PAUSE and RESUME connections. The demo app is a simple Go program that writes and reads every second — our canary in the coal mine."
-->

---

# CNPG Cluster CRD

```yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: pg-cluster-blue
spec:
  instances: 1
  postgresql:
    parameters:
      wal_level: replica
      max_wal_senders: 10
  replica:
    primary: pg-cluster-blue    # Who's the primary?
    source: pg-cluster-green    # Where to stream from?
    self: pg-cluster-blue       # Who am I?
  externalClusters:
    - name: pg-cluster-green
      connectionParameters:
        host: pg-cluster-green-rw
        user: streaming_user
```

<!--
NOTES-35: "This is the Cluster CRD — the key part is the replica section. It defines the distributed topology: who's primary, who's the replication source, and the identity of this cluster."
NOTES-60: "Here's the actual Cluster CRD. The replica block is where the magic happens. primary tells CNPG which cluster is currently the primary — this is what we change during switchover. source defines where to stream WAL from. self is the cluster's own identity. The externalClusters section defines the connection details for the partner cluster. Notice the streaming_user — that's a PostgreSQL user with REPLICATION privilege that we create during setup."
-->

---

# The pg-rw Service (Traffic Router)

<!-- Visual: Two side-by-side diagrams showing selector before/after -->

```yaml
apiVersion: v1
kind: Service
metadata:
  name: pg-rw
spec:
  selector:
    cnpg.io/cluster: pg-cluster-blue  # ← This gets patched!
  ports:
    - port: 5432
```

- Kubernetes Service with **dynamic selector**
- During switchover: `kubectl patch svc pg-rw` → new selector
- **No DNS change, no app restart** — instant traffic rerouting

<!--
NOTES-35: "The pg-rw service is our traffic router. It uses a label selector to point to the active cluster. During switchover, we patch this selector — Kubernetes instantly reroutes all new connections."
NOTES-60: "This is the elegance of the approach. The pg-rw Service doesn't care about blue or green — it just routes to whatever pod matches its selector. When we switch, we run a simple kubectl patch to change the selector from pg-cluster-blue to pg-cluster-green. Kubernetes updates the Endpoints object immediately — no TTL, no propagation delay. Any new TCP connection to pg-rw goes to the new primary. But what about existing connections? That's where PgBouncer comes in."
-->

---

# Replication Setup

<!-- Visual: Flow diagram showing pg_basebackup + WAL streaming -->

### Initial Sync
`pg_basebackup` — full physical copy of blue → green

### Continuous Sync
**WAL streaming replication** — every transaction shipped in real-time

### Credentials
- Dedicated `streaming_user` with `REPLICATION` privilege
- Credentials stored in Kubernetes Secrets

<!--
NOTES-35: "Green bootstraps from Blue using pg_basebackup — a full copy. After that, WAL streaming keeps them in sync continuously."
NOTES-60: "The replication setup has two phases. First, when we deploy pg-green, it bootstraps using pg_basebackup — this creates a full physical copy of pg-blue. After that, PostgreSQL's built-in streaming replication takes over. Every WAL record — every transaction — is shipped from blue to green in real-time. The latency is typically sub-second."
-->

---

# The Switchover: 4-Step Process

<!-- Visual: Numbered timeline or flow chart -->

```
① PAUSE PgBouncer       → Hold client connections (no errors!)

② DEMOTE active cluster → Helm upgrade: change primary

③ PROMOTE standby       → Acquire demotion token → promote

④ RESUME PgBouncer      → Patch pg-rw → reconnect → resume
```

### Total switchover time: **~15 seconds**

<!--
NOTES-35: "The switchover is four steps. Pause PgBouncer to hold connections, demote the active cluster, promote the standby with a demotion token, then patch the service and resume PgBouncer. The whole thing takes about 10–15 seconds."
NOTES-60: "Let me walk through each step in detail. This is the choreography that makes zero downtime possible."
-->

---

# Step 1: PAUSE PgBouncer

```sql
PAUSE appdb;
```

- Client connections are **held**, not dropped
- No errors on the application side — requests just **wait**
- This is the "freeze frame" before we switch

> From the app's perspective, the query just takes a bit longer.

<!--
NOTES-35: "We start by pausing PgBouncer. This holds all client connections in a queue — no errors, no timeouts, they just wait."
NOTES-60: "Step one is critical. We send PAUSE appdb to PgBouncer's admin console. This tells PgBouncer to stop sending queries to the backend PostgreSQL but keep the client connections open. From the application's perspective, the current query just takes a bit longer. No connection errors, no retries needed. This gives us a clean window to perform the actual database switchover without any client seeing an error. The pause typically lasts 10–15 seconds."
-->

---

# Step 2: DEMOTE Active Cluster

<!-- Visual: pg-blue goes from "PRIMARY 👑" to "STANDBY" -->

```bash
helm upgrade pg-blue ./pg-cluster \
  --set distributedTopology.primary=pg-green
```

- Tells CNPG: "pg-green is now the intended primary"
- pg-blue transitions: **primary → standby**
- CNPG generates a **demotion token** when complete

<!--
NOTES-35: "We run a Helm upgrade that changes who the primary is. CNPG demotes pg-blue and generates a demotion token — proof that replication is caught up."
NOTES-60: "We demote the active cluster by running a Helm upgrade that changes the distributedTopology.primary field. This tells CNPG: 'pg-green should be the primary now.' CNPG begins transitioning pg-blue from primary to standby mode. Once the transition is complete and replication is confirmed caught up, CNPG writes a demotion token to the cluster's status field. This token is crucial — it's a cryptographic proof that the standby has all the data."
-->

---

# Step 3: PROMOTE Standby

<!-- Visual: pg-green goes from "STANDBY" to "PRIMARY 👑", token being passed -->

```bash
# 1. Get the demotion token
TOKEN=$(kubectl get cluster pg-blue \
  -o jsonpath='{.status.demotionToken}')

# 2. Promote green with the token
helm upgrade pg-green ./pg-cluster \
  --set distributedTopology.promotionToken=$TOKEN
```

- 🔑 Token handshake guarantees **data consistency**
- **No data loss possible** — token proves sync

<!--
NOTES-35: "We grab the demotion token from the old primary and pass it to the new primary. This handshake guarantees zero data loss."
NOTES-60: "This is the handshake. We read the demotion token from pg-blue's status — this token encodes the WAL position where replication was confirmed in sync. We then pass this token to pg-green via a Helm upgrade setting the promotionToken. CNPG on the green side verifies the token, confirms it has all the WAL up to that point, and promotes itself to primary. This is what makes CNPG's approach safe — you can't accidentally promote a standby that's lagging behind."
-->

---

# Step 4: RESUME — Go Live!

```bash
# Patch service to point to new primary
kubectl patch svc pg-rw \
  -p '{"spec":{"selector":{"cnpg.io/cluster":"pg-green"}}}'

# Reconnect PgBouncer (drop stale backends)
RECONNECT appdb;
RESUME appdb;
```

- Service selector patched → **instant traffic reroute**
- PgBouncer drops old backends, opens new ones
- **Clients resume — zero errors!** 🎉

<!--
NOTES-35: "Finally, we patch the pg-rw service to point to pg-green, tell PgBouncer to reconnect and resume. Clients unfreeze and continue as if nothing happened."
NOTES-60: "Now we bring everything back online. First, we patch the pg-rw Kubernetes Service to change its selector from pg-cluster-blue to pg-cluster-green. This is instantaneous — Kubernetes updates the Endpoints object right away. Then we send two commands to PgBouncer: RECONNECT drops all existing backend connections to the old primary, and RESUME releases the queued client connections. Because we set DNS_MAX_TTL=0, PgBouncer immediately re-resolves the pg-rw hostname and connects to the new primary. The clients' queries flow through — zero errors in the logs."
-->

---

<!-- 60-MIN ONLY: SLIDE 17a -->

# PgBouncer Deep-Dive

### Role in Switchover
Connection holder + backend switcher

### Key Settings

| Setting | Value | Why |
|---------|-------|-----|
| `POOL_MODE` | `session` | One backend per client session |
| `DNS_MAX_TTL` | `0` | No DNS caching (**critical!**) |
| `ADMIN_USERS` | `appuser` | Allows PAUSE/RESUME commands |

### PAUSE Semantics
Waits for in-flight queries to complete, then holds all subsequent queries

<!--
NOTES-60: "Let me explain why PgBouncer is essential here. During switchover, we need two things: hold client connections without errors, and switch backend connections to the new primary. PgBouncer's PAUSE command does the first part — it waits for any in-flight query to complete, then holds all subsequent queries in a queue. DNS_MAX_TTL=0 is critical — without it, PgBouncer would cache the old DNS resolution of pg-rw and keep connecting to the demoted cluster."
SKIP-35: Yes — skip this slide in the 35-minute version
-->

---

<!-- 60-MIN ONLY: SLIDE 17b -->

# Connection Flow During Switchover

```
T+0s   PAUSE           → Clients queue
T+1s   DEMOTE blue     → Blue becomes standby
T+5s   Token acquired  → Replication confirmed in sync
T+6s   PROMOTE green   → Green becomes primary
T+10s  Patch pg-rw     → Service points to green
T+11s  RECONNECT       → Stale backends dropped
T+12s  RESUME          → Clients unfreeze, queries flow ✅
```

### Client experience: **~12–15 second pause. Zero errors.**

<!--
NOTES-60: "Here's the timeline. The entire switchover takes about 12–15 seconds. The longest wait is for the demotion token — CNPG needs to confirm that replication is fully caught up. From the client's perspective, they experience a 12–15 second pause. No errors, no disconnects, just a pause."
SKIP-35: Yes — skip this slide in the 35-minute version
-->

---

<!-- 60-MIN ONLY: SLIDE 17c -->

# Should PgBouncer Be Necessary?

| | With PgBouncer | Without PgBouncer |
|---|---|---|
| Client errors | None | Brief connection drops |
| Complexity | Higher | Lower |
| Safety | Guaranteed | Best-effort |

- CNPG maintainers say: switchover should cause **no noticeable disruption**
- In practice, we observed brief drops without PgBouncer
- **Open question:** configuration issue or expected behavior?
- PgBouncer = **defense-in-depth**

<!--
NOTES-60: "Here's an interesting question I discussed with Leonardo Cecchi, one of the CNPG maintainers, at KubeCon Europe. He told me that the switchover should cause no noticeable disruption — meaning PgBouncer's PAUSE/RESUME shouldn't be necessary. In our testing, we did see brief connection disruptions without PgBouncer. This might be a configuration issue on our side. But for now, PgBouncer gives us that safety net."
SKIP-35: Yes — skip this slide in the 35-minute version
-->

---

# Lessons Learned

1. ⚠️ **Service selector is the bottleneck** — Patch it fast after promotion
2. ⚠️ **DNS caching kills you** — Set `DNS_MAX_TTL=0` in PgBouncer
3. ⚠️ **Token polling needs a timeout** — Don't wait forever (we use 60s)
4. ✅ **Helm makes it repeatable** — Same chart, different values
5. ✅ **The demo app is your proof** — Continuous writes = live verification

<!--
NOTES-35: "A few lessons from building this. DNS caching is a silent killer — always set DNS_MAX_TTL=0. The demotion token needs a timeout — we use 60 seconds. And always have a demo app doing continuous writes — it's your proof that zero downtime actually works."
NOTES-60: "Let me share what we learned the hard way. First, the service selector patch needs to happen immediately after promotion is confirmed. Second, DNS caching — we spent hours debugging why PgBouncer kept connecting to the demoted cluster. Setting DNS_MAX_TTL=0 fixed it instantly. Third, the demotion token — in one test, replication was lagging and the token never appeared. You need a timeout and an abort path. And finally, the continuous-write demo app — it's not just for demos. We use it in staging to validate every switchover."
-->

---

# Pitfalls & Edge Cases

<!-- Visual: Warning-styled slide -->

- 🔥 **Long-running transactions** — PAUSE waits for them → switchover delay
- 🔥 **Replication lag** — Token won't appear if standby is behind
- 🔥 **Schema changes** — Both clusters must be schema-compatible
- 🔥 **Helm release state** — Blue/Green values must stay consistent
- 🔥 **PgBouncer SPOF** — Consider HA setup for production

<!--
NOTES-35: "Watch out for long-running transactions — they delay the PAUSE. And make sure your standby is caught up before switching, or the token won't appear."
NOTES-60: "Edge cases that can bite you. Long-running transactions: PgBouncer's PAUSE waits for all in-flight queries to complete. If you have a 30-second analytics query, your switchover is delayed. Consider setting a statement_timeout. Replication lag: if the standby is behind, the demotion token won't appear because CNPG can't confirm data safety. We've added a pre-flight check. Schema changes: make them backward-compatible — add columns, don't rename them. And PgBouncer is a single point of failure — for production, run multiple replicas."
-->

---

# Rollback: The Safety Net

<!-- Visual: Reverse arrow diagram: green → blue -->

### Rollback = run the same switchover **in reverse**

```
① PAUSE PgBouncer
② DEMOTE green    → Green becomes standby
③ PROMOTE blue    → Same token mechanism
④ RESUME          → Back to blue
```

- **No backup restore, no data recovery** — just flip
- Same 4 steps, same ~15 seconds
- Both clusters are **always running, always in sync**

<!--
NOTES-35: "Rollback is the same process in reverse. Demote green, promote blue, patch the service. No backup restores — just flip."
NOTES-60: "This is where Blue/Green really shines. Rollback is not a special procedure — it's the exact same switchover in the opposite direction. Because both clusters are always running and always in sync, you can switch back in 15 seconds. Compare that to traditional rollback: restore from backup, replay WAL, hope you got the right point-in-time. With Blue/Green, rollback is just another switchover."
-->

---

<!-- 60-MIN ONLY: SLIDE 20a -->

# CI/CD Integration

<!-- Visual: Pipeline diagram -->

```
Build → Test → Deploy App → Switchover → Verify → Done
                                  ↓ (fail)
                              Rollback
```

- **Pre-flight checks:** replication lag, cluster health, token readiness
- **Post-switchover verification:** demo app health, query test
- **Automated rollback:** if verification fails → switch back
- **Tools:** Helm + kubectl + shell scripts (or Argo CD / Flux)

<!--
NOTES-60: "In a real CI/CD pipeline, the switchover becomes just another deployment step. Before switching, run pre-flight checks: is replication caught up? After switching, run verification: can the app write and read? If verification fails, trigger an automated rollback."
SKIP-35: Yes — skip this slide in the 35-minute version
-->

---

<!-- 60-MIN ONLY: SLIDE 20b -->

# Production Considerations

- ✅ **Monitoring** — Track replication lag, switchover duration, PgBouncer queue
- ✅ **Alerting** — Alert on replication lag > threshold
- ✅ **Testing** — Regular switchover drills in staging
- ✅ **Multi-instance** — Run 2+ instances per cluster for HA
- ✅ **Backup** — CNPG continuous backup to S3/GCS

<!--
NOTES-60: "A few things for production. Monitor replication lag continuously. Run switchover drills regularly in staging. In production, run at least 2 instances per cluster for HA. And always enable continuous backups to object storage — Blue/Green gives you operational resilience, but backups give you disaster recovery."
SKIP-35: Yes — skip this slide in the 35-minute version
-->

---

# Key Takeaways

<br>

### 🎯 Blue/Green works for databases
CNPG's distributed topology makes it **practical**

### 🔄 Switchover = 4 steps, ~15 seconds
PAUSE → Demote → Promote → Resume

### ⏪ Rollback is instant
Same process in reverse — **no data loss**

<!--
NOTES-35: "Three things to remember. One: Blue/Green for databases is practical with CNPG. Two: the switchover is four steps, about 15 seconds. Three: rollback is instant — just switch back."
NOTES-60: "If you remember three things from this talk: First, Blue/Green deployments for databases are practical and production-ready with CloudNativePG's distributed topology. Second, the switchover is a well-defined 4-step process. Third, rollback is not a special disaster recovery procedure — it's the same switchover in reverse. Your standby is always running, always in sync, always ready."
-->

---

# Try It Yourself

```bash
git clone <repo-url>
make demo      # Full setup in ~5 minutes
make logs      # Watch continuous writes
make switch    # Trigger switchover — watch the magic!
make teardown  # Clean up
```

**Prerequisites:** Docker, k3d, kubectl, Helm

<!-- Visual: QR code linking to the GitHub repo -->

<!--
NOTES-35: "Everything is open source. Clone the repo, run make demo, and you have a working Blue/Green setup on your laptop in 5 minutes."
NOTES-60: "All of this is open source. Scan the QR code. You need Docker, k3d, kubectl, and Helm. Run make demo and in 5 minutes you have two PostgreSQL clusters with streaming replication, PgBouncer, and a demo app. Run make switch and watch — zero downtime. Try it, break things, see how CNPG handles it."
-->

---

<!-- _class: lead -->
<!-- _paginate: false -->

# Thank You! 🙏

## Questions?

**Speaker Name** — email, social handles
🔗 Repo link | 📱 QR code

<!--
NOTES-35: "Thank you! Happy to take questions. The repo link is on screen — try it out and let me know how it goes."
NOTES-60: "Thank you for your time! Happy to take questions about the architecture, the demo, production considerations, anything. The repo is on screen, feel free to reach out on Twitter or email. And if you're running CNPG in production, I'd love to hear about your experience."
-->
