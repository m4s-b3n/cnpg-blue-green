#!/usr/bin/env bash
set -euo pipefail

# Bidirectional Blue/Green Switchover using CNPG Distributed Topology
# Auto-detects which cluster is active and switches to the other

NAMESPACE="cnpg-demo"
BLUE_RELEASE="pg-blue"
GREEN_RELEASE="pg-green"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$SCRIPT_DIR/../helm/pg-cluster"
VALUES_DIR="$CHART_DIR/values"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()      { echo -e "${GREEN}[OK]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()     { echo -e "${RED}[ERROR]${NC} $1"; }

SOURCE="" TARGET="" SOURCE_RELEASE="" TARGET_RELEASE="" SOURCE_VALUES="" TARGET_VALUES=""

detect_active() {
  local blue_active green_active
  blue_active=$(kubectl get cluster "$BLUE_RELEASE" -n "$NAMESPACE" -o jsonpath='{.metadata.labels.active}' 2>/dev/null || echo "false")
  green_active=$(kubectl get cluster "$GREEN_RELEASE" -n "$NAMESPACE" -o jsonpath='{.metadata.labels.active}' 2>/dev/null || echo "false")

  if [[ "$blue_active" == "true" && "$green_active" != "true" ]]; then
    SOURCE="pg-blue"; TARGET="pg-green"
    SOURCE_RELEASE="$BLUE_RELEASE"; TARGET_RELEASE="$GREEN_RELEASE"
    SOURCE_VALUES="$VALUES_DIR/blue.yaml"; TARGET_VALUES="$VALUES_DIR/green.yaml"
    info "BLUE is active → switching to GREEN"
  elif [[ "$green_active" == "true" && "$blue_active" != "true" ]]; then
    SOURCE="pg-green"; TARGET="pg-blue"
    SOURCE_RELEASE="$GREEN_RELEASE"; TARGET_RELEASE="$BLUE_RELEASE"
    SOURCE_VALUES="$VALUES_DIR/green.yaml"; TARGET_VALUES="$VALUES_DIR/blue.yaml"
    info "GREEN is active → switching to BLUE"
  else
    err "Cannot detect active cluster (blue=$blue_active, green=$green_active)"
    exit 1
  fi
}

switchover() {
  echo ""
  echo "╔══════════════════════════════════════════════╗"
  echo "║  CNPG Blue/Green Switchover                  ║"
  echo "║  $SOURCE → $TARGET"
  echo "╚══════════════════════════════════════════════╝"
  echo ""

  # Step 1: Demote source
  info "Step 1/3: Demoting $SOURCE (setting primary=$TARGET)"
  helm upgrade "$SOURCE_RELEASE" "$CHART_DIR" \
    -n "$NAMESPACE" -f "$SOURCE_VALUES" \
    --set "distributedTopology.primary=$TARGET" \
    --set "bluegreen.active=false" \
    --wait --timeout=120s
  ok "$SOURCE demoted"

  # Step 2: Wait for demotion token
  info "Step 2/3: Waiting for demotion token..."
  local token="" attempts=60
  for ((i=1; i<=attempts; i++)); do
    token=$(kubectl get cluster "$SOURCE_RELEASE" -n "$NAMESPACE" \
      -o jsonpath='{.status.demotionToken}' 2>/dev/null || echo "")
    if [[ -n "$token" ]]; then
      ok "Demotion token acquired (attempt $i)"
      break
    fi
    sleep 2
  done

  if [[ -z "$token" ]]; then
    err "No demotion token after $attempts attempts — aborting"
    warn "Rolling back $SOURCE to primary..."
    helm upgrade "$SOURCE_RELEASE" "$CHART_DIR" \
      -n "$NAMESPACE" -f "$SOURCE_VALUES" \
      --set "distributedTopology.primary=$SOURCE" \
      --set "bluegreen.active=true" \
      --wait --timeout=120s
    exit 1
  fi

  # Step 3: Promote target
  info "Step 3/3: Promoting $TARGET with token"
  helm upgrade "$TARGET_RELEASE" "$CHART_DIR" \
    -n "$NAMESPACE" -f "$TARGET_VALUES" \
    --set "distributedTopology.primary=$TARGET" \
    --set "distributedTopology.promotionToken=$token" \
    --set "bluegreen.active=true" \
    --wait --timeout=120s
  ok "$TARGET promoted!"

  # Wait for both clusters
  info "Waiting for clusters to stabilize..."
  kubectl wait --for=condition=Ready cluster/"$TARGET_RELEASE" -n "$NAMESPACE" --timeout=300s
  kubectl wait --for=condition=Ready cluster/"$SOURCE_RELEASE" -n "$NAMESPACE" --timeout=300s

  echo ""
  echo "╔══════════════════════════════════════════════╗"
  echo "║  ✅ Switchover complete!                     ║"
  echo "║  Active: $TARGET"
  echo "║  Standby: $SOURCE"
  echo "╚══════════════════════════════════════════════╝"
  echo ""

  # Verify
  kubectl get clusters -n "$NAMESPACE"
  echo ""
  info "Run this script again to switch back"
}

detect_active
switchover
