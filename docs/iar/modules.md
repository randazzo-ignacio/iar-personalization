# i.ar Emacs Modules

All Emacs Lisp modules live in `init.d/` and are organized into subdirectories by purpose. The auto-discovery scans `init.d/dynamic/` for new modules created by agents (e.g., darwin). When a dynamic module proves useful, it is promoted to the appropriate subdirectory and added to init.el's explicit load list.

## Naming Convention

Per `GUIDELINES.org` (the coding guidelines document at the repo root):

- `iar--<name>`: internal functions and variables
- `iar-<name>`: public functions and user-facing defcustoms
- `iar-tool--<name>`: tool module provide symbols (one tool per file)
- Module files: `iar-kebab-case.el` for system modules, `<tool_name>.el` for tool modules
- No `my-gptel--` or `iar--mygptel--` prefix. These existed because modules hooked directly into gptel internals. The tool call layer eliminates that coupling. All functions are `iar--` (internal) or `iar-` (public).

## Configuration Files (configs/)

Configuration was split from a single `metaconfig/parameters.el` into individual functional config files in `emacs.d/configs/`. Each file owns defcustoms for one area. Loaded by `init.el` before any `init.d/` module.

| Config File | Provide Symbol | Purpose |
|-------------|----------------|---------|
| `paths.el` | `iar-config-paths` | Base directory paths. All paths relative to `iar-personalization-path` (default: `/root/personalization`). Defines: `iar-personalization-path`, `iar-archetypes-path` (agents.d/archetypes), `iar-personalities-path` (agents.d/personalities), `iar-projects-path` (projects), `iar-cycles-path` (agents.d/cycles), `iar-prompts-path` (agents.d/common), `iar-docs-path` (docs), `iar-knowledge-base-path` (knowledge), `iar-audit-path` (audit), `iar-tasks-path` (tasks). Legacy: `iar-agents-path` (deprecated). |
| `predicates.el` | `iar-config-predicates` | Predicate utilities used by other config files. |
| `keybindings.el` | `iar-config-keybindings` | Keybindings: `iar-key-load-agent` (C-c a), `iar-key-load-knowledge` (C-c k), `iar-key-load-personality` (C-c p), `iar-key-prompt-info` (C-c i), `iar-key-view-prompt` (C-c v), `iar-key-buffer-info` (C-c b), `iar-key-quit` (C-x C-c). Note: `iar-key-summarize` (C-c m) is defined but the summarizer module has been removed. |
| `delimiters.el` | `iar-config-delimiters` | Delimiters and markers: knowledge delimiters, sanitized wrappers, injection suspect prefix, delegation result marker, one-shot response delimiters (`iar-one-shot-response-open`, `iar-one-shot-response-close`). |
| `git.el` | `iar-config-git` | Git commit identity: `iar-git-author-name`, `iar-git-author-email`. |
| `fork.el` | `iar-config-fork` | Gptel fork path: `iar-fork-path`. |
| `delegate.el` | `iar-config-delegate` | Delegate parameters: `iar-delegate-max-depth`, `iar-delegate-max-turns`. |
| `cycle.el` | `iar-config-cycle` | Cycle parameters: `iar-cycle-timeout`, `iar-cycle-max-turns`. |
| `loop-guard.el` | `iar-config-loop-guard` | Loop guard thresholds: `iar-loop-soft-threshold`, `iar-loop-hard-threshold`, `iar-loop-history-size`. |
| `memory.el` | `iar-config-memory` | Memory parameters: `iar-personal-file-max-lines` (max lines injected from LOGS.md/STATE.org, default 100). Legacy fields `iar-memory-max-entries`, `iar-memory-timeout`, `iar-memory-max-conversation-chars` remain but the summarizer module that used them is removed. |
| `file-guard.el` | `iar-config-file-guard` | File guard protected paths: `iar-guard-always-protected`, `iar-guard-conditional-protected`. |
| `debug.el` | `iar-config-debug` | Debug/size parameters: `iar-fs-read-max-size`, `iar-tool-result-max-chars`, `iar-audit-log-max-size`, `iar-buffer-warn-size`, `iar-buffer-hard-cap`. |
| `gptel.el` | `iar-config-gptel` | Ollama backend configuration. Defines models, host, request params. |
| `tasks.el` | `iar-config-tasks` | Task system parameters: `iar-task-description-limit` (default 500, max chars for task descriptions in create_task). |

