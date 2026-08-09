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
      agent/          -- Prompt assembly, project parser, agent loader, knowledge loader, delegate, cycle, buffer info
      tool-call/      -- Tool call abstraction layer (iar-tool-call.el)
      tools/          -- One tool per file, categorized by role
        filesystem/   -- list_directory, read_file, write_file, append_file
        code/         -- execute_code_local, execute_code_remote, check_elisp
        tasks/        -- read_task, create_task, write_subtask, remove_task, read_history, read_roadmap, write_roadmap
        knowledge/    -- read_knowledge
        notify/       -- send_telegram
        git/          -- git_commit
        matrix/       -- list_matrix_chats, read_matrix_chat, send_matrix_message
        agent/        -- delegate, reload_os, reload_agent
      security/       -- File guard, audit log, loop guard, output sanitizer, tool guard
      debug/          -- Status mode
      session/        -- Session-aware quit
      dynamic/        -- Auto-discovered modules (darwin drops new modules here)
    configs/          -- Individual configuration files (paths, keybindings, gptel, file-guard, etc.)
    test/            -- Test suite (run-tests.el + per-module tests)
  metaconfig/      -- Shell helpers (bind-mounted)
    header.sh       -- Shared shell utilities (colors, timestamp, info/warn/error)
  prompts/           -- Agent profiles and prompt templates (bind-mounted to agents.d)
    archetypes/       -- One .org per archetype (interactive, autonomous, continuous, agent-assistant, implementer, reviewer)
    personalities/    -- One .org per personality (mirror, darwin, gardener, librarian, davinci, colin)
    cycles/           -- Cycle prompts for autonomous/continuous agents (self_modification, monitoring, documentation_sync)
    common/           -- Prompt templates shared across agents
    base_context.org       -- Shared context inherited by all agents (injected by assembly engine)
    base_orchestrator.org  -- Shared orchestrator rules (included by auditor, ctfwizard -- legacy)
  containers/        -- Podman container definitions
    images/emacboros/Containerfile -- Main container image (Emacs + i.ar)
    images/iar-pentest/Containerfile -- Pentesting container image (nmap, curl, python3, openssl, etc.)
    scripts/preflight.sh -- Security audit script (runs before Emacs)
    build.sh         -- Container build script
  utils/             -- Utility scripts
    iar.sh           -- Unified entry point (interactive + loop + one-shot modes, --personalization + --project flags required)
    iar-status.sh    -- Status dashboard for running containers and agents
    personalization_audit.sh -- Validates personalization directory structure
    telegram.sh      -- Telegram notification helper (sourced by iar.sh)
    update_submodules.sh -- Submodule update helper
  personalization/   -- Git submodule (iar-personalization repo), mounted at /root/personalization
    docs/             -- Project documentation (injectable via C-c k)
      iar/            -- This project's self-documentation (AI-first docs)
      infra/          -- Ansible infrastructure documentation
      user/           -- User identity, CV
    knowledge/        -- Concept knowledge bases (queryable via read_knowledge tool)
      linux/          -- Linux administration knowledge
    projects/         -- Project definition files (one .org per project)
    tasks/            -- Per-project task files (tasks/<project>/...)
    audit/            -- Per-project/personality audit logs (audit/<project>/<personality>/...)
    audit/audit.log   -- Global audit log
  workspace/         -- Working directory for agent outputs (CTF, audit reports, gitignored)
