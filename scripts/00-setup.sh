#!/usr/bin/env bash
set -euo pipefail

# Create k3d cluster and install CNPG operator
CLUSTER_NAME="cnpg-demo"
NAMESPACE="cnpg-demo"

echo "=== Creating k3d cluster: $CLUSTER_NAME ==="
if k3d cluster list | grep -q "$CLUSTER_NAME"; then
  echo "Cluster $CLUSTER_NAME already exists, skipping creation"
else
  k3d cluster create "$CLUSTER_NAME" \
    --servers 1 \
    --agents 2 \
    --wait
fi

echo "=== Waiting for cluster to be ready ==="
kubectl wait --for=condition=Ready nodes --all --timeout=120s

echo "=== Creating namespace: $NAMESPACE ==="
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

echo "=== Installing CNPG operator ==="
helm repo add cnpg https://cloudnative-pg.github.io/charts 2>/dev/null || true
helm repo update cnpg

if helm list -n cnpg-system | grep -q cnpg; then
  echo "CNPG operator already installed, upgrading..."
  helm upgrade cnpg cnpg/cloudnative-pg -n cnpg-system --wait
else
  kubectl create namespace cnpg-system --dry-run=client -o yaml | kubectl apply -f -
  helm install cnpg cnpg/cloudnative-pg -n cnpg-system --wait
fi

echo "=== Waiting for CNPG operator to be ready ==="
kubectl wait --for=condition=Available deployment/cnpg-cloudnative-pg -n cnpg-system --timeout=120s

echo ""
echo "✅ Setup complete!"
echo "   Cluster: $CLUSTER_NAME"
echo "   Namespace: $NAMESPACE"
echo "   CNPG operator: installed"
echo ""
echo "Next: ./01-deploy-blue.sh"
