#!/usr/bin/env bash
# Live monitor for Blue/Green switchover demo.
# Reads phase from cnpg-bg-status ConfigMap (written by hook scripts).
set -uo pipefail

NAMESPACE="${NAMESPACE:-cnpg-demo}"
BLUE="myapp-blue"
GREEN="myapp-green"
INTERVAL="${INTERVAL:-1}"

# Colors
BOLD='\033[1m'
DIM='\033[2m'
GRN='\033[0;32m'
YEL='\033[1;33m'
BLU='\033[0;34m'
RST='\033[0m'

phase_color() {
	case "$1" in
	IDLE) echo "${GRN}" ;;
	*) echo "${YEL}" ;;
	esac
}

# Hide cursor, restore on exit
tput civis 2>/dev/null
trap 'tput cnorm 2>/dev/null; exit' INT TERM EXIT

PREV_PHASE=""
PHASE_CHANGED_AT=0
MIN_PHASE_DISPLAY=2 # seconds to show each phase minimum

while true; do
	# Read phase from ConfigMap
	STATUS_JSON=$(kubectl get configmap cnpg-bg-status -n "$NAMESPACE" -o json 2>/dev/null)
	NEW_PHASE=$(echo "$STATUS_JSON" | jq -r '.data.phase // "IDLE"')
	NEW_MSG=$(echo "$STATUS_JSON" | jq -r '.data.message // ""')

	# Hold previous phase for at least MIN_PHASE_DISPLAY seconds
	NOW=$(date +%s)
	if [[ "$NEW_PHASE" != "$PREV_PHASE" ]]; then
		ELAPSED=$((NOW - PHASE_CHANGED_AT))
		if [[ $ELAPSED -ge $MIN_PHASE_DISPLAY || -z "$PREV_PHASE" ]]; then
			PHASE="$NEW_PHASE"
			PHASE_MSG="$NEW_MSG"
			PREV_PHASE="$PHASE"
			PHASE_CHANGED_AT=$NOW
		else
			PHASE="$PREV_PHASE"
			# keep old PHASE_MSG
		fi
	else
		PHASE="$NEW_PHASE"
		PHASE_MSG="$NEW_MSG"
	fi

	# Gather cluster state
	SVC_TARGET=$(kubectl get svc pg-rw -n "$NAMESPACE" -o jsonpath='{.spec.selector.cnpg\.io/cluster}' 2>/dev/null)

	BLUE_JSON=$(kubectl get cluster "$BLUE" -n "$NAMESPACE" -o json 2>/dev/null)
	GREEN_JSON=$(kubectl get cluster "$GREEN" -n "$NAMESPACE" -o json 2>/dev/null)

	BLUE_PRIMARY=$(echo "$BLUE_JSON" | jq -r '.spec.replica.primary // empty')
	GREEN_PRIMARY=$(echo "$GREEN_JSON" | jq -r '.spec.replica.primary // empty')
	BLUE_SELF=$(echo "$BLUE_JSON" | jq -r '.spec.replica.self // empty')
	GREEN_SELF=$(echo "$GREEN_JSON" | jq -r '.spec.replica.self // empty')
	BLUE_PHASE=$(echo "$BLUE_JSON" | jq -r '.status.phase // "unknown"')
	GREEN_PHASE=$(echo "$GREEN_JSON" | jq -r '.status.phase // "unknown"')
	BLUE_READY=$(echo "$BLUE_JSON" | jq -r '.status.readyInstances // 0')
	GREEN_READY=$(echo "$GREEN_JSON" | jq -r '.status.readyInstances // 0')
	BLUE_INSTANCES=$(echo "$BLUE_JSON" | jq -r '.spec.instances // 0')
	GREEN_INSTANCES=$(echo "$GREEN_JSON" | jq -r '.spec.instances // 0')

	# Hook pod running?
	HOOK_POD=$(kubectl get pods -n "$NAMESPACE" -l "cnpg-blue-green/hook=post-upgrade" \
		--field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

	# Determine roles
	if [[ "$SVC_TARGET" == "$BLUE" ]]; then
		ACTIVE_COLOR="$BLU"
	else
		ACTIVE_COLOR="$GRN"
	fi
	PCOLOR=$(phase_color "$PHASE")

	# Cluster display
	if [[ "$SVC_TARGET" == "$BLUE" ]]; then
		BLUE_ROLE="${BLU}${BOLD}PRIMARY${RST}"
	else
		BLUE_ROLE="${DIM}standby${RST}"
	fi
	[[ "$BLUE_PHASE" == *"healthy"* ]] && BLUE_HEALTH="${GRN}●${RST}" || BLUE_HEALTH="${YEL}◌${RST}"

	if [[ "$SVC_TARGET" == "$GREEN" ]]; then
		GREEN_ROLE="${GRN}${BOLD}PRIMARY${RST}"
	else
		GREEN_ROLE="${DIM}standby${RST}"
	fi
	[[ "$GREEN_PHASE" == *"healthy"* ]] && GREEN_HEALTH="${GRN}●${RST}" || GREEN_HEALTH="${YEL}◌${RST}"

	HOOK_LINE="${DIM}No hook running${RST}"
	if [[ -n "$HOOK_POD" ]]; then
		HOOK_LINE="${YEL}⚡ Hook:${RST} ${HOOK_POD}"
	fi

	# Render: move cursor home, print fixed-height frame
	tput cup 0 0
	tput el
	echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${RST}"
	tput el
	echo -e "${BOLD}║  CNPG Blue/Green Monitor                                    ║${RST}"
	tput el
	echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${RST}"
	tput el
	echo ""
	tput el
	echo -e "  ${DIM}$(date '+%H:%M:%S')${RST}  Phase: ${PCOLOR}${BOLD}${PHASE}${RST}"
	tput el
	echo -e "  ${DIM}${PHASE_MSG}${RST}"
	tput el
	echo ""
	tput el
	echo -e "  ┌─────────────────────────────────────────────────────────┐"
	tput el
	echo -e "  │  ${BOLD}pg-rw${RST} → ${ACTIVE_COLOR}${BOLD}${SVC_TARGET}${RST}"
	tput el
	echo -e "  └─────────────────────────────────────────────────────────┘"
	tput el
	echo ""
	tput el
	printf "  %b %-14b  %-20b  ready: %s/%s\n" "$BLUE_HEALTH" "${BLU}${BLUE}${RST}" "$BLUE_ROLE" "$BLUE_READY" "$BLUE_INSTANCES"
	tput el
	printf "    ${DIM}primary: %-14s  self: %-14s${RST}\n" "$BLUE_PRIMARY" "$BLUE_SELF"
	tput el
	echo ""
	tput el
	printf "  %b %-14b  %-20b  ready: %s/%s\n" "$GREEN_HEALTH" "${GRN}${GREEN}${RST}" "$GREEN_ROLE" "$GREEN_READY" "$GREEN_INSTANCES"
	tput el
	printf "    ${DIM}primary: %-14s  self: %-14s${RST}\n" "$GREEN_PRIMARY" "$GREEN_SELF"
	tput el
	echo ""
	tput el
	echo -e "  ┌─────────────────────────────────────────────────────────┐"
	tput el
	echo -e "  │  ${HOOK_LINE}"
	tput el
	echo -e "  └─────────────────────────────────────────────────────────┘"
	tput el
	echo ""
	tput el
	echo -e "  ${DIM}1) PAUSE → 2) DEMOTE → 3) PROMOTE → 4) PATCH & RESUME${RST}"
	tput ed

	sleep "$INTERVAL"
done