## Shared Utilities

| Module | Purpose |
|--------|---------|
| `init.d/shared/iar-utils.el` | Consolidated utilities: `iar--get-agent-name` (agent name resolution -- checks buffer-local then global default for `iar--current-agent-name`, falls back to `iar--current-agent-file`, derives name from path, returns "unknown" if none set), `iar--non-blank-p`, `iar--path-traversal-check`, `iar--approx-token-count` (chars -> tokens via ~4 chars/token heuristic), `iar--audit-log-path` (defconst -- constructed from `iar-audit-path` + `iar-personalization-path`), `iar--with-suppressed-save-hooks` (macro binding 5 hooks to nil). Declares `iar-audit-path` defvar (from configs/paths.el). Requires subr-x. Provide symbol: `iar-utils`. |
| `init.d/shared/iar-agent-utils.el` | Agent validation and path resolution: `iar--valid-name-p` (agent/task name validation with string anchors to prevent multi-line bypass), `iar--validate-agent-name`/`iar--validate-task-name` (error wrappers), `iar--resolve-agent-dir` (resolves per-agent directory under "tasks" or "audit" with `file-truename` traversal defense), `iar--resolve-agent-tasks-dir`/`iar--resolve-agent-audit-dir` (convenience wrappers), `iar--resolve-task-path` (adds `.md` extension, validates name, checks traversal). Backward compat aliases: `iar--valid-agent-name-p`, `iar--valid-task-name-p`, `iar--get-agent-dir`. Declares defvars `iar-tasks-path`, `iar-audit-path` (from configs/paths.el). Requires cl-lib, subr-x, iar-utils. Provide symbol: `iar-agent-utils`. |

## Core Infrastructure

| Module | Purpose |
|--------|---------|
| `init.el` | Entry point. Loads configs/ files first, then shared utilities, then sets self-modification mode from `EMACBOROS_SELF_MODIFICATION` env var. Sets `iar--current-project` from `IAR_PROJECT` env var (default: "iar"). Loads all modules explicitly in dependency order, including `execute_code_remote.el` after `execute_code_local.el`. Auto-discovers `init.d/dynamic/*.el` at the end. Sets `load-prefer-newer t`. Note: `iar.sh` manages sidecar container lifecycle -- parses `#+CONTAINERS` from project files to start sidecar containers before Emacs, supports `--no-containers` flag to force-disable sidecars, and `--container-image target:image` to override container images. Container IDs are passed via `IAR_CONTAINER_<target>` env vars. |
| `core/iar-locale.el` | UTF-8 locale configuration. Must load first. Enforces UTF-8 at Emacs level for containerized environments where locale env vars may not be set. Provide symbol: `iar-locale`. |
| `core/iar-package-setup.el` | Package manager setup. Adds MELPA to `package-archives`, calls `package-initialize`. Does NOT load `use-package` -- individual modules use their own `use-package` forms. Provide symbol: `iar-package-setup`. |
| `core/iar-ui-cleanup.el` | UI cleanup. Disables `menu-bar-mode` and `tool-bar-mode` (fboundp-guarded). Sets `inhibit-startup-message` to t. Provide symbol: `iar-ui-cleanup`. |
| `core/iar-evil-mode.el` | Evil mode (vim keybindings). Loads `evil` and `evil-collection` via `use-package`. Provide symbol: `iar-evil-mode`. |
| `core/iar-gptel-setup.el` | Loads gptel package and applies configs/gptel.el settings. Fork override: if `iar-fork-path` is a valid directory, prepends it to `load-path` so the fork takes precedence over the ELPA-installed package. Provide symbol: `iar-gptel-setup`. |
| `core/iar-mount-awareness.el` | Extra mount discovery. Reads `IAR_EXTRA_MOUNTS` env var (comma-separated `path:mode` pairs) at load time. `iar--extra-mounts-prompt-string` returns formatted string for system prompt injection. Integrated with `iar-prompt-assembly.el`. Provide symbol: `iar-mount-awareness`. |

