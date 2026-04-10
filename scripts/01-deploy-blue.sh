#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="cnpg-demo"
BLUE_CLUSTER="pg-blue"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$SCRIPT_DIR/../helm/pg-cluster"
VALUES_FILE="$CHART_DIR/values/blue.yaml"

echo "=== Deploying Blue cluster ($BLUE_CLUSTER) ==="

if helm list -n "$NAMESPACE" | grep -q "$BLUE_CLUSTER"; then
  echo "Blue cluster exists, upgrading..."
  helm upgrade "$BLUE_CLUSTER" "$CHART_DIR" \
    -n "$NAMESPACE" -f "$VALUES_FILE" --wait --timeout=600s
else
  helm install "$BLUE_CLUSTER" "$CHART_DIR" \
    -n "$NAMESPACE" -f "$VALUES_FILE" --wait --timeout=600s
fi

echo "=== Waiting for blue cluster to be ready ==="
kubectl wait --for=condition=Ready cluster/"$BLUE_CLUSTER" -n "$NAMESPACE" --timeout=600s

echo ""
echo "✅ Blue cluster deployed!"
kubectl get cluster "$BLUE_CLUSTER" -n "$NAMESPACE"
kubectl get pods -l cnpg.io/cluster="$BLUE_CLUSTER" -n "$NAMESPACE"
echo ""
echo "Next: ./02-setup-replication.sh"
