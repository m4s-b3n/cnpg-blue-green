#!/usr/bin/env bash
set -euo pipefail

HOOKS_IMAGE_REPO="${HOOKS_IMAGE_REPO:-ghcr.io/m4s-b3n/cnpg-blue-green/cnpg-bg-hooks}"
HOOKS_IMAGE_TAG="${HOOKS_IMAGE_TAG:-latest}"
K3D_CLUSTER="${K3D_CLUSTER:-cnpg-demo}"

for node in server-0 agent-0 agent-1; do
	docker exec "k3d-${K3D_CLUSTER}-${node}" crictl rmi \
		"${HOOKS_IMAGE_REPO}:${HOOKS_IMAGE_TAG}" 2>/dev/null || true
done
k3d image import "${HOOKS_IMAGE_REPO}:${HOOKS_IMAGE_TAG}" -c "${K3D_CLUSTER}"
echo "✅ Hooks image loaded"
