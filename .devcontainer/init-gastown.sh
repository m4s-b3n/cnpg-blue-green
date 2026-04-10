#!/usr/bin/env bash
set -euo pipefail

# Ensure brew-installed binaries are on PATH
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv 2>/dev/null || true)"

GT_HOME="/workspaces/cnpg-blue-green/.gt"

echo "=== Gas Town Setup ==="
echo ""

# --- 1. Verify dependencies ---
echo "--- Verifying dependencies ---"
gt version
bd version
dolt version
tmux -V
copilot --version || { echo "ERROR: GitHub Copilot CLI not found. Add ghcr.io/devcontainers/features/copilot-cli:1 to devcontainer.json"; exit 1; }
echo ""

# --- 2. Init Gas Town workspace ---
echo "--- Gas Town workspace ---"
if [ -d "$GT_HOME/mayor" ]; then
    echo "Workspace already exists at $GT_HOME, skipping init."
else
    gt install "$GT_HOME" --shell
fi
cd "$GT_HOME"
gt git-init || true
echo ""

# --- 3. Configure Copilot as default agent (Claude Opus 4.6) ---
echo "--- Configuring default agent ---"
cd "$GT_HOME"
gt config default-agent copilot
gt config agent set copilot 'copilot --yolo --model claude-opus-4.6'
echo "Agent set to: copilot --yolo --model claude-opus-4.6"
echo ""

# --- 4. SSH agent forwarding check ---
echo "--- Checking SSH agent forwarding ---"
if [ -z "${SSH_AUTH_SOCK:-}" ]; then
    echo "WARNING: SSH_AUTH_SOCK is not set."
    echo "  Make sure your host SSH agent is running and VS Code forwards it."
    echo ""
    read -rp "Continue anyway? [y/N] " yn
    [[ "$yn" =~ ^[Yy]$ ]] || exit 1
else
    echo "SSH_AUTH_SOCK is set: $SSH_AUTH_SOCK"
    if ssh-add -l &>/dev/null; then
        echo "SSH keys loaded:"
        ssh-add -l
    else
        echo "WARNING: No SSH keys found in agent. Run 'ssh-add' on your host."
    fi
fi
echo ""

# --- 5. Test SSH access to GitHub ---
echo "--- Testing SSH connection to GitHub ---"
if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "SSH to GitHub: OK"
else
    echo "WARNING: SSH to GitHub may have failed."
    ssh -T git@github.com 2>&1 || true
fi
echo ""

# --- 6. GitHub CLI authentication ---
echo "--- GitHub CLI authentication ---"
if gh auth status &>/dev/null; then
    echo "Already authenticated with GitHub CLI."
else
    echo "Authenticating with GitHub CLI..."
    gh auth login --git-protocol ssh
fi
echo ""

# --- 7. Configure git identity ---
echo "--- Git identity ---"
CURRENT_NAME=$(git config --global user.name 2>/dev/null || true)
CURRENT_EMAIL=$(git config --global user.email 2>/dev/null || true)

if [ -z "$CURRENT_NAME" ]; then
    read -rp "Your name for git commits: " CURRENT_NAME
    git config --global user.name "$CURRENT_NAME"
fi
if [ -z "$CURRENT_EMAIL" ]; then
    read -rp "Your email for git commits: " CURRENT_EMAIL
    git config --global user.email "$CURRENT_EMAIL"
fi
echo "Git identity: $CURRENT_NAME <$CURRENT_EMAIL>"
echo ""

# --- 8. Enable Gas Town ---
echo "--- Enabling Gas Town ---"
cd "$GT_HOME"
gt enable || true
gt shell install || true
echo ""

# --- 9. Add repo as a Gas Town rig ---
echo "--- Gas Town rig setup ---"
REPO_REMOTE=$(git -C /workspaces/cnpg-blue-green remote get-url origin 2>/dev/null || true)

