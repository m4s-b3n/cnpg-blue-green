#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-cnpg-demo}"

helm upgrade --install demo-app oci://ghcr.io/cotzo/charts/chartpack --version 2.1.0 \
	-n "${NAMESPACE}" \
	-f ./deploy/demo-app/values.yaml \
	--wait --timeout=120s
