#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-cnpg-demo}"
RELEASE="${RELEASE:-mydb}"
CHART="${CHART:-./charts/cnpg-bg}"
VALUES="${VALUES:-${CHART}/values.yaml}"
echo "=== Installing infra (services, pgbouncer, secrets) ==="
helm upgrade --install "${RELEASE}-infra" "${CHART}" \
	-n "${NAMESPACE}" --create-namespace \
	-f "${VALUES}" \
	--set mode=infra \
	--wait --timeout=120s

echo "=== Installing blue cluster ==="
helm upgrade --install "${RELEASE}-blue" "${CHART}" \
	-n "${NAMESPACE}" \
	-f "${VALUES}" \
	--set mode=blue \
	--set hooks.phaseHoldSeconds=2 \
	--wait --timeout=600s

echo "=== Installing green cluster ==="
helm upgrade --install "${RELEASE}-green" "${CHART}" \
	-n "${NAMESPACE}" \
	-f "${VALUES}" \
	--set mode=green \
	--set hooks.phaseHoldSeconds=2 \
	--wait --timeout=600s

echo "✅ Blue/Green database deployed"
