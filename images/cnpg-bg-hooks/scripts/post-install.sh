#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
source /scripts/common.sh

# Post-install hook for the BLUE cluster. The replication user is created
# via postInitSQL in the cluster spec, so no manual exec needed.

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  post-install: ${MY_CLUSTER:-$BLUE_CLUSTER}   "
echo "╚══════════════════════════════════════════════╝"
echo ""

CLUSTER="${MY_CLUSTER:-$BLUE_CLUSTER}"

info "Waiting for $CLUSTER to be healthy..."
wait_cluster_ready "$CLUSTER" "$HEALTH_CHECK_TIMEOUT"

# Verify replication user exists
PRIMARY_POD=$(get_primary_pod "$CLUSTER")
info "Verifying replication user on $PRIMARY_POD..."
kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgres -- \
	psql -U postgres -d appdb -tAc \
	"SELECT 1 FROM pg_user WHERE usename = '$REPL_USERNAME'" | grep -q 1

ok "$CLUSTER is healthy and replication user ready"
