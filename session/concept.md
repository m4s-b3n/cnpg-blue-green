# Blue/Green for Databases
## Zero Downtime Deployments with Kubernetes & CNPG

### Conference Session Concept — Slide Deck & Demo Choreography

---

## Meta

| Aspect | Detail |
|---|---|
| **Title** | Blue/Green for Databases: Zero Downtime Deployments with Kubernetes & CNPG |
| **Formats** | 35 min (condensed) / 60 min (deep-dive) |
| **Language** | English |
| **Audience** | DevOps engineers, platform engineers, DBAs moving to Kubernetes |
| **Prereq knowledge** | Basic Kubernetes concepts, general idea of PostgreSQL |
| **Deliverables** | Slide deck (PowerPoint via compy master), live demo |

---

## Session Structure Overview

### 35-Minute Version — Timing

| # | Section | Duration | Slides |
|---|---------|----------|--------|
| 1 | Title + Intro | 2 min | 1–2 |
| 2 | The Problem | 3 min | 3–5 |
| 3 | Blue/Green Concept | 3 min | 6–8 |
| 4 | Architecture Overview | 4 min | 9–12 |
| 5 | The Switchover — How It Works | 5 min | 13–17 |
| 6 | **LIVE DEMO** | 10 min | — |
| 7 | Lessons Learned & Pitfalls | 4 min | 18–20 |
| 8 | Key Takeaways + Q&A | 4 min | 21–23 |
| | **Total** | **35 min** | **~23 slides** |

### 60-Minute Version — Timing

| # | Section | Duration | Slides |
|---|---------|----------|--------|
| 1 | Title + Intro | 2 min | 1–2 |
| 2 | The Problem (expanded) | 5 min | 3–5 |
| 3 | Blue/Green Concept (with DB specifics) | 5 min | 6–8 |
| 4 | Architecture Deep-Dive | 8 min | 9–12 |
| 5 | The Switchover — Step by Step | 8 min | 13–17 |
| 6 | **LIVE DEMO** | 15 min | — |
| 7 | PgBouncer's Role & Connection Mgmt | 5 min | (extra 17a–17c) |
| 8 | Lessons Learned & Pitfalls | 5 min | 18–20 |
| 9 | Integration into CI/CD Pipelines | 4 min | (extra 20a–20b) |
| 10 | Key Takeaways + Q&A | 3 min | 21–23 |
| | **Total** | **60 min** | **~28 slides** |

> **Strategy:** Slides 1–23 are shared. The 60-min version adds ~5 "deep-dive" slides
> (marked 17a–17c, 20a–20b) and the speaker notes for ALL slides are more detailed.
> In the 35-min version, skip the deep-dive slides and use the concise speaker notes.

---

## Slide-by-Slide Concept

---

### SLIDE 1 — Title Slide

**Visual:** Conference branding, talk title, speaker name/photo, company logo.

**Content:**
- Title: *Blue/Green for Databases*
- Subtitle: *Zero Downtime Deployments with Kubernetes & CNPG*
- Speaker name, role, company
- Conference name & date

**Speaker Notes (35 min):**
> Quick intro — name, role, what I do. "Today I'll show you how to do zero-downtime database deployments. With a live demo."

**Speaker Notes (60 min):**
> Same as 35 min, plus: "We'll go deep into the architecture, the switchover mechanics, connection management with PgBouncer, and I'll share the pitfalls we hit in production. Plus a live demo where we switch a running database with zero downtime."

---

### SLIDE 2 — About Me / Agenda

**Visual:** Split slide. Left: speaker bio/photo. Right: agenda bullet points.

**Content:**
- Brief speaker bio (2–3 bullets)
- Agenda overview:
  - ❌ The Problem with DB deployments
  - 🔵🟢 Blue/Green for Databases
  - 🏗️ Architecture with CNPG
  - 🔄 The Switchover
  - 🎬 Live Demo
  - 💡 Lessons Learned

**Speaker Notes (35 min):**
> "Here's the roadmap. We'll move fast — the demo is the star of the show."

**Speaker Notes (60 min):**
> "Here's our agenda. We'll cover each topic in depth, with extra sections on PgBouncer connection management and CI/CD integration. The demo will be more interactive — feel free to shout questions during it."

---

### SLIDE 3 — The Problem: Database Deployments Are Hard

**Visual:** A "danger zone" graphic or a broken pipeline illustration. Maybe a CI/CD pipeline diagram with a red "X" at the database step.

**Content:**
- "Databases are the bottleneck in CI/CD"
- Schema changes, data migrations, stateful workloads
- Traditional approach: maintenance window → downtime

**Speaker Notes (35 min):**
> "Everyone's got CI/CD for their apps. But the database? That's where pipelines break. Schema changes, data migrations, stateful workloads — you can't just `kubectl rollout restart` a database."

