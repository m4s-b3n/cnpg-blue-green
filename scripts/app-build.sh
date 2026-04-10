#!/usr/bin/env bash
set -euo pipefail

APP_REPO="${APP_REPO:-cnpg-bg-demo-app}"
APP_TAG="${APP_TAG:-latest}"

echo "Building app image: ${APP_REPO}:${APP_TAG}"
docker build -f ./images/demo-app/Dockerfile -t "${APP_REPO}:${APP_TAG}" .