## Tool Call Layer

| Module | Purpose |
|--------|---------|
| `init.d/tool-call/iar-tool-call.el` | **The single integration point with gptel.** This is the ONLY module that touches gptel's internal FSM, curl internals, or tool processing. All other i.ar modules hook into this layer, not gptel directly. **Owns:** Tool registration (`iar-tool-register`, `iar-tool-make` -- wraps `gptel-make-tool` + `add-to-list`), i.ar hook variables (`iar-pre-tool-call-functions`, `iar-post-tool-call-functions`, `iar-post-response-functions` -- bridged to gptel's hooks), result truncation (`iar--truncate-tool-result` -- middle-truncation via `:around` advice on `gptel--process-tool-call`), audit logging (every tool call logged with status in post-tool-call bridge), token usage tracking (`iar--usage-parse-tokens` -- parses `prompt_eval_count` and `eval_count` from Ollama responses via `:before` advice on `gptel-curl--stream-cleanup` and `gptel-curl--sentinel`). Global accumulators: `iar--usage-requests`, `iar--usage-input-tokens`, `iar--usage-output-tokens`, `iar--usage-last-input`, `iar--usage-last-output`, `iar--usage-model`. `iar--usage-reset` (called at cycle start), `iar--usage-totals` (returns plist), `iar--usage-write-log` (writes to `audit/<project>/<personality>/USAGE.log` on `kill-emacs-hook`). Self-installs via `iar--tool-call-setup` at load time. **If gptel's internals change, only this file needs updating.** Requires gptel, cl-lib, subr-x, json, iar-utils, iar-audit-log. Provide symbol: `iar-tool-call`. |

## Agent System

