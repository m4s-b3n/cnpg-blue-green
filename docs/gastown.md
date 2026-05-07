# Gas Town

Gas Town (`gt`) is the multi-agent orchestration system embedded in this repository. It coordinates AI agent workers that handle development tasks — code changes, issue triage, merge queue processing, and more — across the codebase.

All Gas Town state lives in the `.gt/` directory at the repository root.

## Quick Start

Get up and running in two commands:

```bash
cd .gt
gt mayor start     # Start the Mayor (boots infrastructure automatically)
gt mayor attach    # Attach to the Mayor's terminal session
```

You are now in a live conversation with the Mayor — Gas Town's global coordinator and your primary interface to the agent workforce. Tell it what you need done.

Detach from the session with **`Ctrl-B D`** (the Mayor keeps running in the background).

Re-attach any time with `gt mayor attach`.

> **VS Code shortcut:** Run the task **"Gas Town: Start & Attach Mayor"** to do all of the above in one step.
>
> **Note:** Avoid `gt up` — it tries to start all infrastructure agents (Deacon, Witness, Refinery) sequentially and can hang. For interactive use you only need the Mayor.

## Prerequisites

The `gt` CLI must be installed and available on your `PATH`. In the dev container this is already the case.

## Starting & Stopping

### Start

```bash
cd .gt && gt up
```

This boots all long-lived infrastructure services:

| Service    | Purpose                                    |
| ---------- | ------------------------------------------ |
| Dolt       | Shared SQL database for beads (work items) |
| Daemon     | Background process that pokes agents       |
| Deacon     | Health orchestrator                        |
| Mayor      | Global work coordinator                    |
| Witnesses  | Per-rig polecat (worker) managers          |
| Refineries | Per-rig merge queue processors             |

Running `gt up` is idempotent — it only starts services that aren't already running.

Use `gt up --restore` to additionally restore crew sessions and polecats that have pinned work.

### Stop

```bash
cd .gt && gt down
```

Shutdown levels (progressively more aggressive):

```bash
gt down                # Stop infrastructure (default)
gt down --polecats     # Also stop all polecat sessions
gt down --all          # Full shutdown with orphan cleanup
gt down --nuke         # Also kill the shared tmux server
```

This is a pause operation — state is preserved and `gt up` brings everything back.

## Checking Status

```bash
cd .gt && gt status
```

Shows registered rigs, running agents, and witness health. Useful flags:

- `--fast` — skip mail lookups for quicker output
- `--watch` / `-w` — continuously refresh (default 2 s interval)
- `--verbose` / `-v` — detailed multi-line output per agent

## Activity Feed

```bash
cd .gt && gt feed
```

Opens an interactive TUI dashboard with:

- **Agent tree** — all agents organized by role with latest activity
- **Convoy panel** — in-progress and recently landed convoys
- **Event stream** — chronological, scrollable feed

Navigation: `j`/`k` to scroll, `Tab` to switch panels, `q` to quit.

For a non-interactive snapshot:

```bash
gt feed --limit 50 --no-follow --plain
```

## Talking to the Mayor

The Mayor is the global coordinator and your **primary interaction point**. It receives your requests, dispatches work to polecats, handles escalations, and reports back.

### Start the Mayor

```bash
gt mayor start           # Launch Mayor in a detached tmux session
gt mayor start --agent claude-sonnet  # Override with a specific model
```

### Attach / Detach

```bash
gt mayor attach          # Connect your terminal to the Mayor session
```

- **Detach:** `Ctrl-B D` — Mayor keeps running in the background.
- **Re-attach:** `gt mayor attach` any time.

### Other Mayor commands

```bash
gt mayor status          # Is the Mayor running?
gt mayor restart         # Restart the session
gt mayor stop            # Stop the Mayor
```

## Dispatching Work

The primary command for assigning work is `gt sling`:

```bash
gt sling <bead-id> <target>
```

Examples:

```bash
gt sling cbg-42 cnpg_blue_green   # Spawn a polecat in this rig
gt sling cbg-42 crew              # Assign to a crew worker
gt sling cbg-42 mayor             # Assign to the Mayor
```

Merge strategy can be specified:

