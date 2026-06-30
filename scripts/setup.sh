#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"

K3D_CLUSTER="${K3D_CLUSTER:-cnpg-demo}"
NAMESPACE="${NAMESPACE:-cnpg-demo}"
CNPG_CHART_VERSION="${CNPG_CHART_VERSION:-0.28.2}"
# Keep these in sync with charts/cnpg-bg/values.yaml
POSTGRES_IMAGE="${POSTGRES_IMAGE:-ghcr.io/cloudnative-pg/postgresql:17.10}"
PGBOUNCER_IMAGE="${PGBOUNCER_IMAGE:-ghcr.io/cloudnative-pg/pgbouncer:1.25.2}"
CACHE_DIR="${CACHE_DIR:-${REPO_ROOT}/charts/cache}"
CHART_TARBALL="${CACHE_DIR}/cloudnative-pg-${CNPG_CHART_VERSION}.tgz"

echo "=== Creating k3d cluster: ${K3D_CLUSTER} ==="
if k3d cluster list | grep -q "${K3D_CLUSTER}"; then
	echo "Cluster ${K3D_CLUSTER} already exists"
else
	k3d cluster create "${K3D_CLUSTER}" --servers 1 --agents 2 --wait
fi

kubectl wait --for=condition=Ready nodes --all --timeout=120s
kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

# ─── Load prefetched infra images into k3d (no-op if not cached) ─────────────
echo "=== Loading cached infra images into cluster ==="
INFRA_IMAGES=("${POSTGRES_IMAGE}" "${PGBOUNCER_IMAGE}")

# Also include operator images if chart tarball is cached
if [[ -f "${CHART_TARBALL}" ]]; then
	while IFS= read -r img; do
		[[ -n "${img}" ]] && INFRA_IMAGES+=("${img}")
	done < <(helm template cnpg "${CHART_TARBALL}" |
		awk '/^\s+image:/{print $2}' | tr -d '"' | sort -u)
fi

for img in "${INFRA_IMAGES[@]}"; do
	if docker image inspect "${img}" &>/dev/null 2>&1; then
		echo "  → Importing ${img}"
		k3d image import "${img}" -c "${K3D_CLUSTER}"
	else
		echo "  → ${img} not in local Docker, will be pulled at runtime"
	fi
done

# ─── Install CNPG operator ────────────────────────────────────────────────────
echo "=== Installing CNPG operator (chart ${CNPG_CHART_VERSION}) ==="
if [[ -f "${CHART_TARBALL}" ]]; then
	echo "  → Using cached chart: ${CHART_TARBALL}"
	CNPG_CHART_REF="${CHART_TARBALL}"
else
	echo "  → Downloading chart from helm repo"
	helm repo add cnpg https://cloudnative-pg.github.io/charts 2>/dev/null || true
	helm repo update cnpg
	CNPG_CHART_REF="cnpg/cloudnative-pg"
fi

kubectl create namespace cnpg-system --dry-run=client -o yaml | kubectl apply -f -
helm upgrade --install cnpg "${CNPG_CHART_REF}" \
	-n cnpg-system --version "${CNPG_CHART_VERSION}" --wait
kubectl wait --for=condition=Available deployment/cnpg-cloudnative-pg \
	-n cnpg-system --timeout=120s

echo "✅ Setup complete (cluster: ${K3D_CLUSTER}, operator: ${CNPG_CHART_VERSION})"