| Module | Purpose |
|--------|---------|
| `agent/iar-prompt-assembly.el` | **Prompt assembly engine.** Assembles a complete system prompt from three primitives: archetype + personality + project. Assembly order: base_context.org, archetype content, personality content, project objective, auto-loaded knowledge (from project `#+KNOWLEDGE`), memory injection (mode-based), mount info, container info. Key functions: `iar--assemble-prompt` (main entry, returns plist with :prompt, :tools, :mode, :archetype, :personality, :project, :containers), `iar--read-archetype`, `iar--read-personality`, `iar--read-base-context`, `iar--parse-mode` (extracts `#+MODE:` from archetype), `iar--inject-memory` (mode-based: LOGS.md for interactive, STATE.org for autonomous/continuous, none for delegated), `iar--auto-load-knowledge` (reads doc labels from project, loads via `iar--read-knowledge-files`), `iar--filter-tools` (filters `gptel-tools` to only those in project `#+TOOLS` list; accepts optional `containers` argument -- when non-nil, `execute_code_remote` is always included in the tool list, implied by `#+CONTAINERS`), `iar--format-containers` (injects available targets + descriptions into system prompt), `iar--container-descriptions` (defconst mapping target names to brief descriptions). Requires cl-lib, subr-x, ox, iar-utils, iar-project-parser, iar-knowledge-loader, iar-mount-awareness. Provide symbol: `iar-prompt-assembly`. |
| `agent/iar-project-parser.el` | **Project file parser.** Parses `personalization/projects/<name>.org` files. Extracts `#+KNOWLEDGE` (doc labels), `#+TOOLS` (tool name list), `#+CONTAINERS` (sidecar container target list), `#+MOUNTS` (path:mode pairs), `#+OBJECTIVE` (free text). Returns `:containers` key in project plist (list of strings or nil). Key functions: `iar--parse-project-metadata`, `iar--parse-project`, `iar--load-project`, `iar--load-or-create-project` (creates template project if not found), `iar--project-candidates` (lists available projects for completion), `iar--create-project` (writes minimal template). Requires cl-lib, subr-x. Provide symbol: `iar-project-parser`. |
| `agent/iar-agent-loader.el` | **C-c a** -- Interactive agent loader (`iar-load-agent`). Prompts for personality selection, assembles prompt with interactive archetype + selected personality + default project. **C-c p** -- Personality switcher (`iar-load-personality-interactive`). Re-assembles with current archetype + project. Key state: `iar--current-archetype`, `iar--current-personality`, `iar--current-project`, `iar--current-mode`, `iar--current-containers` (all buffer-local). `iar--current-containers` is set from the assembly result's `:containers` key, making sidecar container targets available for validation by `execute_code_remote`. `iar-personality-archetype-map` (hardcoded personality-to-archetype mapping, includes `("pentest" . "interactive")`). `iar--archetype-for-personality` (lookup), `iar--project-for-personality` (if project file matching personality exists, use it; else "iar"). `iar--setup-assembled-buffer` (calls `iar--assemble-prompt`, sets all buffer-local state, resets knowledge state). Backward compat: `iar--current-agent-name` = personality name, `iar--current-agent-file` = personality file path. Requires cl-lib, subr-x, iar-agent-utils, iar-utils, iar-prompt-assembly, iar-project-parser. Provide symbol: `iar-agent-loader`. |
| `agent/iar-knowledge-loader.el` | **C-c k** -- Interactive knowledge folder loader (`iar-load-knowledge`). Reads `.md`/`.org` files from a `docs/<folder>/` directory. If `_overview.md` exists in the directory, only that file is loaded (overview mode); otherwise all `.md`/`.org` files are loaded (full mode). Appends to system prompt with delimiters from configs/delimiters.el. Supports multiple knowledge bases simultaneously. Idempotent. Buffer-local state: `iar--knowledge-base-prompt`, `iar--knowledge-loaded-labels`, `iar--knowledge-blocks`. `iar-load-knowledge-dir` (non-interactive, used by assembly engine and agent_cycle.el for batch mode). **C-c p** -- Personality loader (`iar-load-personality`) -- re-exported from iar-agent-loader.el. **C-c i** -- Prompt size info (`iar-prompt-info`). Requires cl-lib, subr-x, iar-utils. Provide symbol: `iar-knowledge-loader`. |
| `agent/iar-buffer-info.el` | **C-c b** -- Buffer size info (`iar-buffer-info`): displays conversation buffer size in chars and approx tokens. **C-c v** -- View full system prompt (`iar-view-prompt`): displays entire system prompt in read-only `view-mode` buffer. Split from `iar-knowledge-loader.el` per GUIDELINES.org rule 5 (one responsibility per file). Requires subr-x, iar-utils. Provide symbol: `iar-buffer-info`. |
| `agent/iar-personality-loader.el` | **Compatibility shim.** Personality loading is now handled by `iar-agent-loader.el`. This file provides `iar--personalities-dir` for backward compat. Requires iar-agent-loader. Provide symbol: `iar-personality-loader`. |
| `agent/iar-prompt-loader.el` | Loads prompt templates from `agents.d/common/*.org`. Single function `iar--load-prompt` (name) -- constructs path, appends `.org` extension, reads file content, trims trailing whitespace. Signals `error` if file not found. Used by delegate, agent_cycle, loop_guard. Requires subr-x. Provide symbol: `iar-prompt-loader`. |
| `agent/iar-agent-cycle.el` | Autonomous agent cycle runner (`iar-run-cycle`). Any personality with an autonomous/continuous archetype can run autonomously in a loop. Has its own cycle buffer (`*<agent>-cycle*`), timeout, max turns, continue prompting. Supports `:agent`, `:knowledge`, `:self-modification`, `:timeout`, `:prompt` parameters. `iar-personality-cycle-map` maps personalities to cycle files (darwin -> self_modification, gardener -> monitoring, librarian -> documentation_sync). Per-agent cycle prompt loading (`<personality>_cycle.org` fallback to `agent_cycle.org`). Continue prompt loading (`agent_cycle_continue.org` fallback to defconst). Completion detection via `iar--cycle-complete-p` (LOOP_COMPLETE vs CYCLE_COMPLETE markers). Continuation via `gptel-post-response-functions` hook. Cycle logging to `audit/<project>/<personality>/cycle.log`. Token usage tracking. Telegram notification on cycle end via `kill-emacs-hook`. Batch mode event loop: `accept-process-output` with FSM state monitoring. Uses `iar--archetype-for-personality` and `iar--project-for-personality` to resolve archetype and project from personality name. Exit codes: 0 (cycle complete), 1 (timeout), 2 (LOOP_COMPLETE). `iar-darwin-run-cycle` backward compat alias. **One-shot mode:** `iar-run-one-shot` function for single-instruction execution. Forces archetype to "one-shot" (not from personality map). Reads prompt from `IAR_ONE_SHOT_PROMPT` env var. Completion detected via `iar--one-shot-extract-response` (searches for `iar-one-shot-response-open`/`iar-one-shot-response-close` delimiters). Nudge prompt sent when agent produces text without delimiters. Final response printed to stdout via `princ`. Separate state: `iar--one-shot-state`. Requires gptel, cl-lib, subr-x, json. Provide symbol: `iar-agent-cycle`. |

