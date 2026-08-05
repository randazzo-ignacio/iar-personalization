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
| `paths.el` | `iar-config-paths` | Base directory paths: `iar-agents-path`, `iar-prompts-path`, `iar-knowledge-path`, `iar-audit-path`, `iar-tasks-path`. |
| `predicates.el` | `iar-config-predicates` | Predicate utilities used by other config files. |
| `keybindings.el` | `iar-config-keybindings` | Keybindings: `iar-key-load-agent` (C-c a), `iar-key-load-knowledge` (C-c k), `iar-key-prompt-info` (C-c p), `iar-key-view-prompt` (C-c v), `iar-key-buffer-info` (C-c b), `iar-key-summarize` (C-c m), `iar-key-quit` (C-x C-c). |
| `delimiters.el` | `iar-config-delimiters` | Delimiters and markers: knowledge delimiters, sanitized wrappers, injection suspect prefix, delegation result marker. |
| `git.el` | `iar-config-git` | Git commit identity: `iar-git-author-name`, `iar-git-author-email`. |
| `fork.el` | `iar-config-fork` | Gptel fork path: `iar-fork-path`. |
| `delegate.el` | `iar-config-delegate` | Delegate parameters: `iar-delegate-max-depth`, `iar-delegate-max-turns`. |
| `cycle.el` | `iar-config-cycle` | Cycle parameters: `iar-cycle-timeout`, `iar-cycle-max-turns`. |
| `loop-guard.el` | `iar-config-loop-guard` | Loop guard thresholds: `iar-loop-soft-threshold`, `iar-loop-hard-threshold`, `iar-loop-history-size`. |
| `memory.el` | `iar-config-memory` | Memory tool parameters: `iar-memory-max-entries`, `iar-memory-timeout`, `iar-memory-max-conversation-chars`, `iar-personal-file-max-lines`. |
| `file-guard.el` | `iar-config-file-guard` | File guard protected paths: `iar-guard-always-protected`, `iar-guard-conditional-protected`. |
| `debug.el` | `iar-config-debug` | Debug/size parameters: `iar-fs-read-max-size`, `iar-tool-result-max-chars`, `iar-audit-log-max-size`, `iar-buffer-warn-size`, `iar-buffer-hard-cap`. |
| `gptel.el` | `iar-config-gptel` | Ollama backend configuration. Defines models, host, request params. |

## Shared Utilities

| Module | Purpose |
|--------|---------|
| `init.d/shared/iar-utils.el` | Consolidated utilities: `iar--get-agent-name` (agent name resolution -- checks buffer-local then global default for `iar--current-agent-name`, falls back to `iar--current-agent-file` also buffer-local then global, derives name from prompt.org path, returns "unknown" if none set), `iar--non-blank-p`, `iar--path-traversal-check`, `iar--approx-token-count` (chars -> tokens via ~4 chars/token heuristic), `iar--audit-log-path` (defconst -- constructed from `iar-audit-path` defvar + `user-emacs-directory`), `iar--with-suppressed-save-hooks` (macro binding 5 hooks to nil). Declares `iar-audit-path` defvar (from configs/paths.el). Requires subr-x. Provide symbol: `iar-utils`. |
| `init.d/shared/iar-agent-utils.el` | Agent validation and path resolution: `iar--valid-name-p` (agent/task name validation with string anchors to prevent multi-line bypass), `iar--validate-agent-name`/`iar--validate-task-name` (error wrappers), `iar--resolve-agent-dir` (resolves per-agent directory under "tasks" or "audit" with `file-truename` traversal defense), `iar--resolve-agent-tasks-dir`/`iar--resolve-agent-audit-dir` (convenience wrappers), `iar--resolve-task-path` (adds `.md` extension, validates name, checks traversal). Backward compat aliases: `iar--valid-agent-name-p`, `iar--valid-task-name-p`, `iar--get-agent-dir`. Declares defvars `iar-tasks-path`, `iar-audit-path` (from configs/paths.el). Requires cl-lib, subr-x, iar-utils. Provide symbol: `iar-agent-utils`. |

## Core Infrastructure

