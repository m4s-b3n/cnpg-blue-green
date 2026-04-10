#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
source /scripts/common.sh

# Post-upgrade hook for a SINGLE cluster.
# Logic:
#   1. Wait for MY cluster to be healthy with new config
#   2. Run health check
#   3. If I'm the standby → switchover TO ME (I have the new config)
#   4. If I'm already active → just confirm healthy (no switchover needed)

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  post-upgrade: ${MY_CLUSTER}                 "
echo "╚══════════════════════════════════════════════╝"
echo ""

MY_CLUSTER="${MY_CLUSTER:?MY_CLUSTER is required}"
OTHER_CLUSTER="${OTHER_CLUSTER:?OTHER_CLUSTER is required}"

START_TIME=$(date +%s)
elapsed() { echo "$(($(date +%s) - START_TIME))s"; }

# ── Step 1: Wait for my cluster to be healthy ─────────────────────────────
info "Step 1/3: Waiting for $MY_CLUSTER to be healthy..."
wait_cluster_ready "$MY_CLUSTER" "$HEALTH_CHECK_TIMEOUT"
ok "$MY_CLUSTER is healthy [$(elapsed)]"

# ── Step 2: Run health check ──────────────────────────────────────────────
info "Step 2/3: Running health check..."
/scripts/health-check.sh "$MY_CLUSTER"
ok "Health check passed [$(elapsed)]"

# ── Step 3: Switchover if I'm the standby ─────────────────────────────────
ACTIVE=$(detect_active_cluster)
info "Current active cluster: $ACTIVE"

if [[ "$ACTIVE" == "$MY_CLUSTER" ]]; then
	set_phase "IDLE" "$MY_CLUSTER is already active"
	ok "I'm already the active cluster. Nothing to switch."
elif [[ "${SWITCHOVER_ENABLED:-true}" != "true" ]]; then
	set_phase "IDLE" "Switchover disabled for $MY_CLUSTER"
	ok "Switchover disabled (SWITCHOVER_ENABLED=$SWITCHOVER_ENABLED). Skipping."
else
	info "Step 3/3: I'm the standby with new config → switching over..."

	# Pause PgBouncer
	set_phase "1) PAUSE" "Pausing PgBouncer..."
	pgb_pause

	# Demote the current active (clear promotionToken to avoid validation error)
	set_phase "2) DEMOTE" "Demoting $ACTIVE..."
	info "Demoting $ACTIVE..."
	kubectl patch cluster "$ACTIVE" -n "$NAMESPACE" --type=merge --field-manager=helm \
		-p "{\"spec\":{\"replica\":{\"primary\":\"$MY_CLUSTER\",\"source\":\"$MY_CLUSTER\",\"self\":\"$ACTIVE\",\"promotionToken\":null}}}"
	ok "Demotion initiated [$(elapsed)]"

	# Wait for demotion token
	info "Waiting for demotion token..."
	TOKEN=""
	for ((i = 1; i <= SWITCHOVER_TIMEOUT; i++)); do
		TOKEN=$(kubectl get cluster "$ACTIVE" -n "$NAMESPACE" \
			-o jsonpath='{.status.demotionToken}' 2>/dev/null || echo "")
		if [[ -n "$TOKEN" ]]; then
			ok "Demotion token acquired (attempt $i) [$(elapsed)]"
			break
		fi
		sleep 1
	done

	if [[ -z "$TOKEN" ]]; then
		err "No demotion token after ${SWITCHOVER_TIMEOUT}s — aborting!"
		# Rollback demotion (restore original topology)
		kubectl patch cluster "$ACTIVE" -n "$NAMESPACE" --type=merge --field-manager=helm \
			-p "{\"spec\":{\"replica\":{\"primary\":\"$ACTIVE\",\"source\":\"$MY_CLUSTER\",\"self\":\"$ACTIVE\"}}}"
		pgb_resume
		exit 1
	fi

	# Promote me
	set_phase "3) PROMOTE" "Promoting $MY_CLUSTER..."
	info "Promoting $MY_CLUSTER..."
	kubectl patch cluster "$MY_CLUSTER" -n "$NAMESPACE" --type=merge --field-manager=helm \
		-p "{\"spec\":{\"replica\":{\"primary\":\"$MY_CLUSTER\",\"source\":\"$ACTIVE\",\"self\":\"$MY_CLUSTER\",\"promotionToken\":\"$TOKEN\"}}}"
	ok "Promotion initiated [$(elapsed)]"

	# Patch services to me
	set_phase "4) PATCH & RESUME" "Patching services → $MY_CLUSTER"
	patch_services "$MY_CLUSTER"

	# Wait for me to be writable
	info "Waiting for $MY_CLUSTER to be writable..."
	for ((i = 1; i <= 60; i++)); do
		if check_writable; then
			ok "$MY_CLUSTER is writable [$(elapsed)]"
			break
		fi
		sleep 1
	done

	# Resume PgBouncer
	pgb_resume
fi

set_phase "IDLE" "Done"

TOTAL=$(($(date +%s) - START_TIME))
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  ✅ Done in ${TOTAL}s                              "
echo "║  Active: $(detect_active_cluster)            "
echo "╚══════════════════════════════════════════════╝"