## Filesystem and Code Tools (one tool per file)

| Module | Tool | Purpose |
|--------|------|---------|
| `tools/filesystem/list_directory.el` | `list_directory` | List directory contents. Returns newline-separated file names including hidden files, excludes `.` and `..`. Directory entries suffixed with `/`. Results sorted alphabetically. Provide symbol: `iar-tool--list-directory`. |
| `tools/filesystem/read_file.el` | `read_file` | Read file contents into context. Size-limited by `iar-fs-read-max-size` (default 1MB, from configs/debug.el) using character count. Truncation notice appended when limit exceeded. Provide symbol: `iar-tool--read-file`. |
| `tools/filesystem/write_file.el` | `write_file` | Create or overwrite a file. File-guard enforced. Buffer-aware: if file is open in a buffer, checks read-only/modified, then erases/inserts/saves with `iar--with-suppressed-save-hooks`. Otherwise uses atomic write (temp file + rename). Creates parent directories. Audit-logged. Provide symbol: `iar-tool--write-file`. |
| `tools/filesystem/append_file.el` | `append_file` | Append text to end of file. Auto-prepends newline if needed. File-guard enforced. Buffer-aware. Creates parent directories if needed. Audit-logged. Provide symbol: `iar-tool--append-file`. |
| `tools/code/execute_code_local.el` | `execute_code_local` | Async bash/shell command execution in the container. Uses `:connection-type 'pipe` (no pty). Default timeout 3600s. Output sanitization when `iar--sanitize-exec-output` is non-nil. Audit-logged. Provide symbol: `iar-tool--execute-code-local`. |
| `tools/code/execute_code_remote.el` | `execute_code_remote` | Async command execution in sidecar containers or remote hosts. Local targets resolved from `IAR_CONTAINER_<target>` env var (executed via `podman exec`). Remote targets resolved from `iar-remote-targets` defcustom or `IAR_REMOTE_TARGETS` env var (executed via SSH over WireGuard using `make-process` with explicit argv -- no shell injection). SSH uses key-only auth. Output sanitization via `iar--sanitize-exec-output`. Buffer-local `iar--current-containers` validates targets against available containers. Registered via `iar-tool-register`. Provide symbol: `iar-tool--execute-code-remote`. |
| `tools/code/check_elisp.el` | `check_elisp` | Check .el files for syntax errors, unbalanced parens, and byte-compilation warnings. Two-phase: `check-parens` in temp buffer, then `byte-compile-file` with temp .elc. Does NOT modify the file. Provide symbol: `iar-tool--check-elisp`. |

## Task Management Tools (one tool per file)

| Module | Tool | Purpose |
|--------|------|---------|
| `tools/tasks/read_task.el` | `read_task` | Read tasks from the current agent's tasks directory. With no argument, returns a tree-like hierarchy of all tasks with descriptions. With a path argument, returns detail at that level. Uses `iar--resolve-task-dir` and `iar--resolve-task-file` for path resolution. Provide symbol: `iar-tool--read-task`. |
| `tools/tasks/create_task.el` | `create_task` | Create a new task directory with a description.org file. Path is slash-separated. Description limited to `iar-task-description-limit` characters (default 500, from configs/tasks.el). Provide symbol: `iar-tool--create-task`. |
| `tools/tasks/write_subtask.el` | `write_subtask` | Write a subtask .org file inside a task directory. Path is slash-separated where the last segment becomes the filename. Provide symbol: `iar-tool--write-subtask`. |
| `tools/tasks/remove_task.el` | `remove_task` | Delete a task file. Resolves path via `iar--resolve-task-path`. Returns "marked done" on success. Provide symbol: `iar-tool--remove-task`. |
| `tools/tasks/read_history.el` | `read_history` | Read per-agent or unified HISTORY.log. If agent_name provided: reads single `audit/<project>/<name>/HISTORY.log`. If omitted: scans all agent dirs, merges sorted by timestamp into unified timeline. Provide symbol: `iar-tool--read-history`. |
| `tools/tasks/read_roadmap.el` | `read_roadmap` | Read the ROADMAP.org file from the current agent's tasks directory. The roadmap defines task ordering, dependencies, and cycle guidelines for continuous agents. Provide symbol: `iar-tool--read-roadmap`. |
| `tools/tasks/write_roadmap.el` | `write_roadmap` | Write or overwrite the ROADMAP.org file in the current agent's tasks directory. File-guard protected (append-only for write_file). Use this tool to update the roadmap. Provide symbol: `iar-tool--write-roadmap`. |