if [ -n "$REPO_REMOTE" ]; then
    RIG_NAME=$(basename "$REPO_REMOTE" .git)
    # Gas Town doesn't allow hyphens/dots/spaces in rig names
    RIG_NAME=$(echo "$RIG_NAME" | tr '. -' '___')

    echo "Detected repo: $REPO_REMOTE -> rig '$RIG_NAME'"
    read -rp "Add as rig? [Y/n] " yn
    if [[ ! "$yn" =~ ^[Nn]$ ]]; then
        gt rig add "$RIG_NAME" "$REPO_REMOTE" || echo "Rig may already exist, continuing..."
    fi
fi
echo ""

# --- 10. Pre-trust Gas Town folders for Copilot CLI ---
echo "--- Trusting Gas Town folders in Copilot CLI ---"
COPILOT_CONFIG_DIR="${HOME}/.copilot"
COPILOT_CONFIG="${COPILOT_CONFIG_DIR}/config.json"
mkdir -p "$COPILOT_CONFIG_DIR"

# Collect all directories that gt agents will run in
TRUST_DIRS=("$GT_HOME")
for d in "$GT_HOME"/mayor "$GT_HOME"/deacon "$GT_HOME"/deacon/dogs/boot "$GT_HOME"/daemon; do
    [ -d "$d" ] && TRUST_DIRS+=("$d")
done
# Add rig directories (witness, refinery, crew, polecats)
for rig_dir in "$GT_HOME"/*/; do
    [ -d "${rig_dir}witness" ] && TRUST_DIRS+=("${rig_dir}witness")
    [ -d "${rig_dir}refinery" ] && TRUST_DIRS+=("${rig_dir}refinery")
    [ -d "${rig_dir}crew" ] && for crew in "${rig_dir}crew"/*/; do [ -d "$crew" ] && TRUST_DIRS+=("$crew"); done
    [ -d "${rig_dir}polecats" ] && for pc in "${rig_dir}polecats"/*/; do [ -d "$pc" ] && TRUST_DIRS+=("$pc"); done
done

# Build JSON array of folders to trust
TRUST_JSON=$(printf '%s\n' "${TRUST_DIRS[@]}" | jq -R . | jq -s .)

# Merge into copilot config (create if missing)
if [ -f "$COPILOT_CONFIG" ]; then
    jq --argjson folders "$TRUST_JSON" '.trusted_folders = ((.trusted_folders // []) + $folders | unique)' \
        "$COPILOT_CONFIG" > "${COPILOT_CONFIG}.tmp" && mv "${COPILOT_CONFIG}.tmp" "$COPILOT_CONFIG"
else
    echo "{\"trusted_folders\": $TRUST_JSON}" > "$COPILOT_CONFIG"
fi
echo "Trusted $(echo "$TRUST_JSON" | jq length) folder(s) in $COPILOT_CONFIG"
echo ""

# --- 11. Pre-flight fix (clean stale state) ---
echo "--- Pre-flight doctor fix ---"
cd "$GT_HOME"
gt doctor --fix --no-start 2>&1 || echo "WARNING: gt doctor --fix had issues (continuing)"
echo ""

# --- 12. Start services ---
echo "--- Starting Gas Town services ---"
cd "$GT_HOME"
if ! gt up; then
    echo ""
    echo "ERROR: gt up failed to start all services."
    echo "Attempting recovery: gt doctor --fix + gt up --restore ..."
    gt doctor --fix 2>&1 || true
    if ! gt up --restore; then
        echo "ERROR: gt up still failing after recovery attempt."
        echo "Run 'gt doctor' and 'gt status' to diagnose."
        # Don't exit — let the container finish setup so user can debug
    fi
fi
echo ""

# --- 13. Health check ---
echo "--- Running health check ---"
gt doctor || echo "WARNING: gt doctor reported issues. Run 'gt doctor --fix' to resolve."
echo ""
gt status || true
echo ""

# --- 14. Done ---
echo "=== Setup complete ==="
echo ""
echo "Quick start:"
echo "  cd $GT_HOME && gt mayor attach"
echo ""
echo "Useful commands:"
echo "  gt status          # workspace overview"
echo "  gt doctor          # health check"
echo "  gt dashboard       # web dashboard on :8080"
echo "  gt feed            # live agent activity TUI"