**Speaker Notes (60 min):**
> Same opening, plus: "Let me paint the picture: Your app deploys in 30 seconds. Blue/green, canary, rolling — pick your strategy. But then comes the database migration. And suddenly everyone's scheduling a maintenance window at 2 AM on a Saturday. Why? Because databases are stateful. You can't just throw away the old one and spin up a new one. Or can you?"

---

### SLIDE 4 — Why Zero Downtime Matters

**Visual:** Cost-of-downtime statistics or SLA table (99.9% = 8.7h/year, 99.99% = 52min/year).

**Content:**
- Business impact of downtime
- SLA requirements in modern platforms
- "Zero downtime" = no user-visible interruption

**Speaker Notes (35 min):**
> "Zero downtime isn't a nice-to-have anymore — it's an SLA requirement. Every minute of downtime costs money and trust."

**Speaker Notes (60 min):**
> "Let's talk numbers. 99.9% uptime sounds great until you realize that's almost 9 hours of downtime per year. For a payments platform or an e-commerce site, a single database migration that takes the system down for 5 minutes during peak hours can cost thousands. The goal isn't perfection — it's making deployments invisible to users."

---

### SLIDE 5 — Traditional Approaches (and Their Limits)

**Visual:** Comparison table or matrix.

**Content:**
| Approach | Downtime | Rollback | Complexity |
|----------|----------|----------|------------|
| Stop-deploy-start | Minutes | Restore backup | Low |
| Rolling update | Seconds | Tricky | Medium |
| Logical replication | Near-zero | Complex | High |
| **Blue/Green** | **Zero** | **Instant** | **Medium** |

**Speaker Notes (35 min):**
> "There are several approaches. Blue/Green gives us the best trade-off: zero downtime with instant rollback, at manageable complexity."

**Speaker Notes (60 min):**
> "Let me walk through the alternatives. Stop-deploy-start is the classic: take it down, migrate, bring it back. Simple but painful. Rolling updates work for stateless apps but databases aren't stateless. Logical replication can get you close to zero downtime but it's complex to set up and rollback is non-trivial. Blue/Green hits the sweet spot — and with CloudNativePG, Kubernetes does the heavy lifting."

---

### SLIDE 6 — Blue/Green Deployment: The Concept

**Visual:** Classic blue/green diagram — two boxes (blue active, green standby), router/load balancer in front, single arrow showing traffic flow.

**Content:**
- Two identical environments: Blue (active) + Green (standby)
- Traffic routed to active environment
- Deploy to standby → test → switch traffic
- Old environment becomes new standby

**Speaker Notes (35 min):**
> "Blue/Green is simple: two environments, one active, one standby. Deploy to standby, verify, flip traffic. The old active becomes the new standby. Instant rollback = just flip back."

**Speaker Notes (60 min):**
> "The Blue/Green pattern has been around for decades for stateless applications. The key insight is: you never deploy to the active system. You always deploy to the standby, verify it works, and then switch. If something goes wrong? Switch back. The standby is still there, unchanged. For stateless apps this is straightforward — spin up new containers, update the load balancer. But for databases, it's a different story..."

---

### SLIDE 7 — But Wait... Databases Are Different

**Visual:** Thought-bubble or callout box with key challenges. Maybe a "mind blown" emoji or illustration.

**Content:**
- **State:** Data must be synchronized between blue and green
- **Consistency:** No lost writes during switchover
- **Connections:** Active connections must be handled gracefully
- **Schema:** Both clusters must be schema-compatible

**Speaker Notes (35 min):**
> "For databases, Blue/Green is harder because of state. Both clusters need the same data, you can't lose writes during the switch, and existing connections need to be handled."

**Speaker Notes (60 min):**
> "This is where it gets interesting. Unlike stateless apps, databases have data. You need streaming replication to keep blue and green in sync. During switchover, you need to ensure no writes are lost — that means pausing writes briefly or using a connection proxy. And what about the 50 active connections from your app? They're pointing at the old primary. You need a strategy for all of this. That's what CloudNativePG gives us."

---

### SLIDE 8 — Enter CloudNativePG

**Visual:** CNPG logo + key features as icon grid.

**Content:**
- Kubernetes Operator for PostgreSQL
- Manages the full lifecycle: deploy, replicate, failover, backup
- **Distributed Topology**: first-class Blue/Green support
- Demotion/Promotion token mechanism for safe switchover
- Open source, CNCF project

**Speaker Notes (35 min):**
> "CloudNativePG is a Kubernetes operator for PostgreSQL. The key feature for us is Distributed Topology — it provides a built-in mechanism for Blue/Green switchover with demotion and promotion tokens."

