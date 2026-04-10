#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
source /scripts/common.sh

# Standalone switchover script — can be triggered manually or by CI.
# Detects active cluster and switches to the standby.

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  Manual Switchover                           ║"
echo "╚══════════════════════════════════════════════╝"
echo ""

START_TIME=$(date +%s)
elapsed() { echo "$(($(date +%s) - START_TIME))s"; }

ACTIVE=$(detect_active_cluster)
if [[ -z "$ACTIVE" ]]; then
	err "Cannot detect active cluster from pg-rw service selector"
	exit 1
fi

if [[ "$ACTIVE" == "$BLUE_CLUSTER" ]]; then
	STANDBY="$GREEN_CLUSTER"
else
	STANDBY="$BLUE_CLUSTER"
fi

info "$ACTIVE → $STANDBY"

# Verify standby is healthy
wait_cluster_ready "$STANDBY" 60

# Pause
pgb_pause

# Demote (clear promotionToken to avoid validation error)
info "Demoting $ACTIVE..."
kubectl patch cluster "$ACTIVE" -n "$NAMESPACE" --type=merge --field-manager=helm \
	-p "{\"spec\":{\"replica\":{\"primary\":\"$STANDBY\",\"source\":\"$STANDBY\",\"self\":\"$ACTIVE\",\"promotionToken\":null}}}"

# Wait for token
TOKEN=""
for ((i = 1; i <= SWITCHOVER_TIMEOUT; i++)); do
	TOKEN=$(kubectl get cluster "$ACTIVE" -n "$NAMESPACE" \
		-o jsonpath='{.status.demotionToken}' 2>/dev/null || echo "")
	if [[ -n "$TOKEN" ]]; then
		ok "Demotion token acquired [$(elapsed)]"
		break
	fi
	sleep 1
done

if [[ -z "$TOKEN" ]]; then
	err "No demotion token — aborting"
	kubectl patch cluster "$ACTIVE" -n "$NAMESPACE" --type=merge --field-manager=helm \
		-p "{\"spec\":{\"replica\":{\"primary\":\"$ACTIVE\",\"source\":\"$STANDBY\",\"self\":\"$ACTIVE\"}}}"
	pgb_resume
	exit 1
fi

# Promote
info "Promoting $STANDBY..."
kubectl patch cluster "$STANDBY" -n "$NAMESPACE" --type=merge --field-manager=helm \
	-p "{\"spec\":{\"replica\":{\"primary\":\"$STANDBY\",\"source\":\"$ACTIVE\",\"self\":\"$STANDBY\",\"promotionToken\":\"$TOKEN\"}}}"

# Patch services
patch_services "$STANDBY"

# Wait writable
for ((i = 1; i <= 60; i++)); do
	if check_writable; then
		ok "$STANDBY is writable [$(elapsed)]"
		break
	fi
	sleep 1
done

# Resume
pgb_resume

TOTAL=$(($(date +%s) - START_TIME))
echo ""
ok "Switchover complete in ${TOTAL}s — Active: $STANDBY"
