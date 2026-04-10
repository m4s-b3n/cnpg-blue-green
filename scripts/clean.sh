#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-cnpg-demo}"
RELEASE="${RELEASE:-mydb}"

echo "Removing demo app..."
helm uninstall demo-app -n "${NAMESPACE}" 2>/dev/null || true
echo "Removing green cluster..."
helm uninstall "${RELEASE}-green" -n "${NAMESPACE}" 2>/dev/null || true
echo "Removing blue cluster..."
helm uninstall "${RELEASE}-blue" -n "${NAMESPACE}" 2>/dev/null || true
echo "Removing infra..."
helm uninstall "${RELEASE}-infra" -n "${NAMESPACE}" 2>/dev/null || true
echo "Cleaning up leftover resources..."
kubectl delete jobs --all -n "${NAMESPACE}" 2>/dev/null || true
kubectl delete clusters --all -n "${NAMESPACE}" 2>/dev/null || true
kubectl delete pvc --all -n "${NAMESPACE}" 2>/dev/null || true
echo "✅ Namespace ${NAMESPACE} cleaned (operator + cluster still running)"
