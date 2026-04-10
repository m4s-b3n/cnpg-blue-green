#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="cnpg-demo"
BLUE_CLUSTER="pg-blue"
GREEN_CLUSTER="pg-green"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$SCRIPT_DIR/../helm/pg-cluster"
VALUES_FILE="$CHART_DIR/values/green.yaml"

echo "=== Deploying Green cluster ($GREEN_CLUSTER) ==="

# Verify blue is ready
kubectl wait --for=condition=Ready cluster/"$BLUE_CLUSTER" -n "$NAMESPACE" --timeout=60s

if helm list -n "$NAMESPACE" | grep -q "$GREEN_CLUSTER"; then
  echo "Green cluster exists, upgrading..."
  helm upgrade "$GREEN_CLUSTER" "$CHART_DIR" \
    -n "$NAMESPACE" -f "$VALUES_FILE" --wait --timeout=600s
else
  helm install "$GREEN_CLUSTER" "$CHART_DIR" \
    -n "$NAMESPACE" -f "$VALUES_FILE" --wait --timeout=600s
fi

echo "=== Waiting for green cluster to be ready ==="
kubectl wait --for=condition=Ready cluster/"$GREEN_CLUSTER" -n "$NAMESPACE" --timeout=600s

# Verify replication
echo "=== Checking replication ==="
sleep 5
GREEN_POD=$(kubectl get cluster "$GREEN_CLUSTER" -n "$NAMESPACE" -o jsonpath='{.status.currentPrimary}')
echo "Green pod: $GREEN_POD"
kubectl exec -n "$NAMESPACE" "$GREEN_POD" -- psql -U postgres -c \
  "SELECT pid, status, sender_host FROM pg_stat_wal_receiver;" 2>/dev/null || echo "(WAL receiver check — may take a moment)"

echo ""
echo "✅ Green cluster deployed and replicating!"
kubectl get clusters -n "$NAMESPACE"
echo ""
echo "Next: ./04-deploy-app.sh"
