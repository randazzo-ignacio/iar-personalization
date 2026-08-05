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

The personalization submodule at `personalization/` contains knowledge bases, project files, per-agent tasks, and audit logs. Users should fork or create their own personalization repo with their own knowledge, projects, tasks, and agent configurations.

### Build the Container

```bash
cd i.ar
./containers/build.sh
```

### Run (Interactive Mode)

```bash
# Basic usage (connects to remote Ollama via WireGuard):
./utils/iar.sh --personalization ~/repos/iar-personalization --project iar

# With self-modification enabled (for development/darwin):
./utils/iar.sh --personalization ~/repos/iar-personalization --project iar --self-modification

# With local Ollama and self-modification:
./utils/iar.sh --personalization ~/repos/iar-personalization --project iar --local --self-modification

# Mount additional directories into the container:
./utils/iar.sh --personalization ~/repos/iar-personalization --project iar \
  --mount /home/user/projects/myapp \
  --mount-ro /etc/ansible

# With a local gptel fork (for testing upstream fixes):
./utils/iar.sh --personalization ~/repos/iar-personalization --project iar --gptel-fork ~/repos/gptel

# With memory limit (default 8g):
./utils/iar.sh --personalization ~/repos/iar-personalization --project iar --memory 4g

# With a specific model and context window:
./utils/iar.sh --personalization ~/repos/iar-personalization --project iar --model granite4.1:8b-q8_0 --ctx 131072
```

### Run (Loop Mode -- Autonomous Agents)

```bash
# Run a single darwin cycle (needs --self-modification for code edits):
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --agent darwin --project darwin --self-modification

# Run a long darwin loop (50 cycles with cooldown):
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --agent darwin --project darwin --self-modification --max-cycles 50

# Run gardener (no self-modification needed):
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --agent gardener --project gardener --max-cycles 1

# Run librarian (documentation sync):
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --agent librarian --project librarian --max-cycles 1

# With specific knowledge bases:
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --agent darwin --project darwin --knowledge infra/ --knowledge iar/
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
| `--personalization PATH` | Yes | Mounts personalization repo at /root/personalization (contains docs/, knowledge/, projects/, tasks/, audit/) |
| `--project NAME` | Yes | Sets IAR_PROJECT env var. Determines which project file to load. Auto-creates project file if not found. |
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
| `--knowledge LABEL` | No | Documentation directory label to load (default: from project #+KNOWLEDGE). Can be specified multiple times. |
| `--cycle-prompt NAME` | No | Override cycle prompt file (e.g. matrix_turn). |
| `--status` | No | Show status dashboard (dispatches to iar-status.sh) |
| `--help, -h` | No | Show usage and exit |
| `--agent NAME` | Yes (loop) | Personality name (e.g., darwin, gardener, librarian) |
| `--max-cycles N` | No (loop) | Maximum number of cycles (default: 1) |
| `--cooldown SECONDS` | No (loop) | Seconds to wait between cycles (default: 60) |
| `--max-failures N` | No (loop) | Max consecutive failures before stopping (default: 5) |
| `--timeout SECONDS` | No (loop) | Per-cycle timeout (default: 7200 = 120 min) |

Environment variables:
- `EMACBOROS_OLLAMA_HOST` -- Default Ollama host:port
- `IAR_PROJECT` -- Current project name (set by --project flag)
- `EMACBOROS_SELF_MODIFICATION` -- Set to "1" by --self-modification flag
- `AGENT_TELEGRAM_BOT_TOKEN` -- Telegram bot token (loop mode notifications)
- `AGENT_TELEGRAM_CHAT_ID` -- Telegram chat ID (loop mode notifications)

## Inside Emacs

### Keybindings

| Key | Command | Description |
|-----|---------|-------------|
| C-c a | `iar-load-agent` | Select personality and assemble prompt (interactive archetype + default project) |
| C-c k | `iar-load-knowledge` | Load a documentation directory (iar/, user/, infra/, etc.) on top of assembled prompt |
| C-c p | `iar-load-personality-interactive` | Switch personality (re-assemble with current archetype + project) |
| C-c i | `iar-prompt-info` | Show prompt size (chars + approximate tokens) |
| C-c v | `iar-view-prompt` | View full system prompt (read-only) |
| C-c b | `iar-buffer-info` | Show conversation buffer size (chars + approx tokens) |
| C-x C-c | `iar-quit` | Session-aware quit |

All keybindings are defcustoms in `configs/keybindings.el` and can be changed without editing module code.

### Typical Workflow

1. Start the container with `iar.sh --personalization ... --project iar`
2. Emacs opens with gptel-mode active
3. Load a personality: `C-c a mirror` (or darwin, gardener, librarian, davinci, colin)
4. The assembly engine assembles the prompt from: interactive archetype + selected personality + iar project (which auto-loads iar/, infra/, user/ knowledge)
5. Check prompt size: `C-c i` (monitor context window usage)
6. Optionally load additional knowledge: `C-c k linux/` (concept knowledge bases)
7. Converse with the agent. It uses tools (read_file, execute_code_local, delegate, etc.) as needed.
8. When done: append session notes to LOGS.md via `append_file`.

### Talking to Mirror

The mirror agent is your thinking partner. The iar project auto-loads `docs/iar/` knowledge, so mirror already has the project documentation in its system prompt. Ask it about the codebase, design decisions, or to review a change you're planning. The mirror challenges your assumptions, pushes back on scope, and helps you think through problems.

### Running Autonomous Agents

Any personality with an autonomous or continuous archetype can run autonomously in cycles using `iar.sh --loop`:

```bash
# Run a single darwin cycle (needs --self-modification for code edits):
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --agent darwin --project darwin --self-modification