| Module | Purpose |
|--------|---------|
| `init.el` | Entry point. Loads configs/ files first, then shared utilities, then sets self-modification mode from `EMACBOROS_SELF_MODIFICATION` env var. Loads all modules explicitly in dependency order. Auto-discovers `init.d/dynamic/*.el` at the end. Sets `load-prefer-newer t`. |
| `core/iar-locale.el` | UTF-8 locale configuration. Must load first. Enforces UTF-8 at Emacs level for containerized environments where locale env vars may not be set. Provide symbol: `iar-locale`. |
| `core/iar-package-setup.el` | Package manager setup. Adds MELPA to `package-archives`, calls `package-initialize`. Does NOT load `use-package` -- individual modules use their own `use-package` forms. Provide symbol: `iar-package-setup`. |
| `core/iar-ui-cleanup.el` | UI cleanup. Disables `menu-bar-mode` and `tool-bar-mode` (fboundp-guarded). Sets `inhibit-startup-message` to t. Provide symbol: `iar-ui-cleanup`. |
| `core/iar-evil-mode.el` | Evil mode (vim keybindings). Loads `evil` and `evil-collection` via `use-package`. Provide symbol: `iar-evil-mode`. |
| `core/iar-gptel-setup.el` | Loads gptel package and applies configs/gptel.el settings. Fork override: if `iar-fork-path` is a valid directory, prepends it to `load-path` so the fork takes precedence over the ELPA-installed package. Provide symbol: `iar-gptel-setup`. |
| `core/iar-mount-awareness.el` | Extra mount discovery. Reads `IAR_EXTRA_MOUNTS` env var (comma-separated `path:mode` pairs) at load time. `iar--extra-mounts-prompt-string` returns formatted string for system prompt injection. Integrated with `iar-agent-loader.el`. Provide symbol: `iar-mount-awareness`. |

## Tool Call Layer

| Module | Purpose |
|--------|---------|
| `init.d/tool-call/iar-tool-call.el` | **The single integration point with gptel.** This is the ONLY module that touches gptel's internal FSM, curl internals, or tool processing. All other i.ar modules hook into this layer, not gptel directly. **Owns:** Tool registration (`iar-tool-register`, `iar-tool-make` -- wraps `gptel-make-tool` + `add-to-list`), i.ar hook variables (`iar-pre-tool-call-functions`, `iar-post-tool-call-functions`, `iar-post-response-functions` -- bridged to gptel's hooks), result truncation (`iar--truncate-tool-result` -- middle-truncation via `:around` advice on `gptel--process-tool-call`), audit logging (every tool call logged with status in post-tool-call bridge), token usage tracking (`iar--usage-parse-tokens` -- parses `prompt_eval_count` and `eval_count` from Ollama responses via `:before` advice on `gptel-curl--stream-cleanup` and `gptel-curl--sentinel`). Global accumulators: `iar--usage-requests`, `iar--usage-input-tokens`, `iar--usage-output-tokens`, `iar--usage-last-input`, `iar--usage-last-output`, `iar--usage-model`. `iar--usage-reset` (called at cycle start), `iar--usage-totals` (returns plist), `iar--usage-write-log` (writes to `audit/<agent>/USAGE.log` on `kill-emacs-hook`). Self-installs via `iar--tool-call-setup` at load time. **If gptel's internals change, only this file needs updating.** Requires gptel, cl-lib, subr-x, json, iar-utils, iar-audit-log. Provide symbol: `iar-tool-call`. |

## Agent System

