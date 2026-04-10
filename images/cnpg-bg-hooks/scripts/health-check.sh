#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=/dev/null
source /scripts/common.sh

# Health check script for a CNPG cluster.
# Can be overridden by users mounting a custom script.
# Usage: health-check.sh <cluster-name>

CLUSTER="${1:-}"
if [[ -z "$CLUSTER" ]]; then
	err "Usage: health-check.sh <cluster-name>"
	exit 1
fi

info "Running health check on cluster: $CLUSTER"

# Check 1: Cluster CR is Ready
wait_cluster_ready "$CLUSTER" 60

# Check 2: All instances are running
EXPECTED_INSTANCES=$(kubectl get cluster "$CLUSTER" -n "$NAMESPACE" \
	-o jsonpath='{.spec.instances}')
READY_INSTANCES=$(kubectl get cluster "$CLUSTER" -n "$NAMESPACE" \
	-o jsonpath='{.status.readyInstances}')

if [[ "$READY_INSTANCES" -lt "$EXPECTED_INSTANCES" ]]; then
	err "Only $READY_INSTANCES/$EXPECTED_INSTANCES instances ready"
	exit 1
fi
ok "All instances ready: $READY_INSTANCES/$EXPECTED_INSTANCES"

# Check 3: Primary pod is responding
PRIMARY_POD=$(get_primary_pod "$CLUSTER")
if [[ -z "$PRIMARY_POD" ]]; then
	err "No primary pod found for $CLUSTER"
	exit 1
fi

kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgres -- \
	pg_isready -U postgres -d "$DB_NAME" -q
ok "Primary $PRIMARY_POD is accepting connections"

# Check 4: Can execute a query
kubectl exec -n "$NAMESPACE" "$PRIMARY_POD" -c postgres -- \
	psql -U postgres -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1
ok "Query execution successful on $PRIMARY_POD"

ok "Health check passed for $CLUSTER"
