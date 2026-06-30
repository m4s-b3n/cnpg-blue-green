#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-cnpg-demo}"

helm upgrade --install demo-app ./charts/demo-app \
	-n "${NAMESPACE}" \
	--wait --timeout=120s