## Notification and Git Tools

| Module | Tool | Purpose |
|--------|------|---------|
| `tools/notify/telegram.el` | `send_telegram` | Send Telegram notification via Bot API. Async tool. Credentials from `AGENT_TELEGRAM_BOT_TOKEN` and `AGENT_TELEGRAM_CHAT_ID` env vars. Uses curl POST with 10s timeout. Audit-logged. Provide symbol: `iar-tool--telegram`. |
| `tools/git/git_commit.el` | `git_commit` | Stage all changes and commit. Sync tool using `call-process` directly (no shell). Validates repo directory and `.git` presence. Git identity auto-configured from configs/git.el. Audit-logged. Provide symbol: `iar-tool--git-commit`. |

**STATUS:** Matrix server (daftpunk) was killed. These tools are dead unless Matrix is redeployed.
## Matrix Communication Tools (one tool per file)

| Module | Tool | Purpose |
|--------|------|---------|
| `tools/matrix/send_matrix_message.el` | `send_matrix_message` | Send a text message to a Matrix room via Client-Server API. Async tool. Credentials: per-agent Matrix token, resolved from agent name via env var. Provide symbol: `iar-tool--send-matrix-message`. |
| `tools/matrix/read_matrix_chat.el` | `read_matrix_chat` | Read recent messages from a Matrix room. Sync tool. Returns formatted transcript with timestamps and sender names. Provide symbol: `iar-tool--read-matrix-chat`. |
| `tools/matrix/list_matrix_chats.el` | `list_matrix_chats` | List joined rooms for the current agent's Matrix account. Sync tool. Returns room IDs. Provide symbol: `iar-tool--list-matrix-chats`. |

## Agent Tools (tools/agent/)

| Module | Tool | Purpose |
|--------|------|---------|
| `tools/agent/delegate.el` | `delegate` | Async multi-agent delegation. Agent parameter is optional -- when omitted, defaults to agent-assistant (pipeline mode). When specified, spawns that personality directly (direct mode). Spawns sub-agent buffers with timeout handling, max depth limiting, unknown tool blocking, text-only turn re-prompting. Resolves archetype and project from personality name via `iar--archetype-for-personality` and `iar--project-for-personality`. Assembles prompt via `iar--assemble-prompt`. Applies tool gating from project `#+TOOLS`. Result extraction via `=== DELEGATION RESULT ===` marker. Pipeline: agent-assistant (depth 1) delegates to implementer/reviewer (depth 2), correction loop limited by archetype prompt (default 2 rounds). Provide symbol: `iar-delegate-tool`. |
| `tools/agent/reload_os.el` | `reload_os` | Re-evaluate init.el. Rebuilds gptel-tools list. Use after modifying .el files. Provide symbol: `iar-reload-os`. |
| `tools/agent/reload_agent.el` | `reload_agent` | Re-read personality .org and update system prompt in current buffer. Re-assembles via `iar--setup-assembled-buffer` with current archetype + project. Optional agent-name arg. Provide symbol: `iar-reload-agent`. |

## Security and Safety

