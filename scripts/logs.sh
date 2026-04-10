#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-cnpg-demo}"

exec kubectl logs -f -l app.kubernetes.io/instance=demo-app -n "${NAMESPACE}"
