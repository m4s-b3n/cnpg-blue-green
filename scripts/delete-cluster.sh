#!/usr/bin/env bash
set -euo pipefail

K3D_CLUSTER="${K3D_CLUSTER:-cnpg-demo}"

echo "Deleting k3d cluster: ${K3D_CLUSTER}"
k3d cluster delete "${K3D_CLUSTER}"
echo "✅ Cluster ${K3D_CLUSTER} deleted"