# Run a long darwin loop (50 cycles with cooldown):
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --agent darwin --project darwin --self-modification --max-cycles 50

# Run gardener (no self-modification needed):
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --agent gardener --project gardener --max-cycles 1

# Run librarian (documentation sync):
./utils/iar.sh --loop --personalization ~/repos/iar-personalization \
  --agent librarian --project librarian --max-cycles 1
```

Darwin reads its STATE.org (injected in system prompt), reads tasks via read_task, picks one thing to improve, makes the change, delegates to reviewer for code review, runs tests, commits, logs, and sleeps. One mutation per cycle.

The gardener runs as a continuous agent: pull latest code, run tests, diagnose failures, write tasks for darwin. It does not need self-modification mode (read-only to codebase).

The librarian runs as a continuous agent: pick one source file, compare against docs/iar/, fix drift, commit. It does not need self-modification mode (read-write to docs, read-only to code).

Telegram notifications require `AGENT_TELEGRAM_BOT_TOKEN` and `AGENT_TELEGRAM_CHAT_ID` environment variables.

## Setting Up Your Personalization Repo

The personalization repo is mounted at `/root/personalization/` inside the container. It contains:

```
my-personalization/
  docs/             -- Project documentation (injectable via C-c k)
    iar/            -- i.ar self-documentation
    infra/          -- Infrastructure documentation
    user/           -- Your identity, bio, domains, stack
  knowledge/        -- Concept knowledge bases (queryable via read_knowledge tool)
    linux/          -- Linux administration knowledge
  projects/         -- Project definition files (one .org per project)
    iar.org         -- Default project (all tools, multi-domain knowledge)
  tasks/<project>/  -- Per-project task files
  audit/<project>/<personality>/  -- Per-project/personality audit logs
    HISTORY.log     -- Operational log
    LOGS.md         -- Session notes (interactive mode)
    STATE.org       -- Checkpoint (autonomous/continuous mode)
  audit/audit.log   -- Global audit log
```

### Project Files

A project file (`projects/<name>.org`) defines what an agent works on:

```
#+KNOWLEDGE: iar/ infra/ user/
#+TOOLS: list_directory read_file write_file append_file execute_code_local check_elisp read_task create_task write_subtask remove_task read_history send_telegram git_commit delegate reload_os reload_agent read_knowledge read_roadmap write_roadmap
#+MOUNTS: /var/home/nacho/repos/iar-infrastructure:rw
#+OBJECTIVE: General-purpose i.ar development, infrastructure management, and security research.
```

- `#+KNOWLEDGE:` -- Space-separated list of doc subdirectory labels to auto-load
- `#+TOOLS:` -- Space-separated list of tool names to register (if absent, all tools)
- `#+MOUNTS:` -- Space-separated `path:mode` pairs (mode is `rw` or `ro`, default `rw`)
- `#+OBJECTIVE:` -- Free-text scope/goal injected into the prompt

### Setup Steps

1. Create the subdirectories: `docs/`, `knowledge/`, `projects/`, `tasks/`, `audit/`
2. Add knowledge bases you want agents to access in `docs/` and `knowledge/`
3. Create a project file in `projects/` (start by copying `iar.org` and customizing)
4. Create task/audit subdirectories for each project/personality you use
5. Point `--personalization` at your repo when running iar.sh

You can use the iar-personalization repo as a starting point and customize it.