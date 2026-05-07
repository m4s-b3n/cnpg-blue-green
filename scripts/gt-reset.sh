#!/usr/bin/env bash
set -euo pipefail

# Gas Town Reset Script
# Clears all stale beads, convoys, and zombie sessions, then starts fresh.
# Use when the Mayor is stuck in a restart loop or the system is noisy.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GT_DIR="$SCRIPT_DIR/../.gt"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()   { echo -e "${RED}[ERROR]${NC} $1"; }

cd "$GT_DIR"

# ── Step 1: Stop everything ─────────────────────────────────────
info "Step 1/6: Stopping all Gas Town services..."
gt down --all 2>&1 || true
ok "All services stopped"

# ── Step 2: Fix permissions ──────────────────────────────────────
info "Step 2/6: Fixing .beads permissions..."
chmod 700 "$GT_DIR/.beads" 2>/dev/null || true
ok "Permissions fixed"

# ── Step 3: Start Dolt (needed for bead operations) ─────────────
info "Step 3/6: Starting Dolt..."
gt dolt start 2>&1
sleep 2
if ! gt dolt status &>/dev/null; then
  err "Dolt failed to start — cannot clear beads"
  exit 1
fi
ok "Dolt running"

# ── Step 4: Close all open beads ─────────────────────────────────
info "Step 4/6: Closing stale beads..."
open_count=0
while true; do
  ids=$(bd list --status=open 2>&1 | grep '^○' | awk '{print $2}')
  if [[ -z "$ids" ]]; then
    break
  fi
  count=$(echo "$ids" | wc -w)
  open_count=$((open_count + count))
  echo "$ids" | xargs bd close --force --reason="gt-reset: clearing for fresh start" 2>&1 | grep -c '✓' || true
done
ok "Closed $open_count stale beads"

# ── Step 5: Close all convoys ────────────────────────────────────
info "Step 5/6: Closing stale convoys..."
convoy_count=0
convoy_ids=$(gt convoy list 2>&1 | grep -oP 'hq-[a-z0-9-]+' || true)
if [[ -n "$convoy_ids" ]]; then
  for cid in $convoy_ids; do
    gt convoy close "$cid" --force 2>&1 || true
    convoy_count=$((convoy_count + 1))
  done
fi
ok "Closed $convoy_count convoys"

# ── Step 6: Clean up zombie sessions and orphan processes ────────
info "Step 6/6: Cleaning up zombies and orphans..."
gt cleanup --force 2>&1 || true
ok "Cleanup done"

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║  Gas Town reset complete                     ║"
echo "║  Beads closed:   $open_count"
echo "║  Convoys closed: $convoy_count"
echo "╚══════════════════════════════════════════════╝"
echo ""
info "Ready to start fresh:"
echo "  gt up && gt mayor attach"