**Speaker Notes (60 min):**
> "CloudNativePG — or CNPG — is a Kubernetes operator purpose-built for PostgreSQL. It manages everything: provisioning, replication, failover, backups, monitoring. What makes it special for Blue/Green is its Distributed Topology feature. Instead of hacking together scripts to promote and demote clusters, CNPG provides a proper API: you demote one cluster, get a demotion token that proves replication is caught up, and use that token to promote the other cluster. It's a handshake protocol that guarantees data safety."

---

### SLIDE 9 — Architecture Overview

**Visual:** The architecture diagram from the README — but polished for slides:

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

**Content:**
- Two CNPG clusters: pg-blue (primary) + pg-green (standby)
- WAL streaming replication keeps them in sync
- `pg-rw` Service routes to active primary via label selector
- PgBouncer sits between app and service (connection pooling + pause/resume)
- Demo app: Go app doing INSERT+SELECT every second

**Speaker Notes (35 min):**
> "Here's the architecture. Two PostgreSQL clusters managed by CNPG, connected via WAL streaming replication. The app connects through PgBouncer to the pg-rw service, which always points to the active primary. During switchover, we patch the service selector — traffic flips instantly."

**Speaker Notes (60 min):**
> "Let me walk through each component. At the top, the CNPG operator watches our Cluster CRDs and manages the PostgreSQL instances. We have two clusters: pg-blue starts as primary, pg-green as standby. They're connected via PostgreSQL streaming replication — every WAL record from blue is shipped to green in real-time. The pg-rw Service is a standard Kubernetes Service with a label selector pointing to the active cluster. PgBouncer is our connection proxy — it does connection pooling but more importantly, it can PAUSE and RESUME connections. The demo app is a simple Go program that writes and reads every second — our canary in the coal mine. If it reports an error, our zero-downtime claim is busted."

---

### SLIDE 10 — CNPG Cluster CRD

**Visual:** Simplified YAML snippet (syntax-highlighted).

**Content:**
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

**Speaker Notes (35 min):**
> "This is the Cluster CRD — the key part is the `replica` section. It defines the distributed topology: who's primary, who's the replication source, and the identity of this cluster."

**Speaker Notes (60 min):**
> "Here's the actual Cluster CRD. The `replica` block is where the magic happens. `primary` tells CNPG which cluster is currently the primary — this is what we change during switchover. `source` defines where to stream WAL from. `self` is the cluster's own identity. The `externalClusters` section defines the connection details for the partner cluster. Notice the `streaming_user` — that's a PostgreSQL user with REPLICATION privilege that we create during setup. CNPG uses this to establish streaming replication between the clusters."

---

### SLIDE 11 — The pg-rw Service (Traffic Router)

**Visual:** Diagram showing Service selector → Pod label matching. Two scenarios side-by-side: before switch (selector→blue) and after switch (selector→green).

**Content:**
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
- Kubernetes Service with dynamic selector
- During switchover: `kubectl patch svc pg-rw` → new selector
- No DNS change, no app restart — instant traffic rerouting

**Speaker Notes (35 min):**
> "The pg-rw service is our traffic router. It uses a label selector to point to the active cluster. During switchover, we patch this selector — Kubernetes instantly reroutes all new connections."

**Speaker Notes (60 min):**
> "This is the elegance of the approach. The pg-rw Service doesn't care about blue or green — it just routes to whatever pod matches its selector. When we switch, we run a simple kubectl patch to change the selector from pg-cluster-blue to pg-cluster-green. Kubernetes updates the Endpoints object immediately — no TTL, no propagation delay. Any new TCP connection to pg-rw goes to the new primary. But what about existing connections? That's where PgBouncer comes in."

---

### SLIDE 12 — Replication Setup

**Visual:** Flow diagram: pg-blue → streaming_user → WAL stream → pg-green. Show pg_basebackup for initial sync.

**Content:**
- **Initial sync:** `pg_basebackup` (full copy of blue → green)
- **Continuous sync:** WAL streaming replication
- **Replication user:** `streaming_user` with `REPLICATION` privilege
- **Secrets:** Kubernetes Secrets for credentials

**Speaker Notes (35 min):**
> "Green bootstraps from Blue using pg_basebackup — a full copy. After that, WAL streaming keeps them in sync continuously."

**Speaker Notes (60 min):**
> "The replication setup has two phases. First, when we deploy pg-green, it bootstraps using pg_basebackup — this creates a full physical copy of pg-blue. It's like cloning the entire database. After that, PostgreSQL's built-in streaming replication takes over. Every WAL record — every transaction — is shipped from blue to green in real-time. The latency is typically sub-second. We create a dedicated streaming_user with the REPLICATION privilege for this. The credentials are stored in Kubernetes Secrets and referenced in the Cluster CRD's externalClusters section."

