#!/usr/bin/env bash
set -euo pipefail

HOOKS_IMAGE_REPO="${HOOKS_IMAGE_REPO:-ghcr.io/m4s-b3n/cnpg-blue-green/cnpg-bg-hooks}"
HOOKS_IMAGE_TAG="${HOOKS_IMAGE_TAG:-latest}"

echo "Building hooks image: ${HOOKS_IMAGE_REPO}:${HOOKS_IMAGE_TAG}"
docker build -f ./images/cnpg-bg-hooks/Dockerfile -t "${HOOKS_IMAGE_REPO}:${HOOKS_IMAGE_TAG}" .
