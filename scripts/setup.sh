#!/usr/bin/env bash
set -euo pipefail

K3D_CLUSTER="${K3D_CLUSTER:-cnpg-demo}"
NAMESPACE="${NAMESPACE:-cnpg-demo}"
CNPG_CHART_VERSION="${CNPG_CHART_VERSION:-0.28.2}"

echo "=== Creating k3d cluster: ${K3D_CLUSTER} ==="
if k3d cluster list | grep -q "${K3D_CLUSTER}"; then
	echo "Cluster ${K3D_CLUSTER} already exists"
else
	k3d cluster create "${K3D_CLUSTER}" --servers 1 --agents 2 --wait
fi

kubectl wait --for=condition=Ready nodes --all --timeout=120s
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

echo "=== Installing CNPG operator (chart ${CNPG_CHART_VERSION}) ==="
helm repo add cnpg https://cloudnative-pg.github.io/charts 2>/dev/null || true
helm repo update cnpg
kubectl create namespace cnpg-system --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install cnpg cnpg/cloudnative-pg \
	-n cnpg-system --version "${CNPG_CHART_VERSION}" --wait
kubectl wait --for=condition=Available deployment/cnpg-cloudnative-pg \
	-n cnpg-system --timeout=120s

echo "✅ Setup complete (cluster: ${K3D_CLUSTER}, operator: ${CNPG_CHART_VERSION})"