| Module | Purpose |
|--------|---------|
| `agent/iar-agent-loader.el` | **C-c a** -- Interactive agent profile loader (`iar-load-agent`). Discovers `agents.d/agents/<name>/prompt.org`, expands `#+INCLUDE` directives, injects personal files (LOGS.md, SUMMARY.md, MEMORIES.md) from `audit/<name>/` programmatically (truncated to last N lines via `iar-personal-file-max-lines`). Darwin's MEMORIES.md replaces LOGS.md + SUMMARY.md when MEMORIES.md has content but LOGS/SUMMARY don't. Sets `gptel-system-prompt` (buffer-local). Integrates with `iar-mount-awareness.el`. Tracks agent name and file via buffer-local + global `iar--current-agent-name` and `iar--current-agent-file`. Resets knowledge state on agent switch. Path traversal defense via `file-truename`. Keybinding via `iar-key-load-agent` defvar (configs/keybindings.el). Requires cl-lib, iar-agent-utils. Provide symbol: `iar-agent-loader`. |
| `agent/iar-knowledge-loader.el` | **C-c k** -- Interactive knowledge folder loader (`iar-load-knowledge`). Reads all `.md`/`.org` files from a `knowledge/<folder>/` directory (non-recursive, sorted), appends to system prompt with delimiters from configs/delimiters.el. Supports multiple knowledge bases simultaneously. Idempotent. Buffer-local state: `iar--knowledge-base-prompt`, `iar--knowledge-loaded-labels`, `iar--knowledge-blocks`. `iar-load-knowledge-dir` (non-interactive, used by agent_cycle.el for batch mode). **C-c p** -- Prompt size info (`iar-prompt-info`). Requires cl-lib, subr-x, iar-utils. Provide symbol: `iar-knowledge-loader`. |
| `agent/iar-buffer-info.el` | **C-c b** -- Buffer size info (`iar-buffer-info`): displays conversation buffer size in chars and approx tokens. **C-c v** -- View full system prompt (`iar-view-prompt`): displays entire system prompt in read-only `view-mode` buffer. Split from `iar-knowledge-loader.el` per GUIDELINES.org rule 5 (one responsibility per file). Requires subr-x, iar-utils. Provide symbol: `iar-buffer-info`. |
| `agent/iar-prompt-loader.el` | Loads prompt templates from `agents.d/common/*.org`. Single function `iar--load-prompt` (name) -- constructs path, appends `.org` extension, reads file content, trims trailing whitespace. Signals `error` if file not found. Used by delegate, agent_cycle, loop_guard, memory_tools. Requires subr-x. Provide symbol: `iar-prompt-loader`. |
| `agent/iar-memory-tools.el` | **C-c m** -- Memory summarization (`iar-summarize-session`). Sends conversation to LLM for rolling summary (old SUMMARY + conversation -> new concise SUMMARY), stores in SUMMARY.md. Synchronous via `make-process` + `accept-process-output`. Uses `memory_summarizer.org` prompt template. Auto-reloads agent profile after update. Conversation truncated to `iar-memory-max-conversation-chars` if exceeded. Parameters from configs/memory.el. Backward compat alias: `iar-summarize-memories` -> `iar-summarize-session`. Requires gptel, json, cl-lib, subr-x, iar-agent-utils. Provide symbol: `iar-memory-tools`. |
| `agent/iar-agent-cycle.el` | Autonomous agent cycle runner (`iar-run-cycle`). Any orchestrator agent can run autonomously in a loop. Has its own cycle buffer (`*<agent>-cycle*`), timeout, max turns, continue prompting. Supports `:agent`, `:knowledge`, `:self-modification`, `:timeout`, `:prompt` parameters. Per-agent cycle prompt loading (`<agent>_cycle.org` fallback to `agent_cycle.org`). Continue prompt loading (`agent_cycle_continue.org` fallback to defconst). Completion detection via `iar--cycle-complete-p` (LOOP_COMPLETE vs CYCLE_COMPLETE markers). Continuation via `gptel-post-response-functions` hook. Cycle logging to `audit/<agent>/cycle.log`. Token usage tracking (resets accumulators at cycle start, includes token counts in results). Telegram notification on cycle end via `kill-emacs-hook`. Batch mode event loop: `accept-process-output` with FSM state monitoring. Buffer-local: `gptel-stream t`, `gptel-confirm-tool-calls nil`. Exit codes: 0 (cycle complete), 1 (timeout), 2 (LOOP_COMPLETE). `iar-darwin-run-cycle` backward compat alias. Requires gptel, cl-lib, subr-x, json. Provide symbol: `iar-agent-cycle`. |

## Filesystem and Code Tools (one tool per file)

| Module | Tool | Purpose |
|--------|------|---------|
| `tools/filesystem/list_directory.el` | `list_directory` | List directory contents. Returns newline-separated file names including hidden files, excludes `.` and `..`. Directory entries suffixed with `/`. Results sorted alphabetically. Provide symbol: `iar-tool--list-directory`. |
| `tools/filesystem/read_file.el` | `read_file` | Read file contents into context. Size-limited by `iar-fs-read-max-size` (default 1MB, from configs/debug.el) using character count. Truncation notice appended when limit exceeded. Provide symbol: `iar-tool--read-file`. |
| `tools/filesystem/write_file.el` | `write_file` | Create or overwrite a file. File-guard enforced. Buffer-aware: if file is open in a buffer, checks read-only/modified, then erases/inserts/saves with `iar--with-suppressed-save-hooks`. Otherwise uses atomic write (temp file + rename). Creates parent directories. Audit-logged. Provide symbol: `iar-tool--write-file`. |
| `tools/filesystem/append_file.el` | `append_file` | Append text to end of file. Auto-prepends newline if needed. File-guard enforced. Buffer-aware. Creates parent directories if needed. Audit-logged. Provide symbol: `iar-tool--append-file`. |
| `tools/code/execute_code_local.el` | `execute_code_local` | Async bash/shell command execution in the container. Uses `:connection-type 'pipe` (no pty). Default timeout 3600s. Output sanitization when `iar--sanitize-exec-output` is non-nil. Audit-logged. Provide symbol: `iar-tool--execute-code-local`. |
| `tools/code/check_elisp.el` | `check_elisp` | Check .el files for syntax errors, unbalanced parens, and byte-compilation warnings. Two-phase: `check-parens` in temp buffer, then `byte-compile-file` with temp .elc. Does NOT modify the file. Provide symbol: `iar-tool--check-elisp`. |