```bash
gt sling cbg-42 cnpg_blue_green --merge=direct  # Push to main
gt sling cbg-42 cnpg_blue_green --merge=mr      # Merge queue (default)
```

## VS Code Tasks

The repo ships pre-configured VS Code tasks (`.vscode/tasks.json`) for common operations:

| Task                              | Shortcut      | Description                              |
| --------------------------------- | ------------- | ---------------------------------------- |
| Gas Town: Start & Attach Mayor    | —             | Boot services + open Mayor terminal      |
| Gas Town: Start (gt up)           | Default build | Start all services                       |
| Gas Town: Stop (gt down)          | —             | Pause all services                       |
| Gas Town: Status                  | —             | Print current status                     |
| Gas Town: Feed                    | —             | Show recent activity (plain)             |
| Gas Town: Reset (clear stale state) | —           | Stop everything, close stale beads/convoys, clean up |

Run via **Terminal → Run Task…** or the Command Palette (`Ctrl+Shift+P` → "Tasks: Run Task").

## Monitoring Work

Once you have given the Mayor a task, there are several ways to see what is happening.

### What is being worked on right now?

```bash
gt agents              # List all running agent sessions (Mayor, Witnesses, Crew, etc.)
gt hook                # Show what's on your own hook (current work item)
gt convoy list         # List all convoys — the primary tracking units for batched work
gt convoy status <id>  # Detailed progress for a specific convoy
```

### What happened recently?

```bash
gt trail                       # Recent agent commits
gt trail beads                 # Recent work items (beads) created/updated
gt trail hooks                 # Recent hook activity (who picked up what)
gt trail --since 1h            # Limit to the last hour
```

### What is ready / done?

```bash
gt ready               # Work items with no blockers, ready to be picked up
gt changelog           # Completed work (defaults to this week)
gt changelog --today   # Just today's completions
```

### Live dashboard

```bash
gt feed                # Interactive TUI: agents, convoys, event stream
gt feed -p             # Problems view — surfaces stuck agents
gt status --watch      # Continuously refreshing status
```

## Useful Commands Reference

```bash
gt status          # Overall town health
gt feed            # Real-time activity TUI
gt vitals          # Unified health dashboard
gt doctor          # Run health checks
gt costs           # Show costs for Claude sessions
gt trail           # Recent agent activity log
gt changelog       # Completed work summary
gt dolt status     # Database server health
gt dolt cleanup    # Remove orphan test databases
```

## Configuration

Agent model assignments live in `.gt/settings/config.json`. The key section is `role_agents`, which maps each Gas Town role to a model alias:

```json
"role_agents": {
  "boot": "gpt-free",
  "deacon": "gpt-free",
  "dog": "gpt-free",
  "mayor": "claude-opus",
  "polecat": "claude-sonnet",
  "refinery": "claude-haiku",
  "witness": "claude-haiku"
}
```

### Model strategy

The `agents` section in the config defines aliases that map to actual model IDs. Each alias specifies the `--model` argument passed to the `copilot` CLI:

| Alias | Model ID | Tier | Cost |
|-------|----------|------|------|
| `claude-opus` | `claude-opus-4.6` | premium | paid |
| `claude-sonnet` | `claude-sonnet-4.6` | standard | paid |
| `claude-haiku` | `claude-haiku-4.5` | fast | paid |
| `gpt-free` | `gpt-4.1` | fast | **free** |

The `role_agents` section then assigns aliases to roles:

| Role | Alias | What it does | Rationale |
|------|-------|-------------|-----------|
| **Mayor** | `claude-opus` | Plans, reasons, coordinates | The brain — needs the strongest model |
| **Polecats** | `claude-sonnet` | Execute real work (code, slides, etc.) | Coding + debugging tasks |
| Refinery | `claude-haiku` | Processes merge queue | Procedural, follows fixed steps |
| Witness | `claude-haiku` | Monitors/respawns polecats | Procedural, follows fixed steps |
| Boot | `gpt-free` | Watches Deacon liveness | Pure health check — no reasoning |
| Deacon | `gpt-free` | Runs patrol formula | Follows fixed formula — no reasoning |
| Dog | `gpt-free` | Cleanup tasks (reaping, compaction) | Executes specific commands — no reasoning |

