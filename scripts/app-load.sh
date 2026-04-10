#!/usr/bin/env bash
set -euo pipefail

APP_REPO="${APP_REPO:-cnpg-bg-demo-app}"
APP_TAG="${APP_TAG:-latest}"
K3D_CLUSTER="${K3D_CLUSTER:-cnpg-demo}"

k3d image import "${APP_REPO}:${APP_TAG}" -c "${K3D_CLUSTER}"
echo "✅ App image loaded"
