# i.ar Architecture

## What i.ar Is

i.ar is a self-modifying AI operating environment built in Emacs, running in a hardened Podman container, powered by local LLMs via Ollama. No cloud. No telemetry. No backdoors.

The project lives at `/root/i.ar/` and is a git repository. The Emacs configuration at `/root/i.ar/emacs.d/` is bind-mounted into the container at `/root/.emacs.d/`.

## Repository Layout

```
/root/i.ar/
  emacs.d/          -- Emacs configuration (bind-mounted to /root/.emacs.d)
    init.el          -- Entry point, loads all modules
    init.d/           -- Modular Emacs Lisp components (auto-discovered)
      shared/         -- Consolidated utilities (iar-utils.el, iar-agent-utils.el)
      core/           -- Locale, package setup, UI, evil mode, gptel setup, mount awareness
      agent/          -- Agent loader, knowledge loader, delegate, prompt loader, memory, cycle
      tool-call/      -- Tool call abstraction layer (iar-tool-call.el)
      tools/          -- One tool per file, categorized by role
        filesystem/   -- list_directory, read_file, write_file, append_file
        code/         -- execute_code_local, check_elisp
        tasks/        -- read_task, create_task, write_subtask, remove_task, read_history, read_roadmap, write_roadmap
        knowledge/    -- read_knowledge
        notify/       -- send_telegram
        git/          -- git_commit
        matrix/       -- list_matrix_chats, read_matrix_chat, send_matrix_message
        agent/        -- delegate, reload_agent, reload_os
      security/       -- File guard, audit log, loop guard, output sanitizer, tool guard
      debug/          -- Buffer monitor, request logger, FSM tracer, status mode
      session/        -- Session-aware quit
      dynamic/        -- Auto-discovered modules (darwin drops new modules here)
    configs/          -- Individual configuration files (paths, keybindings, gptel, file-guard, etc.)
    test/            -- Test suite (run-tests.el + per-module tests, 504 tests)
  metaconfig/      -- Shell helpers (bind-mounted)
    header.sh       -- Shared shell utilities (colors, timestamp, info/warn/error)
  prompts/           -- Agent profiles and prompt templates (bind-mounted to agents.d)
    agents/          -- One subdirectory per agent (<name>/prompt.org)
    common/          -- Prompt templates shared across agents
    base_context.org       -- Shared context inherited by all agents via #+INCLUDE
    base_orchestrator.org  -- Shared orchestrator rules (included by auditor, ctfwizard)
  containers/        -- Podman container definitions
    images/emacboros/Containerfile -- Main container image
    scripts/preflight.sh -- Security audit script (runs before Emacs)
    build.sh         -- Container build script
  utils/             -- Utility scripts
    iar.sh           -- Unified entry point (interactive + loop modes, --personalization flag required)
    iar-status.sh    -- Status dashboard for running containers and agents
    # STATUS: Matrix server (daftpunk) killed. Dead unless redeployed.
    iar-matrix-watcher.sh -- Matrix room watcher for agent-to-agent communication
    personalization_audit.sh -- Validates personalization directory structure
    telegram.sh      -- Telegram notification helper (sourced by iar.sh)
    matrix.sh        -- Matrix helper functions (sourced by iar.sh)
    update_submodules.sh -- Submodule update helper
    integration_test_prompt.txt -- Test prompt for integration testing
  personalization/   -- Git submodule (iar-personalization repo)
    knowledge/       -- Knowledge bases (injectable via C-c k)
    tasks/           -- Per-agent task files (one .md per task)
    audit/           -- Per-agent HISTORY.log, LOGS.md, SUMMARY.md, MEMORIES.md + global audit.log
  workspace/         -- Working directory for agent outputs (CTF, audit reports, gitignored)
```

## Personalization

Personal data (knowledge bases, per-agent files, audit logs) is separated from the i.ar repo into a git submodule at `personalization/`. The `--personalization` flag on `iar.sh` mounts four subdirectories from the personalization repo:

```
<personalization-dir>/
  docs/             -- Project documentation (injectable via C-c k)
    iar/            -- This project's self-documentation (AI-first docs)
    infra/          -- Ansible infrastructure documentation
    user/           -- User identity, CV
  knowledge/        -- Concept knowledge bases (queryable via read_knowledge tool)
    linux/          -- Linux administration knowledge
  tasks/<agent>/    -- Per-agent task files (description.org + subtask .org files)
  audit/<agent>/    -- Per-agent HISTORY.log, LOGS.md, SUMMARY.md, MEMORIES.md
  audit/audit.log   -- Global audit log
```