---

### SLIDE 13 — The Switchover: 4-Step Process

**Visual:** Numbered timeline or flow chart with 4 steps. Each step is a box with an icon.

**Content:**
```
① PAUSE PgBouncer       → Hold client connections (no errors!)
② DEMOTE active cluster → Helm upgrade: change distributedTopology.primary
③ PROMOTE standby       → Acquire demotion token → promote with token
④ RESUME PgBouncer      → Patch pg-rw service → reconnect → resume
```

**Speaker Notes (35 min):**
> "The switchover is four steps. Pause PgBouncer to hold connections, demote the active cluster, promote the standby with a demotion token, then patch the service and resume PgBouncer. The whole thing takes about 10–15 seconds."

**Speaker Notes (60 min):**
> "Let me walk through each step in detail. This is the choreography that makes zero downtime possible."

---

### SLIDE 14 — Step 1: PAUSE PgBouncer

**Visual:** PgBouncer diagram showing clients queued/waiting, no traffic flowing to backend.

**Content:**
```sql
PAUSE appdb;
```
- Client connections are **held**, not dropped
- No errors on the application side — requests just wait
- This is the "freeze frame" before we switch

**Speaker Notes (35 min):**
> "We start by pausing PgBouncer. This holds all client connections in a queue — no errors, no timeouts, they just wait. The app doesn't even notice."

**Speaker Notes (60 min):**
> "Step one is critical. We send `PAUSE appdb` to PgBouncer's admin console. This tells PgBouncer to stop sending queries to the backend PostgreSQL but keep the client connections open. From the application's perspective, the current query just takes a bit longer. No connection errors, no retries needed. This gives us a clean window to perform the actual database switchover without any client seeing an error. The pause typically lasts 10–15 seconds."

---

### SLIDE 15 — Step 2: DEMOTE Active Cluster

**Visual:** Arrow diagram: pg-blue goes from "PRIMARY 👑" to "STANDBY".

**Content:**
```bash
helm upgrade pg-blue ./pg-cluster \
  --set distributedTopology.primary=pg-green
```
- Tells CNPG: "pg-green is now the intended primary"
- pg-blue transitions from primary → standby
- CNPG generates a **demotion token** when transition is complete

**Speaker Notes (35 min):**
> "We run a Helm upgrade that changes who the primary is. CNPG demotes pg-blue and generates a demotion token — proof that replication is caught up."

**Speaker Notes (60 min):**
> "We demote the active cluster by running a Helm upgrade that changes the `distributedTopology.primary` field. This tells CNPG: 'pg-green should be the primary now.' CNPG begins transitioning pg-blue from primary to standby mode. Once the transition is complete and replication is confirmed caught up, CNPG writes a demotion token to the cluster's status field. This token is crucial — it's a cryptographic proof that the standby has all the data. Without it, we can't promote the other side."

---

### SLIDE 16 — Step 3: PROMOTE Standby

**Visual:** Arrow diagram: pg-green goes from "STANDBY" to "PRIMARY 👑". Show the token being passed.

**Content:**
```bash
# 1. Get the demotion token
TOKEN=$(kubectl get cluster pg-blue -o jsonpath='{.status.demotionToken}')

# 2. Promote green with the token
helm upgrade pg-green ./pg-cluster \
  --set distributedTopology.promotionToken=$TOKEN
```
- Token handshake guarantees data consistency
- pg-green becomes the new primary
- No data loss possible — token proves sync

**Speaker Notes (35 min):**
> "We grab the demotion token from the old primary and pass it to the new primary. This handshake guarantees zero data loss."

**Speaker Notes (60 min):**
> "This is the handshake. We read the demotion token from pg-blue's status — this token encodes the WAL position where replication was confirmed in sync. We then pass this token to pg-green via a Helm upgrade setting the promotionToken. CNPG on the green side verifies the token, confirms it has all the WAL up to that point, and promotes itself to primary. This is what makes CNPG's approach safe — you can't accidentally promote a standby that's lagging behind. The token is the proof."

---

### SLIDE 17 — Step 4: RESUME — Go Live

**Visual:** Full flow restored: App → PgBouncer → pg-rw → pg-green (new primary). Green arrows, happy path.

**Content:**
```bash
# Patch service to point to new primary
kubectl patch svc pg-rw -p '{"spec":{"selector":{"cnpg.io/cluster":"pg-green"}}}'

# Reconnect PgBouncer (drop stale backends)
RECONNECT appdb;
RESUME appdb;
```
- Service selector patched → instant traffic reroute
- PgBouncer drops old backend connections, opens new ones
- `DNS_MAX_TTL=0` ensures immediate DNS re-resolution
- **Clients resume — zero errors!**