| Module | Purpose |
|--------|---------|
| `security/iar-output-sanitizer.el` | Output filtering for tool results. Defense-in-depth -- primary defense is PROMPT INJECTION RESISTANCE directives in base_context.org. `iar--sanitize-external-output` (text): strips control chars (`iar--strip-control-chars` -- ANSI, zero-width, bidi), neutralizes wrapper tags, flags injection lines. Buffer-local `iar--sanitize-exec-output` flag (nil by default). Requires subr-x. Provide symbol: `iar-output-sanitizer`. |
| `security/iar-file-guard.el` | Protected path enforcement. Two tiers: always-protected (archetype/personality/cycle files, base context, history logs, LOGS.md, STATE.org) and conditionally-protected (.el files, Containerfile, iar.sh, git hooks). Protected paths defined as defcustoms in configs/file-guard.el with (regex reason append-allowed) triples. `iar--guard-check-write`, `iar--guard-check-replace`, `iar--guard-check-append`. `iar-guard-allow-self-modification` defcustom intentionally lacks `:safe` property. Self-modification mode relaxes tier 2 but never tier 1. Requires cl-lib, subr-x. Provide symbol: `iar-file-guard`. |
| `security/iar-audit-log.el` | Audit logging for all file operations and command executions. Log at `audit/audit.log`. `iar--audit-log` (tool detail) is the main entry point -- best-effort via condition-case. Wrapper functions: `iar--audit-log-write`, `iar--audit-log-replace`, `iar--audit-log-append`, `iar--audit-log-exec`. Rotation at `iar-audit-log-max-size` (from configs/debug.el). Requires subr-x, iar-utils. Provide symbol: `iar-audit-log`. |
| `security/iar-loop-guard.el` | Detects repetitive tool call loops via `iar-pre-tool-call-functions` hook (i.ar's own hook, not gptel's). Soft threshold (default 3): after N identical consecutive calls, tool is blocked and correction message sent. Hard threshold (default 6): entire request stopped. History ring size 20. Args signature via md5. Provide symbol: `iar-loop-guard`. |
| `security/iar-tool-guard.el` | Unknown tool blocking utility. `iar--block-unknown-tools` intercepts hallucinated tool names at the pre-tool-call stage. Returns `(:block message)` for unknown tools. Uses dynamic variable `gptel-tools` for tool list resolution. Used by delegate buffers and cycle buffers. Requires cl-lib. Provide symbol: `iar-tool-guard`. |

## Debug and Monitoring

| Module | Purpose |
|--------|---------|
| `debug/iar-status-mode.el` | Custom mode-line display for agent session metrics. Replaces the old buffer-monitor, request-logger, and fsm-tracer modules (which were removed). Shows 6 data points in the mode line: agent name, prompt size in chars, last request input/output tokens, cumulative input/output tokens. All token data comes from the tool call layer's accumulators (`iar--usage-*` variables). No gptel internals. Uses `(:eval ...)` mode-line construct for live updates. Format: `[agent prompt_size] last:in/out total:in/out`. Requires subr-x, cl-lib, iar-utils, iar-tool-call. Provide symbol: `iar-status-mode`. |

## Session Management

| Module | Purpose |
|--------|---------|
| `session/iar-quit.el` | Session-aware shutdown (`iar-quit`). Bound to C-x C-c. With prefix ARG, skips summarization. Normal quit: checks `gptel-mode`, then quits via `save-buffers-kill-emacs` after 0.5s delay. `condition-case` error handling. The memory summarizer (`iar-summarize-session`) has been removed -- quit no longer calls it. Requires subr-x. Provide symbol: `iar-quit`. |

## Keybindings

| Key | Command | Description |
|-----|---------|-------------|
| C-c a | `iar-load-agent` | Select personality and assemble prompt (interactive archetype + default project) |
| C-c k | `iar-load-knowledge` | Load knowledge folder/file on top of assembled prompt |
| C-c p | `iar-load-personality-interactive` | Switch personality (re-assemble with current archetype + project) |
| C-c i | `iar-prompt-info` | Show prompt size info |
| C-c v | `iar-view-prompt` | View full system prompt (read-only) |
| C-c b | `iar-buffer-info` | Show conversation buffer size (chars + approx tokens) |
| C-x C-c | `iar-quit` | Session-aware quit |