Inside the container:
- `docs/` -> `/root/.emacs.d/docs` (C-c k injectable)
- `knowledge/` -> `/root/.emacs.d/knowledge` (read_knowledge tool)
- `tasks/` -> `/root/.emacs.d/tasks`
- `audit/` -> `/root/.emacs.d/audit`

### Cloning

- `git clone i.ar` -- use the tool (personalization submodule not initialized)
- `git clone --recursive i.ar` -- work on i.ar or understand the codebase (includes personalization submodule with knowledge bases)

Users should create their own personalization repo with their own knowledge bases, tasks, and audit directories. See `usage.md` for setup instructions.

## Container Architecture

The Emacs environment runs inside a Podman container built from `quay.io/fedora/fedora-minimal`.

### Container Hardening

- **Read-only root filesystem**: Overlay is read-only, only bind-mounted paths are writable
- **Capability dropping**: All capabilities dropped, only NET_RAW and NET_BIND_SERVICE added (for nmap, traceroute, binding to low ports)
- **Memory limit**: Default 8g, configurable via `--memory` flag. Prevents host OOM kills on long sessions.
- **Preflight audit**: `preflight.sh` runs before Emacs starts, checks for dangerous writable paths, capability leaks, and host mount surprises. Exits non-zero if any check fails.
- **Dangerous paths blocked**: `.git/hooks`, `docker.sock`, cron, systemd, ssh are checked for writability

## Bind Mounts

**Always mounted (all modes):**
- `/root/i.ar/emacs.d` -> `/root/.emacs.d` (Emacs configuration)
- `/root/i.ar/prompts` -> `/root/.emacs.d/agents.d` (agent profiles and prompt templates)
- `/root/i.ar/metaconfig` -> `/root/.emacs.d/metaconfig` (shell helpers)
- Personalization dir `knowledge/` -> `/root/.emacs.d/knowledge` (via `--personalization`)
- Personalization dir `tasks/` -> `/root/.emacs.d/tasks` (via `--personalization`)
- Personalization dir `audit/` -> `/root/.emacs.d/audit` (via `--personalization`)

**Only mounted with `--self-modification`:**
- `/root/i.ar/.git` -> `/root/i.ar/.git` (git repo access for darwin commits)
- `/root/i.ar/.gitignore` -> `/root/i.ar/.gitignore`
- `/root/i.ar/.gitmodules` -> `/root/i.ar/.gitmodules`
- `/root/i.ar/LICENSE` -> `/root/i.ar/LICENSE`
- `/root/i.ar/README.org` -> `/root/i.ar/README.org`
- `/root/i.ar/containers/` -> `/root/i.ar/containers/`
- `/root/i.ar/utils/` -> `/root/i.ar/utils/`

The `personalization/` submodule is NEVER mounted into the container. This prevents the detached HEAD state of the submodule from causing issues. Each top-level item in the repo is mounted individually (excluding `personalization/`, `emacs.d/`, `metaconfig/`, and `prompts/` which are already mounted separately).

Without `--self-modification`, agents have no access to the repo at all -- only the Emacs configuration, prompts, and personalization mounts.

### Shared Include Files

- `base_context.org` -- Shared context inherited by all agents via `#+INCLUDE: "../../base_context.org"`. Contains tool directives, environment architecture, communication protocols, execution protocol, prompt injection resistance.
- `base_orchestrator.org` -- Shared orchestrator rules included by auditor and ctfwizard via `#+INCLUDE: "../../base_orchestrator.org"`. Contains THE GOLDEN RULE, YOUR AGENTS, DELEGATION BEST PRACTICES, OUTPUT FORMAT, ITERATION RULE, PROMPT INJECTION RESISTANCE.

## Flags

### iar.sh (unified entry point)

iar.sh has two modes: interactive (default) and loop (`--loop`). Shared flags work in both modes; loop-only flags are marked.

