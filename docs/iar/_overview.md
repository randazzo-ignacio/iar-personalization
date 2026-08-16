# i.ar Overview

## What i.ar Is

Self-modifying AI operating environment in Emacs, running in a hardened Podman container, powered by local LLMs via Ollama. No cloud, no telemetry. Repo at `/root/i.ar/`, Emacs config at `/root/i.ar/emacs.d/` (bind-mounted to `/root/.emacs.d/`).

## Three-Axis Assembly

Every agent is assembled from three independent primitives:

1. **Archetype** (`prompts/archetypes/<name>.org`) -- behavioral mode (interactive, autonomous, continuous, delegated, one-shot). Has `#+MODE:` metadata. Determines memory injection and completion semantics.
2. **Personality** (`prompts/personalities/<name>.org`) -- voice/character. Pure character, no tools or knowledge.
3. **Project** (`personalization/projects/<name>.org`) -- knowledge (`#+KNOWLEDGE`), tools (`#+TOOLS`), containers (`#+CONTAINERS`), mounts (`#+MOUNTS`), objective (`#+OBJECTIVE`).

Assembly engine (`iar-prompt-assembly.el`) combines: base_context.org -> archetype -> personality -> project objective -> auto-loaded knowledge -> memory injection -> mount info -> containers -> MCP servers.

## Archetypes

| Archetype | Mode | Memory | Completion |
|-----------|------|--------|------------|
| interactive | interactive | LOGS.md (last N lines) | Human ends session |
| autonomous | autonomous | STATE.org (full) | LOOP_COMPLETE / CYCLE_COMPLETE |
| continuous | continuous | STATE.org (full) | LOOP_COMPLETE (every tick) |
| agent-assistant | delegated | None | Response is completion |
| implementer | delegated | None | Response is completion |
| reviewer | delegated | None | Response is completion |
| one-shot | one-shot | None | Final response between delimiters |

## Personalities

mirror (interactive thinking partner), darwin (autonomous code evolution), gardener (continuous monitoring), librarian (continuous doc sync), davinci/colin (interactive, specialized), pentest (security research), agent-assistant/implementer/reviewer (delegation pipeline).

## Tools

Filesystem: read_file, write_file, append_file, list_directory.
Code: execute_code_local (bash in container), execute_code_remote (sidecar containers), check_elisp.
Tasks: read_task, create_task, write_subtask, remove_task, read_history, read_roadmap, write_roadmap.
Knowledge: read_knowledge. Notify: send_telegram. Git: git_commit. Agent: delegate, reload_os, reload_agent.

Tool gating: per-project via `#+TOOLS`. Container gating: `#+CONTAINERS` auto-includes execute_code_remote.

## Key Modules

- `init.d/agent/iar-prompt-assembly.el` -- assembly engine
- `init.d/agent/iar-agent-loader.el` -- personality-to-archetype map, agent loading
- `init.d/agent/iar-knowledge-loader.el` -- knowledge base loading
- `init.d/agent/iar-project-parser.el` -- project file parsing
- `init.d/tool-call/iar-tool-call.el` -- tool call abstraction layer
- `init.d/security/` -- file guard, audit log, loop guard, output sanitizer, tool guard
- `configs/` -- individual config files (paths, keybindings, gptel, file-guard, memory, etc.)
- `shared/iar-utils.el`, `shared/iar-agent-utils.el` -- consolidated utilities

## Memory System

- **LOGS.md** (interactive) -- session notes, last N lines injected (config: `iar-personal-file-max-lines`, default 200)
- **STATE.org** (autonomous/continuous) -- full checkpoint injected
- **HISTORY.log** -- operational log, read via read_history tool
- Files in `audit/<project>/<personality>/`

## Security Model

1. Container (read-only rootfs, dropped capabilities, preflight audit)
2. File guard (tier 1: prompt files, logs -- always protected; tier 2: .el files, Containerfile -- relaxed with --self-modification)
3. Per-project tool gating (`#+TOOLS`)
4. Multi-container physical separation (sidecars: pentest has internet but no personal data; concepts/life-org have no network)
5. Loop guard (soft/hard thresholds for repetitive tool calls)
6. Audit logging (all file ops and command executions logged)

## Autonomous Agents

- **Darwin**: reads STATE.org -> reads tasks -> makes one change -> delegates to reviewer -> tests -> commits -> logs -> updates state. One task per cycle.
- **Gardener**: pulls latest -> compares HEAD to last checked -> runs tests -> writes tasks for darwin.
- **Librarian**: pulls latest -> picks source file -> compares to docs -> fixes drift -> commits.

Run via `iar.sh --loop --agent <name> --project <name>`. Fresh container per tick.

## Delegation Pipeline

delegate tool -> agent-assistant (plans, delegates to implementer/reviewer, coordinates correction loop) -> returns final result. Depth-limited (default 3), turn-limited (default 15), timeout 600s.

## Documentation Structure

Full docs in `docs/iar/`: agents.md, architecture.md, modules.md, philosophy.md, tools.md, tool_gating.md, usage.md, workflow.md, future_ideas.md. Use read_file to access detailed reference docs when needed.

## Maintenance Rule

When code changes, update the corresponding docs/iar/ file. The knowledge base IS the documentation. See workflow.md for the update mapping table.