#!/usr/bin/env bash
set -euo pipefail

# Bidirectional Blue/Green Switchover using CNPG Distributed Topology
# Zero-downtime via PgBouncer PAUSE + service selector patching:
#   - PAUSE PgBouncer → clients wait (no errors)
#   - Only change topology via Helm (no inheritedMetadata → no rolling update)
#   - Patch pg-rw/pg-ro/pg-r service selectors to target cluster
#   - RESUME PgBouncer → clients flow to new primary

NAMESPACE="cnpg-demo"
BLUE_RELEASE="pg-blue"
GREEN_RELEASE="pg-green"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$SCRIPT_DIR/../helm/pg-cluster"
VALUES_DIR="$CHART_DIR/values"
SKIP_PGBOUNCER="${SKIP_PGBOUNCER:-0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()      { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()     { echo -e "${RED}[ERROR]${NC} $1"; }

elapsed() { echo "$(( $(date +%s) - START_TIME ))s"; }

SOURCE="" TARGET="" SOURCE_RELEASE="" TARGET_RELEASE="" SOURCE_VALUES="" TARGET_VALUES=""
START_TIME=0

pgb_cmd() {
  local cmd="$1"
  local admin_pod
  admin_pod=$(kubectl get pods -n "$NAMESPACE" -l "cnpg.io/podRole=instance,role=replica" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -z "$admin_pod" ]]; then
    admin_pod=$(kubectl get pods -n "$NAMESPACE" -l "cnpg.io/podRole=instance" \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  fi
  kubectl exec -n "$NAMESPACE" "$admin_pod" -c postgres -- \
    psql "host=pgbouncer port=5432 user=appuser password=changeme123 dbname=pgbouncer sslmode=disable" \
    -t -c "$cmd" 2>/dev/null
}

pgb_available() {
  [[ "$SKIP_PGBOUNCER" != "1" ]] && kubectl get deploy pgbouncer -n "$NAMESPACE" &>/dev/null
}

pgb_deployed() {
  kubectl get deploy pgbouncer -n "$NAMESPACE" &>/dev/null
}

detect_active() {
  # Detect which cluster pg-rw currently routes to
  local current_cluster
  current_cluster=$(kubectl get svc pg-rw -n "$NAMESPACE" \
    -o jsonpath='{.spec.selector.cnpg\.io/cluster}' 2>/dev/null || echo "")

  if [[ "$current_cluster" == "$BLUE_RELEASE" ]]; then
    SOURCE="pg-blue"; TARGET="pg-green"
    SOURCE_RELEASE="$BLUE_RELEASE"; TARGET_RELEASE="$GREEN_RELEASE"
    SOURCE_VALUES="$VALUES_DIR/blue.yaml"; TARGET_VALUES="$VALUES_DIR/green.yaml"
    info "BLUE is active → switching to GREEN"
  elif [[ "$current_cluster" == "$GREEN_RELEASE" ]]; then
    SOURCE="pg-green"; TARGET="pg-blue"
    SOURCE_RELEASE="$GREEN_RELEASE"; TARGET_RELEASE="$BLUE_RELEASE"
    SOURCE_VALUES="$VALUES_DIR/green.yaml"; TARGET_VALUES="$VALUES_DIR/blue.yaml"
    info "GREEN is active → switching to BLUE"
  else
    err "Cannot detect active cluster from pg-rw selector (got: '$current_cluster')"
    exit 1
  fi
}

patch_services() {
  local cluster="$1"
  info "Patching services → $cluster"
  kubectl patch svc pg-rw -n "$NAMESPACE" --type=json \
    -p "[{\"op\":\"replace\",\"path\":\"/spec/selector/cnpg.io~1cluster\",\"value\":\"$cluster\"}]"
  kubectl patch svc pg-ro -n "$NAMESPACE" --type=json \
    -p "[{\"op\":\"replace\",\"path\":\"/spec/selector/cnpg.io~1cluster\",\"value\":\"$cluster\"}]"
  kubectl patch svc pg-r -n "$NAMESPACE" --type=json \
    -p "[{\"op\":\"replace\",\"path\":\"/spec/selector/cnpg.io~1cluster\",\"value\":\"$cluster\"}]"
}

