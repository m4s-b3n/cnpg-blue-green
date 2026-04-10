#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-cnpg-demo}"

echo "=== Clusters ==="
kubectl get clusters -n "${NAMESPACE}" -o wide 2>/dev/null || echo "No clusters"

echo ""
echo "=== Pods ==="
kubectl get pods -n "${NAMESPACE}" -L role,cnpg.io/cluster 2>/dev/null || echo "No pods"

echo ""
echo "=== Services ==="
kubectl get svc -n "${NAMESPACE}" 2>/dev/null || echo "No services"

echo ""
echo "=== Active cluster ==="
kubectl get svc pg-rw -n "${NAMESPACE}" \
	-o jsonpath='{.spec.selector.cnpg\.io/cluster}' 2>/dev/null
echo ""
