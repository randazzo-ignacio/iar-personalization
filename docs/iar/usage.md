# i.ar Usage Guide

## Quickstart

### Prerequisites
- Podman (container runtime)
- Emacs 28+ (for local development without container)
- Ollama running on a reachable host (local or WireGuard mesh)
- A personalization repository (see below)

### Clone

```bash
# Just want to use the tool:
git clone https://github.com/randazzo-ignacio/i.ar.git

# Want to work on i.ar or understand the codebase (includes personalization submodule):
git clone --recursive https://github.com/randazzo-ignacio/i.ar.git
```

The personalization submodule at `personalization/` contains knowledge bases, per-agent tasks, and audit logs. Users should fork or create their own personalization repo with their own knowledge, tasks, and agent configurations.

### Build the Container

```bash
cd i.ar
./containers/build.sh
```

### Run (Interactive Mode)

```bash
# Basic usage (connects to remote Ollama via WireGuard):
./utils/iar.sh --personalization ~/repos/iar-personalization

# With self-modification enabled (for development/darwin):
./utils/iar.sh --personalization ~/repos/iar-personalization --self-modification

# With local Ollama and self-modification:
./utils/iar.sh --personalization ~/repos/iar-personalization --local --self-modification

# Mount additional directories into the container:
./utils/iar.sh --personalization ~/repos/iar-personalization \
  --mount /home/user/projects/myapp \
  --mount-ro /etc/ansible

# With a local gptel fork (for testing upstream fixes):
./utils/iar.sh --personalization ~/repos/iar-personalization --gptel-fork ~/repos/gptel

# With memory limit (default 8g):
./utils/iar.sh --personalization ~/repos/iar-personalization --memory 4g

# With a specific model and context window:
./utils/iar.sh --personalization ~/repos/iar-personalization --model granite4.1:8b-q8_0 --ctx 131072
```

### Run (Loop Mode -- Autonomous Agents)

```bash
# Run a single darwin cycle (needs --self-modification for code edits):
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --agent darwin --self-modification --gptel-fork ~/repos/gptel

# Run a long darwin loop (50 cycles with cooldown):
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --agent darwin --self-modification --gptel-fork ~/repos/gptel --max-cycles 50

# Run gardener (no self-modification needed):
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --agent gardener --gptel-fork ~/repos/gptel --max-cycles 10

# With specific knowledge bases:
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --agent playground --knowledge infra/ --knowledge iar/

# With a specific model and context window (for local models):
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --agent playground --model nemotron-3-super:120b --ctx 131072 \
  --ollama-host 10.66.0.5:11434 --max-cycles 999 --cooldown 300
```

### Status Dashboard

```bash
./utils/iar.sh --status
# or directly:
./utils/iar-status.sh
```

### Flags

| Flag | Required | Description |
|------|----------|-------------|
| `--personalization PATH` | Yes | Mounts docs/, knowledge/, tasks/, audit/ subdirectories into container |
| `--loop` | No | Run in autonomous loop mode (requires `--agent`) |
| `--self-modification` | No | Enables tier 2 file guard relaxation for .el file edits |
| `--ollama-host HOST:PORT` | No | Override Ollama backend (default: from env or WireGuard IP) |
| `--local` | No | Shortcut for `--ollama-host localhost:11434` with host networking |
| `--model NAME` | No | Ollama model name (default: glm-5.2:cloud) |
| `--ctx N` | No | Max context window in tokens (default: 1048576 = 1M) |
| `--mount PATH` | No | Mount additional writable directory into container |
| `--mount-ro PATH` | No | Mount additional read-only directory into container |
| `--gptel-fork PATH` | No | Mount a local gptel fork directory (writable) into the container |
| `--ssh-key-dir PATH` | No | Directory containing SSH keys (default: ~/.ssh) |
| `--ssh-key NAME` | No | SSH key name (default: emacboros_ed25519). Skipped if key doesn't exist. |
| `--memory LIMIT` | No | Podman memory limit (default: 8g). Caps container memory. |
| `--knowledge LABEL` | No | Knowledge directory label to load (default: iar/). Can be specified multiple times. |
| `--cycle-prompt NAME` | No | Override cycle prompt file (e.g. matrix_turn). |
| `--status` | No | Show status dashboard (dispatches to iar-status.sh) |
| `--help, -h` | No | Show usage and exit |
| `--agent NAME` | Yes (loop) | Agent profile name (required in --loop mode) |
| `--max-cycles N` | No (loop) | Maximum number of cycles (default: 1) |
| `--cooldown SECONDS` | No (loop) | Seconds to wait between cycles (default: 60) |
| `--max-failures N` | No (loop) | Max consecutive failures before stopping (default: 5) |
| `--timeout SECONDS` | No (loop) | Per-cycle timeout (default: 7200 = 120 min) |