switchover() {
  echo ""
  echo "╔══════════════════════════════════════════════╗"
  echo "║  CNPG Blue/Green Switchover                  ║"
  echo "║  $SOURCE → $TARGET"
  echo "╚══════════════════════════════════════════════╝"
  echo ""

  START_TIME=$(date +%s)

  # ── Step 0: Pause PgBouncer ────────────────────────────────────────
  if pgb_available; then
    info "Step 0: Pausing PgBouncer (clients will wait)..."
    pgb_cmd "PAUSE appdb;"
    ok "PgBouncer paused — clients held [$(elapsed)]"
  else
    warn "PgBouncer not deployed — clients may see brief errors during switch"
  fi

  # ── Step 1: Demote source ──────────────────────────────────────────
  info "Step 1/4: Demoting $SOURCE (topology change only)"
  helm upgrade "$SOURCE_RELEASE" "$CHART_DIR" \
    -n "$NAMESPACE" -f "$SOURCE_VALUES" \
    --set "distributedTopology.primary=$TARGET"
  ok "$SOURCE demotion initiated [$(elapsed)]"

  # ── Step 2: Poll for demotion token ────────────────────────────────
  info "Step 2/4: Waiting for demotion token..."
  local token="" attempts=60
  for ((i=1; i<=attempts; i++)); do
    token=$(kubectl get cluster "$SOURCE_RELEASE" -n "$NAMESPACE" \
      -o jsonpath='{.status.demotionToken}' 2>/dev/null || echo "")
    if [[ -n "$token" ]]; then
      ok "Demotion token acquired (attempt $i) [$(elapsed)]"
      break
    fi
    sleep 1
  done

  if [[ -z "$token" ]]; then
    err "No demotion token after $attempts attempts — aborting"
    warn "Rolling back $SOURCE to primary..."
    helm upgrade "$SOURCE_RELEASE" "$CHART_DIR" \
      -n "$NAMESPACE" -f "$SOURCE_VALUES" \
      --set "distributedTopology.primary=$SOURCE"
    if pgb_available; then pgb_cmd "RESUME appdb;"; fi
    exit 1
  fi

  # ── Step 3: Promote target ─────────────────────────────────────────
  info "Step 3/4: Promoting $TARGET with token"
  helm upgrade "$TARGET_RELEASE" "$CHART_DIR" \
    -n "$NAMESPACE" -f "$TARGET_VALUES" \
    --set "distributedTopology.primary=$TARGET" \
    --set "distributedTopology.promotionToken=$token"
  ok "$TARGET promotion initiated [$(elapsed)]"

  # ── Step 4: Wait for target primary to be writable ───────────────
  info "Step 4/4: Waiting for $TARGET to be writable..."

  # First find a helper pod (source replica) for testing connectivity
  local helper_pod
  helper_pod=$(kubectl get pods -n "$NAMESPACE" \
    -l "cnpg.io/cluster=$SOURCE_RELEASE,role=replica" \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
  if [[ -z "$helper_pod" ]]; then
    helper_pod=$(kubectl get pods -n "$NAMESPACE" \
      -l "cnpg.io/podRole=instance" \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
  fi

  # Patch services first so pg-rw points to target
  patch_services "$TARGET_RELEASE"
  ok "Services patched → $TARGET [$(elapsed)]"

  # Force PgBouncer to drop stale backend connections to the old primary.
  # In no-pause mode we skipped PAUSE/RESUME but still need RECONNECT so
  # PgBouncer creates new backends through the updated pg-rw service.
  if pgb_deployed; then
    info "Reconnecting PgBouncer backends → $TARGET..."
    pgb_cmd "RECONNECT appdb;"
    ok "PgBouncer backends reconnecting [$(elapsed)]"
  fi

  # Now poll until the target primary is actually writable via pg-rw
  local writable=false
  for ((i=1; i<=60; i++)); do
    if kubectl exec -n "$NAMESPACE" "$helper_pod" -c postgres -- \
      psql "host=pg-rw port=5432 user=appuser password=changeme123 dbname=appdb sslmode=disable" \
      -c "SELECT pg_is_in_recovery();" 2>/dev/null | grep -q " f$"; then
      writable=true
      ok "$TARGET is writable [$(elapsed)]"
      break
    fi
    sleep 1
  done

  if [[ "$writable" != "true" ]]; then
    warn "$TARGET not writable after 60s — resuming anyway"
  fi

  # ── Resume PgBouncer ───────────────────────────────────────────────
  # RECONNECT drops stale backend connections; RESUME releases held clients.
  # With dns_max_ttl=0, new connections resolve fresh DNS → reach new primary.
  if pgb_available; then
    info "Resuming PgBouncer..."
    pgb_cmd "RECONNECT appdb;"
    pgb_cmd "RESUME appdb;"
    ok "PgBouncer resumed — clients flowing to $TARGET [$(elapsed)]"
  fi

  local total
  total=$(( $(date +%s) - START_TIME ))

  echo ""
  echo "╔══════════════════════════════════════════════╗"
  echo "║  ✅ Switchover complete in ${total}s              ║"
  echo "║  Active: $TARGET"
  echo "║  Standby: $SOURCE"
  echo "╚══════════════════════════════════════════════╝"
  echo ""

  kubectl get pods -n "$NAMESPACE" -l "cnpg.io/podRole=instance" \
    -o custom-columns='NAME:.metadata.name,ROLE:.metadata.labels.role,CLUSTER:.metadata.labels.cnpg\.io/cluster,READY:.status.conditions[?(@.type=="Ready")].status'
  echo ""
  info "pg-rw → $(kubectl get svc pg-rw -n "$NAMESPACE" -o jsonpath='{.spec.selector.cnpg\.io/cluster}')"
  info "Run this script again to switch back"
}

detect_active
switchover