## Task Management Tools (one tool per file)

| Module | Tool | Purpose |
|--------|------|---------|
| `tools/tasks/read_tasks.el` | `read_tasks` | Read all task .md files from current agent's tasks directory. Each task formatted with basename and trimmed content. Provide symbol: `iar-tool--read-tasks`. |
| `tools/tasks/write_task.el` | `write_task` | Create a new task file. Resolves path via `iar--resolve-task-path`. Refuses to overwrite existing files. Creates parent directory if needed. Provide symbol: `iar-tool--write-task`. |
| `tools/tasks/remove_task.el` | `remove_task` | Delete a task file. Resolves path via `iar--resolve-task-path`. Returns "marked done" on success. Provide symbol: `iar-tool--remove-task`. |
| `tools/tasks/read_history.el` | `read_history` | Read per-agent or unified HISTORY.log. If agent_name provided: reads single `audit/<name>/HISTORY.log`. If omitted: scans all agent dirs, merges sorted by timestamp into unified timeline. Provide symbol: `iar-tool--read-history`. |

## Notification and Git Tools

| Module | Tool | Purpose |
|--------|------|---------|
| `tools/notify/telegram.el` | `send_telegram` | Send Telegram notification via Bot API. Async tool. Credentials from `AGENT_TELEGRAM_BOT_TOKEN` and `AGENT_TELEGRAM_CHAT_ID` env vars. Uses curl POST with 10s timeout. Audit-logged. Provide symbol: `iar-tool--telegram`. |
| `tools/git/git_commit.el` | `git_commit` | Stage all changes and commit. Sync tool using `call-process` directly (no shell). Validates repo directory and `.git` presence. Git identity auto-configured from configs/git.el. Audit-logged. Provide symbol: `iar-tool--git-commit`. |

**STATUS:** Matrix server (daftpunk) was killed. These tools are dead unless Matrix is redeployed.
## Matrix Communication Tools (one tool per file)

| Module | Tool | Purpose |
|--------|------|---------|
| `tools/matrix/send_matrix_message.el` | `send_matrix_message` | Send a text message to a Matrix room via Client-Server API. Async tool. Credentials: per-agent Matrix token, resolved from agent name via env var (e.g., `MIRROR_BOT_MATRIX_TOKEN`). Token resolution and server URL shared with other matrix tools. Provide symbol: `iar-tool--send-matrix-message`. |
| `tools/matrix/read_matrix_chat.el` | `read_matrix_chat` | Read recent messages from a Matrix room. Sync tool (curl is fast). Returns formatted transcript with timestamps and sender names. Provide symbol: `iar-tool--read-matrix-chat`. |
| `tools/matrix/list_matrix_chats.el` | `list_matrix_chats` | List joined rooms for the current agent's Matrix account. Sync tool. Returns room IDs. Provide symbol: `iar-tool--list-matrix-chats`. |

## Agent Tools (tools/agent/)

| Module | Tool | Purpose |
|--------|------|---------|
| `tools/agent/delegate.el` | `delegate` | Async multi-agent delegation. Spawns sub-agent buffers with timeout handling, max depth limiting, unknown tool blocking, text-only turn re-prompting. Result extraction via `=== DELEGATION RESULT ===` marker. Provide symbol: `iar-delegate-tool`. |
| `tools/agent/reload_os.el` | `reload_os` | Re-evaluate init.el. Rebuilds gptel-tools list. Use after modifying .el files. Provide symbol: `iar-reload-os`. |
| `tools/agent/reload_agent.el` | `reload_agent` | Re-read agent prompt.org and update system prompt in current buffer. Optional agent-name arg. Path traversal defense. Provide symbol: `iar-reload-agent`. |

## Security and Safety