**Speaker Notes (35 min):**
> "Finally, we patch the pg-rw service to point to pg-green, tell PgBouncer to reconnect and resume. Clients unfreeze and continue as if nothing happened."

**Speaker Notes (60 min):**
> "Now we bring everything back online. First, we patch the pg-rw Kubernetes Service to change its selector from pg-cluster-blue to pg-cluster-green. This is instantaneous — Kubernetes updates the Endpoints object right away. Then we send two commands to PgBouncer: RECONNECT drops all existing backend connections to the old primary, and RESUME releases the queued client connections. Because we set DNS_MAX_TTL=0, PgBouncer immediately re-resolves the pg-rw hostname and connects to the new primary. The clients' queries flow through — they were just waiting, and now they get their responses. Zero errors in the logs."

---

### SLIDE 17a — PgBouncer Deep-Dive (60-min only)

**Visual:** PgBouncer architecture diagram: client connections on left, server connections on right, pool in the middle.

**Content:**
- **Role in switchover:** Connection holder + backend switcher
- **Key settings:**
  - `POOL_MODE=session` — one backend per client session
  - `DNS_MAX_TTL=0` — no DNS caching (critical!)
  - `ADMIN_USERS=appuser` — allows PAUSE/RESUME commands
- **PAUSE semantics:** Waits for in-flight queries to complete, then holds

**Speaker Notes (60 min):**
> "Let me explain why PgBouncer is essential here. During switchover, we need two things: hold client connections without errors, and switch backend connections to the new primary. PgBouncer's PAUSE command does the first part — it waits for any in-flight query to complete, then holds all subsequent queries in a queue. The clients don't get errors, they just experience slightly higher latency. DNS_MAX_TTL=0 is critical — without it, PgBouncer would cache the old DNS resolution of pg-rw and keep connecting to the demoted cluster. With TTL=0, every new backend connection resolves DNS fresh."

---

### SLIDE 17b — Connection Flow During Switchover (60-min only)

**Visual:** Timeline/sequence diagram showing what happens at each moment:

```
T+0s   PAUSE           → Clients queue
T+1s   DEMOTE blue     → Blue becomes standby
T+5s   Token acquired  → Replication confirmed in sync
T+6s   PROMOTE green   → Green becomes primary
T+10s  Patch pg-rw     → Service points to green
T+11s  RECONNECT       → Stale backends dropped
T+12s  RESUME          → Clients unfreeze, queries flow
```

**Speaker Notes (60 min):**
> "Here's the timeline. The entire switchover takes about 12–15 seconds. The longest wait is for the demotion token — CNPG needs to confirm that replication is fully caught up. From the client's perspective, they experience a 12–15 second pause. No errors, no disconnects, just a pause. For most applications, this is invisible — a web request might take 15 seconds instead of 200ms, but it succeeds."

---

### SLIDE 17c — Should PgBouncer Be Necessary? (60-min only)

**Visual:** Question mark icon. Two columns: "With PgBouncer" vs "Without PgBouncer".

**Content:**
- CNPG maintainers say: switchover should cause no noticeable disruption
- In theory, Kubernetes Service update + PostgreSQL's fast promotion = near-zero
- In practice, we observed brief connection drops without PgBouncer
- **Open question:** Is this a configuration issue or expected behavior?
- PgBouncer is our safety net — but ideally shouldn't be required

**Speaker Notes (60 min):**
> "Here's an interesting question I discussed with Leonardo Cecchi, one of the CNPG maintainers, at KubeCon Europe. He told me that the switchover should cause no noticeable disruption — meaning PgBouncer's PAUSE/RESUME shouldn't be necessary. In our testing, we did see brief connection disruptions without PgBouncer. This might be a configuration issue on our side — we're investigating. But for now, PgBouncer gives us that safety net. The takeaway: CNPG's distributed topology is designed for near-zero disruption, and PgBouncer adds defense-in-depth."

---

### SLIDE 18 — Lessons Learned

**Visual:** Numbered list with icons (⚠️ warning, ✅ solution).

**Content:**
1. ⚠️ **Service selector is the bottleneck** — Patch it fast after promotion
2. ⚠️ **DNS caching kills you** — Set `DNS_MAX_TTL=0` in PgBouncer
3. ⚠️ **Token polling needs a timeout** — Don't wait forever for demotion token
4. ✅ **Helm makes it repeatable** — Same chart, different values for blue/green
5. ✅ **The demo app is your proof** — Continuous writes = live verification

**Speaker Notes (35 min):**
> "A few lessons from building this. DNS caching is a silent killer — always set DNS_MAX_TTL=0. The demotion token needs a timeout — we use 60 seconds. And always have a demo app doing continuous writes — it's your proof that zero downtime actually works."