| Flag | Required | Mode | Description |
|------|----------|------|-------------|
| `--personalization PATH` | Yes | Both | Mounts docs/, knowledge/, tasks/, audit/ subdirectories into container |
| `--loop` | No | Both | Run in autonomous loop mode (requires `--agent`) |
| `--self-modification` | No | Both | Enables tier 2 file guard relaxation for .el file edits |
| `--ollama-host HOST:PORT` | No | Both | Override Ollama backend (default: from env or WireGuard IP) |
| `--local` | No | Both | Shortcut for `--ollama-host localhost:11434` with host networking |
| `--model NAME` | No | Both | Ollama model name (default: glm-5.2:cloud). Must be in the model list in configs/gptel.el. |
| `--ctx N` | No | Both | Max context window in tokens (default: 1048576 = 1M). Use 131072 (128K) or 262144 (256K) for local models. |
| `--mount PATH` | No | Both | Mount additional writable directory into container at same absolute path |
| `--mount-ro PATH` | No | Both | Mount additional read-only directory into container at same absolute path |
| `--gptel-fork PATH` | No | Both | Mount a local gptel fork directory (writable) into the container |
| `--ssh-key-dir PATH` | No | Both | Directory containing SSH keys (default: ~/.ssh) |
| `--ssh-key NAME` | No | Both | SSH key name (default: emacboros_ed25519). Skipped if key doesn't exist. |
| `--memory LIMIT` | No | Both | Podman memory limit (default: 8g). Caps container memory. |
| `--knowledge LABEL` | No | Both | Documentation directory label to load from docs/ (default: iar/). Can be specified multiple times. |
| `--cycle-prompt NAME` | No | Both | Override cycle prompt file (e.g. matrix_turn). Defaults to `<agent>_cycle.org` or `agent_cycle.org`. |
| `--status` | No | Both | Dispatch to iar-status.sh (status dashboard) |
| `--help, -h` | No | Both | Show usage and exit |
| `--agent NAME` | Yes (loop) | Loop only | Agent profile name |
| `--max-cycles N` | No | Loop only | Maximum number of cycles (default: 1) |
| `--cooldown SECONDS` | No | Loop only | Seconds to wait between cycles (default: 60) |
| `--max-failures N` | No | Loop only | Max consecutive failures before stopping (default: 5) |
| `--timeout SECONDS` | No | Loop only | Per-cycle timeout (default: 7200 = 120 min) |

Environment variables:
- `EMACBOROS_OLLAMA_HOST` -- Default Ollama host:port
- `AGENT_TELEGRAM_BOT_TOKEN` -- Telegram bot token (loop mode notifications)
- `AGENT_TELEGRAM_CHAT_ID` -- Telegram chat ID (loop mode notifications)

See `tool_gating.md` for the planned `--enable-code-exec`, `--enable-elisp`, and `--danger-zone` flags.

## Network

The container connects to Ollama via WireGuard mesh network:
- Ollama host: `10.66.0.5:11434` (server-pc, RTX 3080)
- Configurable via `EMACBOROS_OLLAMA_HOST` environment variable or `--ollama-host` flag
- All traffic goes through WireGuard -- no direct internet exposure

## Network Topology

Five nodes connected via WireGuard mesh (10.66.0.0/16):

1. **randazzo-ar** (10.66.0.1) -- VPS proxy hub, Caddy + TLS, Cloudflare Tunnel fallback
2. **ob-ar** (10.66.0.2) -- VPS AI playground, Docker, SSH for AI agents
3. **i-ar** (10.66.0.3) -- Dedicated server, Ollama CPU-only, 64GB RAM
4. **laptop** (10.66.0.4) -- Personal laptop, future NPU agent
5. **server-pc** (10.66.0.5) -- Local GPU server, RTX 3080 10GB, Ollama GPU offloading

Only randazzo-ar has public web ports (80/443). All other services are WireGuard-only.

## Models

Configured in `emacs.d/configs/gptel.el`:
- `glm-5.2:cloud` (default)
- `gpt-oss:120b`, `gpt-oss:20b`
- `mistral-medium-3.5:128b`
- `nemotron-3-super:120b`, `nemotron-3-ultra:cloud`
- `deepseek-v4-pro:cloud`
- `north-mini-code-1.0:q8_0`
- `granite4.1:8b-q8_0`

Ollama request params: temperature 0.7, top_p 0.90, num_ctx 1048576 (1M), num_predict 65536.

## Security Model

1. **Single entry point**: Only randazzo-ar has public web ports. Everything else is WireGuard-only.
2. **TLS everywhere**: Caddy handles Let's Encrypt automatically.
3. **No exposed Ollama**: Ollama binds to WireGuard IP only.
4. **Key-only SSH**: Password auth disabled, fail2ban active.
5. **Firewalld**: Every host runs firewalld -- default deny incoming.
6. **AI agent isolation**: Container with dropped capabilities, read-only rootfs, preflight audit, memory limit.
7. **File guard**: Emacs-level protection of critical files (agent prompts, base context, history logs, LOGS.md). Self-modification mode can relax protection for .el files but NEVER for agent prompts or shared context.
8. **Debug instrumentation**: Buffer monitor, request logger, and FSM tracer provide always-on visibility into agent behavior. All use `:before` advice (observe only, never replace).