Polecats (the workers that do actual coding/content work) are explicitly assigned `claude-sonnet`. Override per-sling with `--agent`:

```bash
gt sling cbg-42 cnpg_blue_green --agent claude-opus  # Use Opus for tasks needing heavy reasoning
```

To list all available models:

```bash
copilot -p "list available models" --yolo -s
```

### Patrols (daemon config)

The file `.gt/mayor/daemon.json` controls automated health patrols — periodic checks that the Deacon, Witnesses, and other agents run. These are required for autonomous multi-agent work (polecats, merge queue, health monitoring).

All patrol entries have an `"enabled"` flag. If you need to disable them temporarily for debugging:

```json
"heartbeat": { "enabled": false, ... },
"patrols": {
  "refinery": { "enabled": false, ... },
  "witness":  { "enabled": false, ... },
  ...
}
```

> **Warning:** Disabling the heartbeat will cause `gt up` to report the daemon as failed, which cascades into Deacon/Witness failures.

## Troubleshooting

### Mayor keeps restarting (context loop)

If the Mayor exits repeatedly every 1–3 minutes without doing real work, it is stuck in a **patrol loop**: each restart, it processes patrol formulas and handoff messages that fill the context window before it can get to your task.

Symptoms — `gt feed` shows many `session_start` events for the Mayor in quick succession.

Fix:

1. Stop the Mayor: `gt mayor stop`
2. Disable patrols in `.gt/mayor/daemon.json` (set all `"enabled"` to `false`) — see [Configuration](#configuration) above.
3. Restart: `gt mayor start && gt mayor attach`

### Mayor crashed or exited mid-task

This is the most common problem. The Mayor's session can exit due to context limits, errors, or manual interruption. Here is how to recover:

1. **Check if the task is still tracked:**
   ```bash
   gt convoy list         # Is there a convoy for your task?
   gt trail beads         # Was a bead created for it?
   gt ready               # Did it land back in the ready queue?
   ```
   Work in Gas Town is tracked via **beads** (durable work items stored in Dolt). If a bead was created before the crash, the work is not lost — it just needs to be picked up again.

2. **Restart the Mayor:**
   ```bash
   gt mayor restart       # Respawns with a fresh Claude session
   gt mayor attach        # Attach to the new session
   ```

3. **Check if the Mayor remembers:**
   After restarting, the Mayor runs `gt resume` automatically to check for handoff messages. If there is a bead on its hook, it will continue from where it left off.

   If it does *not* pick up automatically, re-sling the work:
   ```bash
   gt sling <bead-id> mayor
   ```

4. **Talk to the old session** (if you need to understand what happened):
   ```bash
   gt seance                              # List recent dead sessions
   gt seance --talk <session-id>           # Interactive conversation with predecessor
   gt seance --talk <id> -p "What were you working on?"
   ```

### An agent is stuck

```bash
gt feed -p             # Problems view highlights stuck agents
gt handoff mayor       # Force the Mayor to restart with a fresh context
gt release             # Release stuck in_progress issues back to pending
```

### Work was dispatched but nothing is happening

```bash
gt agents              # Are the expected agents running?
gt witness status      # Is the Witness managing polecats?
gt doctor              # Run health checks across the system
gt vitals              # Unified health dashboard
```

If polecats were spawned but have since exited, the Witness should respawn them. If the Witness itself is down, restart infrastructure:

```bash
gt up                  # Re-boots any missing services
```

### Dolt database issues

If `bd` commands hang, queries timeout, or you see "connection refused":

1. **Collect diagnostics first** (do not blindly restart):
   ```bash
   kill -QUIT $(cat .gt/.dolt-data/dolt.pid)   # Goroutine dump
   gt dolt status 2>&1 | tee /tmp/dolt-diag.log
   ```
2. Escalate: `gt escalate -s HIGH "Dolt: <describe symptom>"`
3. Only then consider `gt dolt stop && gt dolt start`.

### Orphan cleanup

```bash
gt dolt cleanup    # Safe removal of orphan test databases
gt down --all      # Full shutdown including orphan process cleanup
```