**Speaker Notes (60 min):**
> "Let me share what we learned the hard way. First, the service selector patch — this needs to happen immediately after promotion is confirmed. Any delay means PgBouncer might reconnect to the old primary. Second, DNS caching. We spent hours debugging why PgBouncer kept connecting to the demoted cluster — turns out it was caching the DNS resolution. Setting DNS_MAX_TTL=0 fixed it instantly. Third, the demotion token — in one test, replication was lagging and the token never appeared. You need a timeout and an abort path. Fourth, using Helm for both clusters with different value files made the setup clean and repeatable. And finally, the continuous-write demo app — it's not just for demos. We use it in staging to validate every switchover."

---

### SLIDE 19 — Pitfalls & Edge Cases

**Visual:** "Warning" styled slide — yellow/orange theme.

**Content:**
- 🔥 **Long-running transactions** — PAUSE waits for them to finish → delay
- 🔥 **Replication lag** — Token won't appear if standby is behind → timeout
- 🔥 **Schema changes** — Both clusters must be schema-compatible
- 🔥 **Helm release state** — Blue/Green values must stay consistent
- 🔥 **PgBouncer single point of failure** — Consider HA setup for production

**Speaker Notes (35 min):**
> "Watch out for long-running transactions — they delay the PAUSE. And make sure your standby is caught up before switching, or the token won't appear."

**Speaker Notes (60 min):**
> "Edge cases that can bite you. Long-running transactions: PgBouncer's PAUSE waits for all in-flight queries to complete. If you have a 30-second analytics query running, your switchover is delayed by 30 seconds. Consider setting a statement_timeout. Replication lag: if the standby is behind, the demotion token won't appear because CNPG can't confirm data safety. We've added a pre-flight check that verifies replication lag before starting the switchover. Schema changes: both clusters must be schema-compatible at the time of switchover. This means you need to make schema changes backward-compatible — add columns, don't rename them. And PgBouncer is a single point of failure — for production, consider running it as a Deployment with multiple replicas behind a Service."

---

### SLIDE 20 — Rollback: The Safety Net

**Visual:** Reverse arrow diagram: green → blue switchover. Same 4 steps, reversed.

**Content:**
- Rollback = **run the same switchover in reverse**
- pg-green demoted → pg-blue promoted
- Same token mechanism, same PgBouncer dance
- **No backup restore, no data recovery** — just flip

**Speaker Notes (35 min):**
> "Rollback is the same process in reverse. Demote green, promote blue, patch the service. No backup restores, no data recovery — just flip."

**Speaker Notes (60 min):**
> "This is where Blue/Green really shines. Rollback is not a special procedure — it's the exact same switchover, just in the opposite direction. Demote green, get the token, promote blue, patch the service. Because both clusters are always running and always in sync, you can switch back in 15 seconds. Compare that to traditional rollback: restore from backup, replay WAL, hope you got the right point-in-time. With Blue/Green, rollback is just another switchover."

---

### SLIDE 20a — CI/CD Integration (60-min only)

**Visual:** Pipeline diagram: Build → Test → Deploy App → Switchover → Verify → Done (or Rollback).

**Content:**
- Integrate switchover into your deployment pipeline
- Pre-flight checks: replication lag, cluster health, token readiness
- Post-switchover verification: demo app health, query test
- Automated rollback trigger: if verification fails → switch back
- Tools: Helm + kubectl + shell scripts (or Argo CD)

**Speaker Notes (60 min):**
> "In a real CI/CD pipeline, the switchover becomes just another deployment step. Before switching, run pre-flight checks: is replication caught up? Is the standby healthy? Is the operator ready? After switching, run verification: can the app write? Can it read? Are all services healthy? If verification fails, trigger an automated rollback — same switchover, reversed. We do this with a combination of Helm, kubectl, and shell scripts. If you're using Argo CD or Flux, you can model this as a series of Argo workflows or Flux automation objects."

---

### SLIDE 20b — Production Considerations (60-min only)

**Visual:** Checklist-style slide.

**Content:**
- ✅ **Monitoring:** Track replication lag, switchover duration, PgBouncer queue depth
- ✅ **Alerting:** Alert on replication lag > threshold before any switchover
- ✅ **Testing:** Regular switchover drills in staging
- ✅ **Multi-instance:** Run 2+ instances per cluster for HA within each side
- ✅ **Backup:** CNPG supports continuous backup to S3/GCS — enable it

**Speaker Notes (60 min):**
> "A few things for production. Monitor your replication lag continuously — not just during switchovers. Set alerts for lag spikes. Run switchover drills regularly in staging — muscle memory matters. In production, run at least 2 instances per cluster for HA within each side — if a pod crashes, CNPG handles the failover within the cluster. And always enable continuous backups to object storage. Blue/Green gives you operational resilience, but backups give you disaster recovery."

