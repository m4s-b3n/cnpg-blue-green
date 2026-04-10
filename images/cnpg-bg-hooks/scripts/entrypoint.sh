#!/usr/bin/env bash
set -euo pipefail

# Entrypoint for the CNPG Blue/Green hook container.
# Dispatches to the appropriate script based on HOOK_ACTION env var.

ACTION="${HOOK_ACTION:-}"

case "$ACTION" in
post-install)
	exec /scripts/post-install.sh
	;;
post-upgrade)
	exec /scripts/post-upgrade.sh
	;;
health-check)
	exec /scripts/health-check.sh
	;;
switchover)
	exec /scripts/switchover.sh
	;;
*)
	echo "ERROR: Unknown HOOK_ACTION: '$ACTION'"
	echo "Valid actions: post-install, post-upgrade, health-check, switchover"
	exit 1
	;;
esac