Note: C-c m (memory summarizer) has been removed. The `iar-key-summarize` defcustom still exists in configs/keybindings.el but the command it bound to (`iar-summarize-session`) is no longer loaded.

All keybindings are defcustoms in `configs/keybindings.el` and can be changed without editing module code.

## Agent Prompt Assembly

Agents are no longer loaded from monolithic `prompt.org` files. The three-axis assembly model constructs prompts from independent primitives:

```
agents.d/archetypes/<name>.org    -- Behavioral mode (interactive, autonomous, etc.)
agents.d/personalities/<name>.org -- Voice/character (mirror, darwin, etc.)
personalization/projects/<name>.org -- Knowledge, tools, mounts, objective
```

The assembly engine (`iar-prompt-assembly.el`) reads all three, combines them with `base_context.org`, auto-loads project knowledge, injects mode-based memory, and filters tools. The result is a single system prompt + filtered tool list set buffer-locally by `iar--setup-assembled-buffer`.

Memory files are injected programmatically by the assembly engine based on the archetype's `#+MODE:` metadata:
- Interactive: LOGS.md (last N lines) from `audit/<project>/<personality>/`
- Autonomous/Continuous: STATE.org (full) from `audit/<project>/<personality>/`
- Delegated: No memory injection

Task files are read on demand via the `read_task` tool from `tasks/<project>/`.

## Shared Context

`prompts/base_context.org` contains shared context inherited by all agents (bind-mounted to `agents.d/base_context.org`). It is injected by the assembly engine directly -- not via `#+INCLUDE`. Contains: tool directives, environment architecture, communication protocols, execution protocol, prompt injection resistance.

## Prompt Templates

`prompts/common/` contains prompt templates used by the system (not user-facing, bind-mounted to `agents.d/common/`):
- `delegated_task.org` -- Template for delegate task prompts
- `delegate_continue.org` -- Re-prompt for delegates that narrate instead of acting
- `agent_cycle.org` -- Shared cycle prompt for all autonomous agents
- `agent_cycle_continue.org` -- Shared cycle continuation prompt
- `continuous_agent.org` -- Generic protocol for continuous agents
- `loop_soft_block.org` -- Loop guard soft block message
- `loop_hard_stop.org` -- Loop guard hard stop message
- `unknown_tool.org` -- Unknown tool error message
- `mount_info.org` -- Extra mount info template
- `memory_summarizer.org` -- Memory summarization prompt (legacy, summarizer module removed)
- `matrix_turn.org` -- Matrix watcher turn prompt

## Cycle Prompts

`prompts/cycles/` contains cycle prompts for autonomous and continuous agents (bind-mounted to `agents.d/cycles/`):
- `self_modification.org` -- Darwin's cycle: read state, read tasks, make one change, review, test, commit, log, update state
- `monitoring.org` -- Gardener's cycle: pull latest, compare HEAD to last checked commit, run tests, diagnose failures, write tasks for darwin
- `documentation_sync.org` -- Librarian's cycle: pick one source file, compare against docs, fix drift, commit, log

Cycle files are loaded by `iar-agent-cycle.el` based on `iar-personality-cycle-map`.

## Coding Guidelines

`GUIDELINES.org` at the repo root defines evidence-based coding conventions. Every rule traces to something found during the ownership read-through of the codebase (July 2026). Sections:

1. Naming Conventions (prefixes: `iar--`, `iar-`, `iar-tool--`)
2. Module Structure (one responsibility per file)
3. Tool Patterns (registration via `iar-tool-register`, not `add-to-list`)
4. Security Rules
5. Prompt and Text Rules
6. Error Handling
7. Architecture Rules (tool call layer is the single gptel integration point)
8. Test Conventions
9. Anti-Patterns (no `my-gptel--` prefix, no `:override` advice)
10. cl-lib Adoption
11. Module Loading
12. Forward-Declaration Comment Format

## Test Suite

Test files live in `test/` and follow the naming convention `test-<module>.el`. The test runner (`run-tests.el`) loads the gptel fork on load-path (via `EMACBOROS_GPTEL_FORK_PATH` env var) to ensure tests use the fork with our fixes instead of stale ELPA `.elc` files. Run with:
```bash
emacs --batch -l /root/.emacs.d/test/run-tests.el
```