---

### SLIDE 21 — Key Takeaways

**Visual:** Three big icons/bullets, clean and memorable.

**Content:**
1. 🎯 **Blue/Green works for databases** — CNPG's distributed topology makes it practical
2. 🔄 **Switchover = 4 steps, ~15 seconds** — PAUSE → Demote → Promote → Resume
3. ⏪ **Rollback is instant** — Same process in reverse, no data loss

**Speaker Notes (35 min):**
> "Three things to remember. One: Blue/Green for databases is not just possible, it's practical with CNPG. Two: the switchover is four steps and takes about 15 seconds. Three: rollback is instant — just switch back."

**Speaker Notes (60 min):**
> "If you remember three things from this talk: First, Blue/Green deployments for databases are practical and production-ready with CloudNativePG's distributed topology. Second, the switchover is a well-defined 4-step process that takes about 15 seconds — pause, demote, promote, resume. And third, rollback is not a special disaster recovery procedure — it's the same switchover in reverse. Your standby is always running, always in sync, always ready. This changes how you think about database deployments."

---

### SLIDE 22 — Try It Yourself

**Visual:** QR code linking to the GitHub repo + terminal screenshot.

**Content:**
```bash
git clone <repo-url>
make demo      # Full setup in ~5 minutes
make logs      # Watch continuous writes
make switch    # Trigger switchover — watch the magic!
make teardown  # Clean up
```
- Prerequisites: Docker, k3d, kubectl, Helm
- Full demo in 5 minutes on your laptop

**Speaker Notes (35 min):**
> "Everything is open source. Clone the repo, run `make demo`, and you have a working Blue/Green setup on your laptop in 5 minutes. Try it!"

**Speaker Notes (60 min):**
> "All of this is open source and available in our GitHub repo. Scan the QR code or check the link. You need Docker, k3d, kubectl, and Helm — that's it. Run `make demo` and in about 5 minutes you have two PostgreSQL clusters with streaming replication, PgBouncer, and a demo app doing continuous writes. Run `make switch` and watch the logs — zero downtime. I encourage you to try it and experiment — break things, add latency, kill pods, see how CNPG handles it."

---

### SLIDE 23 — Thank You + Q&A

**Visual:** Speaker contact info, social media, repo link, QR code again.

**Content:**
- "Thank you!"
- Speaker name, email, social handles
- Repo link + QR code
- "Questions?"

**Speaker Notes (35 min):**
> "Thank you! Happy to take questions. The repo link is on screen — try it out and let me know how it goes."

**Speaker Notes (60 min):**
> "Thank you for your time! I'm happy to take questions — about the architecture, the demo, production considerations, anything. The repo is on screen, feel free to reach out on Twitter or email if you think of questions later. And if you're running CNPG in production, I'd love to hear about your experience."

---

## Live Demo Choreography

### Setup (before the talk)

**Pre-stage the environment** to save time during the demo:

```bash
# Run BEFORE the talk (takes ~5 min)
make demo
# Verify everything is running
make status
make logs  # Leave running in a terminal
```

The demo environment should be fully running when you walk on stage. Two terminals visible:
1. **Terminal 1:** `make logs` — continuous output showing writes
2. **Terminal 2:** Ready for commands

### Demo Flow — 35-Minute Version (10 min)

| Step | Action | What audience sees | Talk track |
|------|--------|--------------------|------------|
| 1 | Show `make logs` output | Continuous WRITE ok messages | "This app is writing to PostgreSQL every second. Let's see what happens when we switch." |
| 2 | Show `make status` | Both clusters, pods, services | "Here's our setup — pg-blue is primary, pg-green is standby." |
| 3 | Run `make switch` | Script output with each step | "Watch the 4 steps: PAUSE... DEMOTE... TOKEN... PROMOTE... RESUME..." |
| 4 | Point to `make logs` | Continuous WRITE ok — no errors! | "Look at the logs — no interruption. Zero errors. That's zero downtime." |
| 5 | Run `make status` again | pg-green is now primary | "And now green is the primary. We can switch back just as easily." |
| 6 | (Optional) Run `make switch` again | Reverse switchover | "And back to blue. Same process, same result." |

### Demo Flow — 60-Minute Version (15 min)

