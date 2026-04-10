# ─── CNPG Blue/Green Demo ─────────────────────────────────────────────────────
# Usage (in order):
#   make setup          → create k3d cluster + install CNPG operator
#   make images         → build & load hooks + app images (optional — skipping
#                         uses the latest published images from ghcr.io)
#   make install        → deploy infra + blue + green (3 releases, 1 chart)
#   make app            → deploy demo app
#   make logs           → watch app logs (proof of zero-downtime)
#   make monitor        → live dashboard: cluster state + switchover phase
#   make switchover     → sequential: update standby → switch → update other
#   make status         → show clusters, pods, services
#   make clean          → remove everything (keeps operator + cluster)
#   make delete-cluster → remove the k3d cluster entirely

.PHONY: setup images hooks-build hooks-load app-build app-load \
        install switchover app logs status clean delete-cluster monitor

# ─── Config ──────────────────────────────────────────────────────────────────
export HOOKS_IMAGE_REPO   ?= ghcr.io/m4s-b3n/cnpg-blue-green/cnpg-bg-hooks
export HOOKS_IMAGE_TAG    ?= latest
export APP_REPO           ?= ghcr.io/m4s-b3n/cnpg-blue-green/demo-app
export APP_TAG            ?= latest
export K3D_CLUSTER        ?= cnpg-demo
export NAMESPACE          ?= cnpg-demo
export RELEASE            ?= mydb
export CHART              ?= ./charts/cnpg-bg
export VALUES             ?= $(CHART)/values.yaml
export CNPG_CHART_VERSION ?= 0.28.2

# ─── 1. Setup: cluster + operator ────────────────────────────────────────────
setup:
	@scripts/setup.sh

# ─── 2. Build & load images (optional) ───────────────────────────────────────
hooks-build:
	@scripts/hooks-build.sh

hooks-load: hooks-build
	@scripts/hooks-load.sh

app-build:
	@scripts/app-build.sh

app-load: app-build
	@scripts/app-load.sh

images: hooks-load app-load
	@echo "✅ All images ready in cluster"

# ─── 3. Install (3 releases: infra, blue, green) ─────────────────────────────
install:
	@scripts/install.sh

# ─── 4. Deploy demo app ──────────────────────────────────────────────────────
app:
	@scripts/app-deploy.sh

# ─── 5. Watch logs ───────────────────────────────────────────────────────────
logs:
	@scripts/logs.sh

# ─── 5b. Live monitor ────────────────────────────────────────────────────────
monitor:
	@scripts/monitor.sh

# ─── 6. switchover: update standby → switch → update other (no switch) ──────────
switchover:
	@scripts/switchover.sh

# ─── Status ──────────────────────────────────────────────────────────────────
status:
	@scripts/status.sh

# ─── Cleanup (keeps operator + cluster) ──────────────────────────────────────
clean:
	@scripts/clean.sh

# ─── Delete cluster ──────────────────────────────────────────────────────────
delete-cluster:
	@scripts/delete-cluster.sh


