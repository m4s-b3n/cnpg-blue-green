#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "${SCRIPT_DIR}")"

CNPG_CHART_VERSION="${CNPG_CHART_VERSION:-0.28.2}"
HOOKS_IMAGE_REPO="${HOOKS_IMAGE_REPO:-ghcr.io/m4s-b3n/cnpg-blue-green/cnpg-bg-hooks}"
HOOKS_IMAGE_TAG="${HOOKS_IMAGE_TAG:-latest}"
APP_REPO="${APP_REPO:-ghcr.io/m4s-b3n/cnpg-blue-green/demo-app}"
APP_TAG="${APP_TAG:-latest}"
# Keep these in sync with charts/cnpg-bg/values.yaml
POSTGRES_IMAGE="${POSTGRES_IMAGE:-ghcr.io/cloudnative-pg/postgresql:17.10}"
PGBOUNCER_IMAGE="${PGBOUNCER_IMAGE:-ghcr.io/cloudnative-pg/pgbouncer:1.25.2}"
CACHE_DIR="${CACHE_DIR:-${REPO_ROOT}/charts/cache}"

mkdir -p "${CACHE_DIR}"

# ─── Helm chart ──────────────────────────────────────────────────────────────
echo "=== Fetching CNPG helm chart v${CNPG_CHART_VERSION} ==="
helm repo add cnpg https://cloudnative-pg.github.io/charts 2>/dev/null || true
helm repo update cnpg

CHART_TARBALL="${CACHE_DIR}/cloudnative-pg-${CNPG_CHART_VERSION}.tgz"
if [[ ! -f "${CHART_TARBALL}" ]]; then
	helm pull cnpg/cloudnative-pg --version "${CNPG_CHART_VERSION}" \
		--destination "${CACHE_DIR}"
	echo "  → Saved to ${CHART_TARBALL}"
else
	echo "  → Already cached: ${CHART_TARBALL}"
fi

# ─── Images ──────────────────────────────────────────────────────────────────
echo "=== Pulling images ==="

# Extract all images referenced in the CNPG operator chart
OPERATOR_IMAGES=$(helm template cnpg "${CHART_TARBALL}" |
	awk '/^\s+image:/{print $2}' | tr -d '"' | sort -u)

IMAGES=(
	"${POSTGRES_IMAGE}"
	"${PGBOUNCER_IMAGE}"
	"${HOOKS_IMAGE_REPO}:${HOOKS_IMAGE_TAG}"
	"${APP_REPO}:${APP_TAG}"
)

while IFS= read -r img; do
	[[ -n "${img}" ]] && IMAGES+=("${img}")
done <<<"${OPERATOR_IMAGES}"

for img in "${IMAGES[@]}"; do
	echo "  → docker pull ${img}"
	docker pull "${img}"
done

echo "✅ Prefetch complete"
echo "   Helm chart : ${CHART_TARBALL}"
echo "   Images     : ${#IMAGES[@]} pulled to local Docker daemon"
echo "   Run 'make setup' to create the cluster and load everything offline"
