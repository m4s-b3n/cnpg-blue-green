#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-cnpg-demo}"
RELEASE="${RELEASE:-mydb}"
CHART="${CHART:-./charts/cnpg-bg}"
VALUES="${VALUES:-${CHART}/values.yaml}"
ACTIVE=$(kubectl get svc pg-rw -n "${NAMESPACE}" \
	-o jsonpath='{.spec.selector.cnpg\.io/cluster}')

case "${ACTIVE}" in
*-blue)
	FIRST=green
	SECOND=blue
	;;
*-green)
	FIRST=blue
	SECOND=green
	;;
*)
	echo "ERROR: cannot determine active cluster from pg-rw selector: ${ACTIVE}"
	exit 1
	;;
esac

echo "=== Active: ${ACTIVE} → upgrading ${FIRST} (standby) first ==="
helm upgrade "${RELEASE}-${FIRST}" "${CHART}" \
	-n "${NAMESPACE}" \
	-f "${VALUES}" \
	--set "mode=${FIRST}" \
	--timeout=600s

echo "=== Now upgrading ${SECOND} (no switchover) ==="
helm upgrade "${RELEASE}-${SECOND}" "${CHART}" \
	-n "${NAMESPACE}" \
	-f "${VALUES}" \
	--set "mode=${SECOND}" \
	--set hooks.switchoverEnabled=false \
	--set hooks.phaseHoldSeconds=4 \
	--timeout=600s

ACTIVE_AFTER=$(kubectl get svc pg-rw -n "${NAMESPACE}" \
	-o jsonpath='{.spec.selector.cnpg\.io/cluster}')
echo "✅ Upgrade complete — active: ${ACTIVE_AFTER}"