Environment variables:
- `EMACBOROS_OLLAMA_HOST` -- Default Ollama host:port
- `AGENT_TELEGRAM_BOT_TOKEN` -- Telegram bot token (loop mode notifications)
- `AGENT_TELEGRAM_CHAT_ID` -- Telegram chat ID (loop mode notifications)

## Inside Emacs

### Keybindings

| Key | Command | Description |
|-----|---------|-------------|
| C-c a | `iar--load-agent` | Load agent personality (mirror, darwin, auditor, etc.) |
| C-c k | `iar-load-knowledge` | Load a documentation directory (iar/, user/, infra/, etc.) |
| C-c p | `iar-prompt-info` | Show prompt size (chars + approximate tokens) |
| C-c m | `iar-summarize-session` | Summarize conversation to LOGS.md/SUMMARY.md |
| C-x C-c | `iar-quit` | Session-aware quit (summarize before kill) |

All keybindings are defcustoms in `configs/keybindings.el` and can be changed without editing module code.

### Typical Workflow

1. Start the container with `iar.sh --personalization ...`
2. Emacs opens with gptel-mode active
3. Load an agent: `C-c a mirror` (or darwin, auditor, ctfwizard, gardener)
4. Load documentation: `C-c k iar/` (project docs), `C-c k user/` (your identity), `C-c k infra/` (infrastructure)
5. Check prompt size: `C-c p` (monitor context window usage)
6. Converse with the agent. It uses tools (read_file, execute_code_local, delegate, etc.) as needed.
7. When done: `C-c m` to summarize the session to memory.

### Talking to Mirror

The mirror agent is your thinking partner. Load `docs/iar/` into it and ask it about the codebase, design decisions, or to review a change you're planning. The mirror challenges your assumptions, pushes back on scope, and helps you think through problems.

### Running Autonomous Agents

Any orchestrator agent can run autonomously in cycles using `iar.sh --loop`:

```bash
# Run a single darwin cycle (needs --self-modification for code edits):
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --agent darwin --self-modification

# Run a long darwin loop (50 cycles with cooldown):
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --agent darwin --self-modification --max-cycles 50

# Run a different agent autonomously:
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --agent gardener --max-cycles 1

# With specific knowledge bases:
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --knowledge infra/ --knowledge iar/
```

Darwin reads its memories (injected in system prompt, truncated to 200 lines), reads tasks via read_task, picks one thing to improve, makes the change, delegates to reviewer for code review, runs tests, commits, logs, and sleeps. One mutation per cycle. Documentation (default: iar/) is loaded automatically into the system prompt.

The gardener runs as a continuous agent: pull latest code, run tests, diagnose failures, write tasks for darwin. It does not need self-modification mode (read-only to codebase).

Telegram notifications require `AGENT_TELEGRAM_BOT_TOKEN` and `AGENT_TELEGRAM_CHAT_ID` environment variables.

## Setting Up Your Personalization Repo

The personalization repo has three subdirectories:

```
my-personalization/
  docs/             -- Project documentation (injectable via C-c k)
  knowledge/         -- Concept knowledge bases (queryable via read_knowledge tool)
    user/            -- Your identity, bio, domains, stack
    iar/             -- i.ar self-documentation (from submodule or fork)
    infra/           -- Your infrastructure docs
    linux/           -- Linux administration knowledge
  tasks/<agent>/     -- Per-agent files: TODO.md, IDEAS.md, LOGS.md, SUMMARY.md
  audit/<agent>/     -- Per-agent HISTORY.log files
  audit/audit.log    -- Global audit log
```

1. Create the three subdirectories
2. Add knowledge bases you want agents to access
3. Create task/audit subdirectories for each agent you use
4. Point `--personalization` at your repo when running iar.sh

You can use the iar-personalization repo as a starting point and customize it.