| Step | Action | What audience sees | Talk track |
|------|--------|--------------------|------------|
| 1 | Show `make logs` output | Continuous WRITE ok | "This is our canary — writing every second." |
| 2 | Show `make status` | Full cluster status | "Blue is primary, green is standby. Let's peek at the replication." |
| 3 | Show replication status | `pg_stat_replication` output | "Here's the streaming replication — green is caught up." |
| 4 | Show PgBouncer stats | `SHOW pools;` output | "PgBouncer is proxying our connections. One active server connection." |
| 5 | Run switchover **step by step** | Each command individually | Walk through each step with explanation |
| 5a | `PAUSE appdb;` | Logs stop appearing | "Paused. The app is waiting, not erroring." |
| 5b | Helm upgrade (demote) | Helm output | "Demoting blue..." |
| 5c | Poll for token | Token appears | "There's the token — replication is confirmed in sync." |
| 5d | Helm upgrade (promote) | Helm output | "Promoting green with the token..." |
| 5e | Patch service + RESUME | Logs resume! | "And we're back! Look — no errors in the log." |
| 6 | Show `make status` | Green is primary | "Green is now primary." |
| 7 | Show replication reversed | Blue now replicating from green | "And blue is now the standby, replicating from green." |
| 8 | (Optional) Full reverse switch | `make switch` | "Let's switch back — same process, 15 seconds." |

### Demo Tips

- **Font size:** Use large terminal font (20pt+). Audience needs to read from the back.
- **Terminal theme:** Dark background, light text. High contrast.
- **Split screen:** Logs on top/left, commands on bottom/right.
- **Backup plan:** If the live demo fails, have a screen recording ready.
- **Pre-flight:** Always run `make status` before the demo to verify everything is healthy.
- **Timing safety:** If running short on time in 35-min version, skip the reverse switchover.

---

## Visualization Ideas

### Animated Diagrams (if tooling allows)

1. **Architecture slide:** Build up component by component (k8s cluster → CNPG operator → blue cluster → green cluster → replication arrows → service → PgBouncer → app)
2. **Switchover sequence:** Step-by-step animation showing traffic flow changing
3. **Before/After:** Side-by-side showing blue as primary vs green as primary

### Color Coding

- **Blue:** `#2196F3` — Blue cluster, primary when active
- **Green:** `#4CAF50` — Green cluster, primary after switch
- **Red/Orange:** `#FF5722` — Warnings, pitfalls, errors
- **Gray:** `#9E9E9E` — Inactive/standby components

### Slide Style Recommendations

- **Minimal text** — max 5 bullets per slide
- **Large diagrams** — architecture and flow diagrams should dominate
- **Code snippets** — syntax-highlighted, max 10 lines per slide
- **Dark mode** for code slides, light mode for concept slides (or consistent throughout)

---

## Slide Count Summary

| Slide | Title | 35-min | 60-min |
|-------|-------|--------|--------|
| 1 | Title | ✅ | ✅ |
| 2 | About Me / Agenda | ✅ | ✅ |
| 3 | The Problem | ✅ | ✅ |
| 4 | Why Zero Downtime | ✅ | ✅ |
| 5 | Traditional Approaches | ✅ | ✅ |
| 6 | Blue/Green Concept | ✅ | ✅ |
| 7 | DBs Are Different | ✅ | ✅ |
| 8 | Enter CNPG | ✅ | ✅ |
| 9 | Architecture Overview | ✅ | ✅ |
| 10 | CNPG Cluster CRD | ✅ | ✅ |
| 11 | pg-rw Service | ✅ | ✅ |
| 12 | Replication Setup | ✅ | ✅ |
| 13 | Switchover: 4 Steps | ✅ | ✅ |
| 14 | Step 1: PAUSE | ✅ | ✅ |
| 15 | Step 2: DEMOTE | ✅ | ✅ |
| 16 | Step 3: PROMOTE | ✅ | ✅ |
| 17 | Step 4: RESUME | ✅ | ✅ |
| 17a | PgBouncer Deep-Dive | ❌ | ✅ |
| 17b | Connection Timeline | ❌ | ✅ |
| 17c | Should PgBouncer Be Necessary? | ❌ | ✅ |
| 18 | Lessons Learned | ✅ | ✅ |
| 19 | Pitfalls & Edge Cases | ✅ | ✅ |
| 20 | Rollback | ✅ | ✅ |
| 20a | CI/CD Integration | ❌ | ✅ |
| 20b | Production Considerations | ❌ | ✅ |
| 21 | Key Takeaways | ✅ | ✅ |
| 22 | Try It Yourself | ✅ | ✅ |
| 23 | Thank You + Q&A | ✅ | ✅ |
| | **Total** | **23** | **28** |

---

## Next Steps

1. **Review this concept** — adjust structure, add/remove slides as needed
2. **Create PowerPoint** — use compy slide deck master template
3. **Prepare demo environment** — test the full demo flow end-to-end
4. **Record backup demo video** — in case live demo fails
5. **Practice timing** — run through both versions with a stopwatch
6. **Prepare for PgBouncer question** — update after Leonardo's feedback
