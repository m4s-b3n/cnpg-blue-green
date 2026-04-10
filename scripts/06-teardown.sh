#!/usr/bin/env bash
set -euo pipefail

CLUSTER_NAME="cnpg-demo"

echo "=== Tearing down demo ==="

echo "Deleting k3d cluster: $CLUSTER_NAME"
k3d cluster delete "$CLUSTER_NAME" 2>/dev/null || echo "Cluster not found"

echo ""
echo "✅ Teardown complete!"
