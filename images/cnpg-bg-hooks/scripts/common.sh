#!/usr/bin/env bash
# Common functions and variables for hook scripts.
# Sourced by other scripts, not executed directly.

# Environment variables expected from the hook Job:
#   NAMESPACE        - Kubernetes namespace
#   BLUE_CLUSTER     - Name of the blue CNPG cluster
#   GREEN_CLUSTER    - Name of the green CNPG cluster
#   DB_NAME          - Application database name
#   REPL_USERNAME    - Streaming replication username
#   REPL_PASSWORD    - Streaming replication password
#   APP_USERNAME     - Application username (for pgbouncer admin)
#   APP_PASSWORD     - Application password
#   PGBOUNCER_ENABLED - Whether PgBouncer is deployed

NAMESPACE="${NAMESPACE:?NAMESPACE is required}"
BLUE_CLUSTER="${BLUE_CLUSTER:?BLUE_CLUSTER is required}"
GREEN_CLUSTER="${GREEN_CLUSTER:?GREEN_CLUSTER is required}"
DB_NAME="${DB_NAME:-appdb}"
REPL_USERNAME="${REPL_USERNAME:-streaming_user}"
REPL_PASSWORD="${REPL_PASSWORD:-streaming_password}"
APP_USERNAME="${APP_USERNAME:-appuser}"
APP_PASSWORD="${APP_PASSWORD:-changeme123}"
PGBOUNCER_ENABLED="${PGBOUNCER_ENABLED:-true}"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-300}"
SWITCHOVER_TIMEOUT="${SWITCHOVER_TIMEOUT:-120}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
ok() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err() { echo -e "${RED}[ERROR]${NC} $1"; }

# Update the cnpg-bg-status ConfigMap with current phase
set_phase() {
	local phase="$1"
	local message="${2:-}"
	kubectl patch configmap cnpg-bg-status -n "$NAMESPACE" --type=merge \
		-p "{\"data\":{\"phase\":\"$phase\",\"active\":\"$(detect_active_cluster)\",\"message\":\"$message\",\"timestamp\":\"$(date -u +%H:%M:%S)\"}}" \
		2>/dev/null || true
	sleep "${PHASE_HOLD_SECONDS:-0}"
}

# Wait for a CNPG cluster to be Ready
wait_cluster_ready() {
	local cluster="$1"
	local timeout="${2:-$HEALTH_CHECK_TIMEOUT}"
	info "Waiting for cluster $cluster to be Ready (timeout: ${timeout}s)..."
	if kubectl wait --for=condition=Ready "cluster/$cluster" \
		-n "$NAMESPACE" --timeout="${timeout}s" 2>/dev/null; then
		ok "Cluster $cluster is Ready"
		return 0
	else
		err "Cluster $cluster not Ready after ${timeout}s"
		return 1
	fi
}

# Get the primary pod of a cluster
get_primary_pod() {
	local cluster="$1"
	kubectl get cluster "$cluster" -n "$NAMESPACE" \
		-o jsonpath='{.status.currentPrimary}'
}

# Detect which cluster the pg-rw service currently routes to
detect_active_cluster() {
	kubectl get svc pg-rw -n "$NAMESPACE" \
		-o jsonpath='{.spec.selector.cnpg\.io/cluster}' 2>/dev/null || echo ""
}

# Patch services to point to a cluster
patch_services() {
	local cluster="$1"
	info "Patching services → $cluster"
	for svc in pg-rw pg-ro pg-r; do
		kubectl patch svc "$svc" -n "$NAMESPACE" --type=json --field-manager=helm \
			-p "[{\"op\":\"replace\",\"path\":\"/spec/selector/cnpg.io~1cluster\",\"value\":\"$cluster\"}]" \
			2>/dev/null || true
	done
	ok "Services patched → $cluster"
}

# PgBouncer admin command via a helper pod
pgb_cmd() {
	local cmd="$1"
	local helper_pod
	helper_pod=$(kubectl get pods -n "$NAMESPACE" -l "cnpg.io/podRole=instance" \
		-o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
	if [[ -z "$helper_pod" ]]; then
		warn "No instance pod found for PgBouncer command"
		return 1
	fi
	kubectl exec -n "$NAMESPACE" "$helper_pod" -c postgres -- \
		psql "host=pgbouncer port=5432 user=$APP_USERNAME password=$APP_PASSWORD dbname=pgbouncer sslmode=disable" \
		-t -c "$cmd" 2>/dev/null
}

pgb_pause() {
	if [[ "$PGBOUNCER_ENABLED" == "true" ]]; then
		info "Pausing PgBouncer..."
		if pgb_cmd "PAUSE $DB_NAME;"; then
			ok "PgBouncer paused"
		else
			warn "PgBouncer pause failed"
		fi
	fi
}

pgb_resume() {
	if [[ "$PGBOUNCER_ENABLED" == "true" ]]; then
		info "Resuming PgBouncer..."
		pgb_cmd "RECONNECT $DB_NAME;" || true
		if pgb_cmd "RESUME $DB_NAME;"; then
			ok "PgBouncer resumed"
		else
			warn "PgBouncer resume failed"
		fi
	fi
}

# Check if a cluster's primary is writable via pg-rw service
check_writable() {
	local helper_pod
	helper_pod=$(kubectl get pods -n "$NAMESPACE" -l "cnpg.io/podRole=instance" \
		-o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
	if [[ -z "$helper_pod" ]]; then return 1; fi
	kubectl exec -n "$NAMESPACE" "$helper_pod" -c postgres -- \
		psql "host=pg-rw port=5432 user=$APP_USERNAME password=$APP_PASSWORD dbname=$DB_NAME sslmode=disable" \
		-c "SELECT pg_is_in_recovery();" 2>/dev/null | grep -q " f$"
}