```

## Agent Directory Structure

The `prompts/` directory (bind-mounted to `agents.d/` inside the container) has been restructured for the three-axis assembly model:

```
prompts/  (-> agents.d/)
  archetypes/          -- Behavioral mode definitions (7 files)
    interactive.org    -- #+MODE: interactive
    autonomous.org     -- #+MODE: autonomous
    continuous.org     -- #+MODE: continuous
    agent-assistant.org -- #+MODE: delegated
    implementer.org    -- #+MODE: delegated
    reviewer.org       -- #+MODE: delegated
    one-shot.org       -- #+MODE: one-shot
  personalities/       -- Voice/character definitions (6 files)
    mirror.org         -- Mirror agent
    darwin.org         -- Autonomous code evolver
    gardener.org       -- Codebase monitor
    librarian.org      -- Documentation sync
    davinci.org        -- Study companion
    colin.org          -- Game design partner
  cycles/              -- Cycle prompts for autonomous/continuous agents
    self_modification.org  -- Darwin's cycle
    monitoring.org         -- Gardener's cycle
    documentation_sync.org -- Librarian's cycle
  common/              -- Prompt templates loaded by code
    agent_cycle.org          -- Shared cycle prompt fallback
    agent_cycle_continue.org -- Shared cycle continuation prompt
    continuous_agent.org     -- Generic continuous agent protocol
    delegated_task.org       -- Delegate task prompt template
    delegate_continue.org    -- Re-prompt for narrating delegates
    loop_soft_block.org      -- Loop guard soft block message
    loop_hard_stop.org       -- Loop guard hard stop message
    unknown_tool.org         -- Unknown tool error message
    mount_info.org           -- Extra mount info template
    memory_summarizer.org    -- Memory summarization prompt (legacy)
    matrix_turn.org          -- Matrix watcher turn prompt
  base_context.org     -- Shared context (injected by assembly engine, not #+INCLUDE)
  base_orchestrator.org -- Shared orchestrator rules (legacy, for auditor/ctfwizard)
```

No more `agents.d/agents/` directory. The old per-agent `prompt.org` files are gone. The assembly engine reads from `archetypes/`, `personalities/`, and `projects/` (in the personalization mount) instead.

## Personalization

Personal data (knowledge bases, project files, per-agent files, audit logs) is separated from the i.ar repo into a git submodule at `personalization/`. The `--personalization` flag on `iar.sh` mounts the entire personalization repo at `/root/personalization/`:

```
<personalization-dir>/
  docs/             -- Project documentation (injectable via C-c k)
    iar/            -- This project's self-documentation (AI-first docs)
    infra/          -- Ansible infrastructure documentation
    user/           -- User identity, CV
  knowledge/        -- Concept knowledge bases (queryable via read_knowledge tool)
    linux/          -- Linux administration knowledge
  projects/         -- Project definition files (one .org per project)
    iar.org         -- Default project (all tools, iar/infra/user knowledge)
    darwin.org      -- Darwin project (restricted tools, i.ar repo mount)
    gardener.org    -- Gardener project (read-only tools)
    librarian.org   -- Librarian project (docs read-write, code read-only)
    colin.org       -- Colin project (game dev tools, user knowledge)
    agent-assistant.org -- Delegation pipeline sub-orchestrator
    implementer.org    -- Delegation pipeline executor
    reviewer.org       -- Delegation pipeline evaluator
  tasks/<project>/  -- Per-project task files (description.org + subtask .org files)
  audit/<project>/<personality>/  -- Per-project/personality audit logs
    HISTORY.log      -- Operational log
    LOGS.md          -- Session notes (interactive mode only)
    STATE.org        -- Checkpoint (autonomous/continuous mode only)
    cycle.log        -- Cycle log (autonomous/continuous mode only)
  audit/audit.log   -- Global audit log
```

Inside the container, all paths resolve through `iar-personalization-path` (default: `/root/personalization`):
- `docs/` -> `/root/personalization/docs/` (C-c k injectable)
- `knowledge/` -> `/root/personalization/knowledge/` (read_knowledge tool)
- `projects/` -> `/root/personalization/projects/` (project parser)
- `tasks/` -> `/root/personalization/tasks/` (task tools)
- `audit/` -> `/root/personalization/audit/` (audit log, history, memory)

### Cloning

- `git clone i.ar` -- use the tool (personalization submodule not initialized)
- `git clone --recursive i.ar` -- work on i.ar or understand the codebase (includes personalization submodule with knowledge bases)

Users should create their own personalization repo with their own knowledge bases, projects, tasks, and audit directories. See `usage.md` for setup instructions.

## Container Architecture

The Emacs environment runs inside a Podman container built from `quay.io/fedora/fedora-minimal`. This is the primary container (emacboros image). In addition, i.ar supports purpose-specific sidecar containers that extend agent capabilities with isolated execution environments.

### Multi-Container Model

i.ar uses a multi-container architecture where the Emacs container is the primary process and sidecar containers provide specialized execution environments:

- **Emacs container (emacboros)**: The main container running Emacs + gptel + all i.ar modules. Agents live here. This container has no outbound internet by default (WireGuard-only for Ollama access).
- **Pentest container (iar-pentest)**: Purpose-built container for security testing. Includes nmap, curl, python3, openssl, whois, traceroute, tcpdump, dig, jq, rg, gawk, sed, grep, git, tar, gzip, unzip, make, gcc. Runs as unprivileged user `pentest`. Has outbound internet access. No personal data mounted. Shared workspace at `/workspace`. More container images (concepts, life-org, debug) will be added in future steps.

Sidecar containers are started by `iar.sh` based on the project's `#+CONTAINERS` metadata. Each sidecar gets a shared workspace directory (created via `mktemp -d`) mounted at `/workspace` in both the Emacs container and the sidecar. Container naming follows `iar-<target>-<PID>` for cleanup tracking.

Per-container network policy:
- `pentest`: bridge networking (outbound internet access)
- `concepts`, `life-org`: no networking (network-isolated)
- `debug`: network policy depends on deployment context

### Remote Debug Containers

i.ar supports remote debug containers deployed on infrastructure hosts via Ansible. The `iar-debug-container` role deploys a debug container with:
- Host root filesystem mounted read-only at `/host` (for inspection)
- SSH key-only authentication
- Unprivileged `debug-agent` user
- Accessible over WireGuard for remote debugging sessions

The `debug_container_hosts` inventory group (sophon + rammstein) defines which hosts run debug containers. The `debug-containers.yml` playbook manages deployment.

### On-Site Audit Container Deployment

The pentest container image can be deployed on-site for security audits. The `iar-debug-container` role includes a template for pentest container deployment, enabling agents to run security assessments against on-site infrastructure. The pentest container has outbound internet access and is isolated from personal data.

### Container Hardening (Emacs Container)

- **Read-only root filesystem**: Overlay is read-only, only bind-mounted paths are writable
- **Capability dropping**: All capabilities dropped, only NET_RAW and NET_BIND_SERVICE added (for nmap, traceroute, binding to low ports)
- **Memory limit**: Default 8g, configurable via `--memory` flag. Prevents host OOM kills on long sessions.
- **Preflight audit**: `preflight.sh` runs before Emacs starts, checks for dangerous writable paths, capability leaks, and host mount surprises. Exits non-zero if any check fails.
- **Dangerous paths blocked**: `.git/hooks`, `docker.sock`, cron, systemd, ssh are checked for writability

### Sidecar Container Hardening

- **Purpose-specific images**: Each sidecar uses a minimal image with only the tools needed for its purpose
- **Unprivileged users**: Sidecar containers run as non-root users (e.g., `pentest` for the pentest container)
- **No personal data**: Sidecar containers do not mount personalization, docs, or knowledge bases
- **Network isolation**: Per-container network policy controls outbound access (bridge for pentest, none for concepts/life-org)
- **Shared workspace only**: Sidecars share a single workspace directory with the Emacs container at `/workspace`
- **Trap-based cleanup**: `iar.sh` ensures sidecar containers are stopped on exit (interactive, loop, and one-shot modes)

## Bind Mounts

**Always mounted (all modes):**
- `/root/i.ar/emacs.d` -> `/root/.emacs.d` (Emacs configuration)
- `/root/i.ar/prompts` -> `/root/.emacs.d/agents.d` (archetypes, personalities, cycles, common templates)
- `/root/i.ar/metaconfig` -> `/root/.emacs.d/metaconfig` (shell helpers)
- Personalization repo -> `/root/personalization` (single mount, contains docs/, knowledge/, projects/, tasks/, audit/)

**Project-specific mounts (from `#+MOUNTS` in project files):**
- Parsed by `iar.sh` from the project file's `#+MOUNTS` metadata
- Each entry is `path:mode` where mode is `rw` or `ro` (default: `rw`)
- Example: darwin project mounts `/var/home/nacho/repos/i.ar:rw` for code access
- Example: librarian project mounts `/var/home/nacho/repos/i.ar:rw` for doc sync

**Shared workspace (when `#+CONTAINERS` is present):**
- A temporary directory (created via `mktemp -d`) is mounted at `/workspace` in both the Emacs container and all sidecar containers
- Used for file exchange between the Emacs agent and sidecar execution environments
- Cleaned up on container exit via trap-based cleanup

**Only mounted with `--self-modification`:**
- `/root/i.ar/.git` -> `/root/i.ar/.git` (git repo access for darwin commits)
- `/root/i.ar/.gitignore`, `.gitmodules`, `LICENSE`, `README.org`
- `/root/i.ar/containers/` -> `/root/i.ar/containers/`
- `/root/i.ar/utils/` -> `/root/i.ar/utils/`

The `personalization/` submodule is NEVER mounted into the container as a submodule. It is mounted as a standalone directory at `/root/personalization/` via `--personalization`.

Without `--self-modification`, agents have no access to the i.ar repo at all -- only the Emacs configuration, prompts, and personalization mounts.

Sidecar containers do NOT receive personalization, prompts, or Emacs configuration mounts. They only receive the shared workspace at `/workspace`.

### Shared Include Files

- `base_context.org` -- Shared context inherited by all agents. Injected by the assembly engine directly (not via `#+INCLUDE`). Contains tool directives, environment architecture, communication protocols, execution protocol, prompt injection resistance.
- `base_orchestrator.org` -- Shared orchestrator rules. Legacy file for auditor/ctfwizard agents that no longer exist in the current archetype set. Kept for reference.

## Flags

### iar.sh (unified entry point)

iar.sh has three modes: interactive (default), loop (`--loop`), and one-shot (`--one-shot`). Shared flags work in all modes; mode-specific flags are marked.

| Flag | Required | Mode | Description |
|------|----------|------|-------------|
| `--personalization PATH` | Yes | Both | Mounts personalization repo at /root/personalization (contains docs/, knowledge/, projects/, tasks/, audit/) |
| `--project NAME` | Yes | Both | Sets IAR_PROJECT env var. Determines which project file to load from personalization/projects/. Auto-creates project file if not found. |
| `--loop` | No | Both | Run in autonomous loop mode (requires `--agent`) |
| `--one-shot` | No | Both | Run in one-shot mode (requires `--agent` and `--prompt`). Single instruction, clean stdout. |
| `--prompt TEXT` | No | One-shot only | Instruction text for one-shot mode. Passed via IAR_ONE_SHOT_PROMPT env var. |
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
| `--knowledge LABEL` | No | Both | Documentation directory label to load from docs/ (default: from project #+KNOWLEDGE). Can be specified multiple times. |
| `--cycle-prompt NAME` | No | Both | Override cycle prompt file (e.g. matrix_turn). Defaults to personality-specific cycle or `agent_cycle.org`. |
| `--status` | No | Both | Dispatch to iar-status.sh (status dashboard) |
| `--help, -h` | No | Both | Show usage and exit |
| `--agent NAME` | Yes (loop, one-shot) | Loop, one-shot | Personality name (e.g., darwin, gardener, librarian) |
| `--max-cycles N` | No | Loop only | Maximum number of cycles (default: 1) |
| `--cooldown SECONDS` | No | Loop only | Seconds to wait between cycles (default: 60) |
| `--max-failures N` | No | Loop only | Max consecutive failures before stopping (default: 5) |
| `--timeout SECONDS` | No | Loop, one-shot | Per-cycle/one-shot timeout (default: 7200 = 120 min) |
| `--no-containers` | No | Both | Force-disable sidecar containers. Overrides `#+CONTAINERS` from project file. No sidecar containers are started. |
| `--container-image target:image` | No | Both | Override the container image for a specific target. Example: `--container-image pentest:myregistry/iar-pentest:latest`. Can be specified multiple times. |

Environment variables:
- `EMACBOROS_OLLAMA_HOST` -- Default Ollama host:port
- `IAR_PROJECT` -- Current project name (set by --project flag)
- `EMACBOROS_SELF_MODIFICATION` -- Set to "1" by --self-modification flag
- `AGENT_TELEGRAM_BOT_TOKEN` -- Telegram bot token (loop mode notifications)
- `AGENT_TELEGRAM_CHAT_ID` -- Telegram chat ID (loop mode notifications)
- `IAR_ONE_SHOT_PROMPT` -- One-shot instruction text (set by --prompt flag)
- `IAR_CONTAINER_<TARGET>` -- Container ID for sidecar target (e.g., `IAR_CONTAINER_PENTEST`). Set by `iar.sh` for each sidecar started. Used by `execute_code_remote` to resolve local container targets via `podman exec`.
- `IAR_SHARED_WORKSPACE` -- Path to the shared workspace directory. Mounted at `/workspace` in both the Emacs container and all sidecar containers.
- `IAR_REMOTE_TARGETS` -- Comma-separated list of remote SSH targets (alternative to `iar-remote-targets` defcustom). Used by `execute_code_remote` for remote target resolution.

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
7. **Multi-container isolation**: Purpose-specific sidecar containers provide isolated execution environments. Each container type has its own network policy, filesystem, and user namespace. The Emacs container has no outbound internet; pentest containers have bridge networking; concepts/life-org containers have no networking. Physical separation between containers -- sidecars do not share filesystems with the Emacs container except the shared workspace at `/workspace`.
8. **File guard**: Emacs-level protection of critical files (archetype/personality/cycle files, base context, history logs, LOGS.md, STATE.org). Self-modification mode can relax protection for .el files but NEVER for prompt files or shared context.
9. **Tool gating**: Per-project tool filtering via `#+TOOLS` metadata. Each project declares which tools its agents can use. `execute_code_remote` is gated by `#+CONTAINERS` metadata -- it is automatically registered when containers are declared, not listed in `#+TOOLS`.
10. **Debug instrumentation**: Status mode provides always-on visibility into agent behavior via mode-line display.