| Module | Purpose |
|--------|---------|
| `security/iar-output-sanitizer.el` | Output filtering for tool results. Defense-in-depth -- primary defense is PROMPT INJECTION RESISTANCE directives in base_context.org. `iar--sanitize-external-output` (text): strips control chars (`iar--strip-control-chars` -- ANSI, zero-width, bidi), neutralizes wrapper tags, flags injection lines. Buffer-local `iar--sanitize-exec-output` flag (nil by default). Requires subr-x. Provide symbol: `iar-output-sanitizer`. |
| `security/iar-file-guard.el` | Protected path enforcement. Two tiers: always-protected (agent prompts, base context, history logs, LOGS.md) and conditionally-protected (.el files, Containerfile, iar.sh, git hooks). Protected paths defined as defcustoms in configs/file-guard.el with (regex reason append-allowed) triples. `iar--guard-check-write`, `iar--guard-check-replace`, `iar--guard-check-append`. `iar-guard-allow-self-modification` defcustom intentionally lacks `:safe` property. Self-modification mode relaxes tier 2 but never tier 1. Requires cl-lib, subr-x. Provide symbol: `iar-file-guard`. |
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
| `session/iar-quit.el` | Session-aware shutdown (`iar-quit`). Bound to C-x C-c. With prefix ARG, skips summarization. Normal quit: checks `gptel-mode`, calls `iar-summarize-session` (non-interactive), then quits via `save-buffers-kill-emacs` after 0.5s delay. `condition-case` error handling -- warns on summarization failure but quits anyway. Requires subr-x. Provide symbol: `iar-quit`. |

## Keybindings

| Key | Command | Description |
|-----|---------|-------------|
| C-c a | `iar-load-agent` | Load agent personality |
| C-c k | `iar-load-knowledge` | Load knowledge folder/file |
| C-c p | `iar-prompt-info` | Show prompt size info |
| C-c v | `iar-view-prompt` | View full system prompt (read-only) |
| C-c b | `iar-buffer-info` | Show conversation buffer size (chars + approx tokens) |
| C-c m | `iar-summarize-session` | Summarize conversation to memory |
| C-x C-c | `iar-quit` | Session-aware quit |

All keybindings are defcustoms in `configs/keybindings.el` and can be changed without editing module code.

## Agent Profile Structure

Each agent lives in `prompts/agents/<name>/` (bind-mounted to `/root/.emacs.d/agents.d/agents/`):

```
prompts/agents/<name>/
  prompt.org      -- Agent personality (loaded by C-c a, #+INCLUDE expanded)
```

The `prompt.org` file includes shared context via:
```
#+INCLUDE: "../../base_context.org"
```

Personal files are NOT in the agent directory. They live in the personalization mount:

```
tasks/<name>/     -- Task files (one .md per task, file exists = work to do)
audit/<name>/     -- HISTORY.log, LOGS.md, SUMMARY.md, MEMORIES.md
```

Memory files (LOGS.md, SUMMARY.md, MEMORIES.md) are injected into the agent prompt programmatically by `iar-agent-loader.el` from `audit/<name>/` (not via #+INCLUDE). The agent sees its memory as part of its system prompt without any #+INCLUDE lines for personal files. Task files are read on demand via the `read_tasks` tool from `tasks/<name>/`.

## Shared Context

`prompts/base_context.org` contains shared context inherited by all agents (bind-mounted to `agents.d/base_context.org`). Individual agent prompts include it via:
```
#+INCLUDE: "../../base_context.org"
```

## Prompt Templates

`prompts/common/` contains prompt templates used by the system (not user-facing, bind-mounted to `agents.d/common/`):
- `delegated_task.org` -- Template for delegate task prompts
- `delegate_continue.org` -- Re-prompt for delegates that narrate instead of acting
- `agent_cycle.org` -- Shared cycle prompt for all autonomous agents
- `agent_cycle_continue.org` -- Shared cycle continuation prompt
- `continuous_agent.org` -- Generic protocol for continuous agents (read memories, read history, read state, do work, log, update state, LOOP_COMPLETE)
- `gardener_cycle.org` -- Gardener-specific cycle wake-up message
- `librarian_cycle.org` -- Librarian-specific cycle wake-up message
- `matrix_turn.org` -- Matrix watcher turn prompt
- `memory_summarizer.org` -- Memory summarization prompt
- `loop_soft_block.org` -- Loop guard soft block message
- `loop_hard_stop.org` -- Loop guard hard stop message
- `unknown_tool.org` -- Unknown tool error message
- `mount_info.org` -- Extra mount info template

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

24 test files, 488 tests total. Run with:
```bash
emacs --batch -l /root/.emacs.d/test/run-tests.el
```

Test files live in `test/` and follow the naming convention `test-<module>.el`. The test runner (`run-tests.el`) loads the gptel fork on load-path (via `EMACBOROS_GPTEL_FORK_PATH` env var) to ensure tests use the fork with our fixes instead of stale ELPA `.elc` files.