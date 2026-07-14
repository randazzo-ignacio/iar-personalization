# i.ar Emacs Modules

All Emacs Lisp modules live in `init.d/` and are organized into subdirectories by purpose. The auto-discovery scans `init.d/dynamic/` for new modules created by agents (e.g., darwin). When a dynamic module proves useful, it is promoted to the appropriate subdirectory and added to init.el's explicit load list.

## Naming Convention

- `iar--<name>`: internal functions and variables
- `iar--mygptel--<name>`: functions that hook into gptel internals (advice-add, gptel hooks, gptel-make-tool callbacks)
- `iar-<name>`: public functions and user-facing defcustoms
- `iar-tool--<name>`: tool module provide symbols (one tool per file)
- Module files: `iar-kebab-case.el` for system modules, `<tool_name>.el` for tool modules

## Module Inventory

### Metaconfig

| Module | Purpose |
|--------|---------|
| `metaconfig/parameters.el` | Central parameter configuration. All tunable parameters (delegate depth, agent cycle limits, loop guard thresholds, memory limits, file read limits, personal file injection line cap, audit log rotation, base paths, keybindings, delimiters, file guard protected paths). Loaded before any init.d module. |
| `metaconfig/gptel.el` | Ollama backend configuration. Defines models, host, request params. |

### Shared Utilities

| Module | Purpose |
|--------|---------|
| `init.d/shared/iar-utils.el` | Consolidated utilities: `iar--get-agent-name` (agent name resolution with fallback), `iar--approx-token-count` (character-to-token estimation), `iar--audit-log-path` (audit log path resolution), `iar--with-suppressed-save-hooks` (macro for atomic writes). |
| `init.d/shared/iar-agent-utils.el` | Agent validation and path resolution: `iar--valid-name-p` (agent/task name validation), `iar--resolve-agent-dir` (path resolution with traversal defense), `iar--resolve-task-path`. |

### Core Infrastructure

| Module | Purpose |
|--------|---------|
| `init.el` | Entry point. Loads all modules explicitly, then auto-discovers the rest. Sets `load-prefer-newer t` to avoid stale byte-compiled code. Sets self-modification mode from `EMACBOROS_SELF_MODIFICATION` env var before file guard loads. |
| `core/iar-locale.el` | UTF-8 locale configuration. Must load first. In a containerized environment, locale may not be set via environment variables, so UTF-8 is enforced at the Emacs level. Calls `set-terminal-coding-system`, `set-keyboard-coding-system`, `set-selection-coding-system` (all to `'utf-8`), `prefer-coding-system` (`'utf-8`), and `set-language-environment` (`"UTF-8"`). Key insight: `char-displayable-p` returns nil for non-ASCII when `terminal-coding-system` is nil, causing Emacs to render escape sequences instead of glyphs. Setting terminal coding system is the critical fix. Provide symbol: `iar-locale`. |
| `core/iar-package-setup.el` | Package manager setup (MELPA, use-package). |
| `core/iar-ui-cleanup.el` | UI cleanup. Disables `menu-bar-mode` and `tool-bar-mode` (both fboundp-guarded for batch/minimal Emacs builds). Sets `inhibit-startup-message` to `t`. Does NOT disable `scroll-bar-mode` (not present in terminal Emacs). Provide symbol: `iar-ui-cleanup`. |
| `core/iar-evil-mode.el` | Evil mode (vim keybindings in Emacs). Sets `evil-want-integration` to `t` and `evil-want-keybinding` to `nil` (both declared as defvars before use to silence byte-compiler). Loads `evil` via `use-package` with `:ensure t` and `:config (evil-mode 1)`. Loads `evil-collection` via `use-package` with `:after evil`, `:ensure t`, and `:config (evil-collection-init)`. Provide symbol: `iar-evil-mode`. |
| `core/iar-gptel-setup.el` | Loads gptel package and applies metaconfig/gptel.el settings. Declares defvars `iar-gptel-backend`, `iar-gptel-default-model`, `iar-fork-path` (from metaconfig). Fork override: if `iar-fork-path` is a valid directory, prepends it to `load-path` so the fork takes precedence over the ELPA-installed package (used when a fix is merged upstream but not yet shipped in ELPA). Loads gptel via `use-package` with `:ensure t` and `:config` that calls `(load-file metaconfig/gptel.el)` then `setq-default` for `gptel-backend` and `gptel-model`. Provide symbol: `iar-gptel-setup`. |

### Agent System

| Module | Purpose |
|--------|---------|
| `agent/iar-agent-loader.el` | **C-c a** -- Interactive agent profile loader (`iar-load-agent`). Discovers `agents.d/agents/<name>/prompt.org`, expands `#+INCLUDE` directives via `org-export-expand-include-keyword` (requires `ox`), injects personal files (LOGS.md, SUMMARY.md, MEMORIES.md) from `audit/<name>/` programmatically (truncated to last N lines via `iar-personal-file-max-lines`). Darwin's MEMORIES.md replaces LOGS.md + SUMMARY.md when MEMORIES.md has content but LOGS/SUMMARY don't. Sets `gptel-system-prompt` (buffer-local). Integrates with `iar-mount-awareness.el` -- appends `iar--extra-mounts-prompt-string` to profile if available. Tracks agent name and file via buffer-local + global `iar--current-agent-name` and `iar--current-agent-file` (dual set so debug modules in process buffers can resolve agent name). Resets knowledge state (`iar--knowledge-base-prompt`, `iar--knowledge-loaded-labels`, `iar--knowledge-blocks`) on agent switch. Path traversal defense via `file-truename` check in `iar--load-agent-profile`. Reports prompt size on load. Owns `iar--load-agent-profile` (used by delegate, reload, agent_cycle). Keybinding via `iar-key-load-agent` defvar (parameters.el), bound via `keymap-set` on `gptel-mode-map` after gptel loads. Requires cl-lib, iar-agent-utils. Provide symbol: `iar-agent-loader`. |
| `agent/iar-knowledge-loader.el` | **C-c k** -- Interactive knowledge folder loader. Reads all `.md`/`.org` files from a `knowledge/<folder>/` directory, appends to system prompt with delimiters. Supports multiple knowledge bases loaded simultaneously. Idempotent (same knowledge reload is no-op). **C-c p** -- Prompt size info (chars + approximate tokens). Also provides `iar--load-knowledge-dir` for non-interactive use (used by agent_cycle.el to load knowledge in batch mode). |
| `agent/iar-delegate-tool.el` | Async multi-agent delegation. Spawns sub-agent buffers with timeout handling, max depth limiting, unknown tool blocking, text-only turn re-prompting. Sub-agent output is returned as tool result (no live streaming into parent buffer). Result extraction via `=== DELEGATION RESULT ===` marker. |
| `agent/iar-prompt-loader.el` | Loads prompt templates from `agents.d/common/*.org`. Single function `iar--load-prompt` (name) -- constructs path via `iar-prompts-path` defvar (from parameters.el) relative to `user-emacs-directory`, appends `.org` extension. Reads file content into temp buffer, trims trailing whitespace via `string-trim-right`. Signals `error` if file not found. Templates may contain format specifiers (`%s`, `%d`) applied by calling code via `format` at runtime. Used by delegate_tool, agent_cycle, loop_guard, memory_tools. Requires subr-x. Provide symbol: `iar-prompt-loader`. |
| `agent/iar-reload-tools.el` | **reload_os** tool: re-evaluates init.el, rebuilds gptel-tools. **reload_agent** tool: re-reads current agent's prompt.org. |
| `agent/iar-memory-tools.el` | **C-c m** -- Memory summarization. Sends conversation to LLM for summarization, stores in LOGS.md/SUMMARY.md. |
| `agent/iar-agent-cycle.el` | Autonomous agent cycle runner (`iar-run-cycle`). Any orchestrator agent can run autonomously in a loop: one change per cycle, testing, logging, sleeping. Has its own cycle buffer, timeout, max turns, continue prompting. Loads shared `agent_cycle.org` prompt. Supports `:agent`, `:knowledge`, `:self-modification`, `:timeout`, `:prompt` parameters. Includes per-agent cycle prompt loading (`<agent>_cycle.org` fallback to `agent_cycle.org`), cycle logging to `audit/<agent>/cycle.log`, self-modification default nil. Token usage tracking via `iar--cycle-token-summary` (integrates with `iar-request-logger.el` -- resets accumulators at cycle start, includes token counts in all result messages). Telegram notification on cycle end via `kill-emacs-hook` (`iar--cycle-notify-on-exit`). Exit codes: 0 (normal), 1 (timeout), 2 (LOOP_COMPLETE -- task done). `iar-darwin-run-cycle` backward compat alias. Requires gptel, cl-lib, subr-x, json. |

### Filesystem and Code Tools (one tool per file)

| Module | Tool | Purpose |
|--------|------|---------|
| `tools/filesystem/list_directory.el` | `list_directory` | List directory contents. Core function `iar--mygptel--fs-list-directory` (path). Expands path via `expand-file-name`. Returns newline-separated file names including hidden files (dotfiles), excludes `.` and `..` entries. Directory entries suffixed with `/` to distinguish from files. Results sorted alphabetically via `string-lessp`. Error handling via `condition-case`, returns `Error:` string on failure. Requires gptel, cl-lib. Provide symbol: `iar-tool--list-directory`. |
| `tools/filesystem/read_file.el` | `read_file` | Read file contents into context. Core function `iar--mygptel--fs-read-file` (filepath). Expands path via `expand-file-name`. Size-limited by `iar-fs-read-max-size` (default 1MB) -- uses character count (not byte count) because `insert-file-contents` decodes the file and token consumption correlates with characters. When limit exceeded, truncates and appends `[... file truncated at N characters ...]` notice. Error handling via `condition-case`, returns `Error:` string on failure. Requires gptel. Provide symbol: `iar-tool--read-file`. |
| `tools/filesystem/write_file.el` | `write_file` | Create or overwrite a file. Core function `iar--mygptel--fs-write-file` (filepath, content). Expands path via `expand-file-name`. File-guard enforced via `iar--guard-check-write`. Buffer-aware: if file is open in a buffer, checks `buffer-read-only` and `buffer-modified-p` (returns error if either), then erases buffer, inserts content, and saves with `iar--with-suppressed-save-hooks`. If file is NOT in a buffer, uses atomic write (temp file via `make-temp-file` + `rename-file`) to avoid stale buffer overwrites. Creates parent directories via `make-directory`. Audit-logged via `my-gptel--audit-log-write`. Error handling via `condition-case`, returns `Success:` or `Error:` string. Requires gptel, iar-file-guard, iar-audit-log, iar-utils. Provide symbol: `iar-tool--write-file`. |
| `tools/filesystem/append_file.el` | `append_file` | Append text to end of file. Auto-prepends newline if file doesn't end with one. File-guard enforced via `iar--guard-check-append`. If file is open in a buffer, appends to buffer and saves (with read-only and unsaved-modification checks). Otherwise appends directly to disk via `write-region`. Creates parent directories if needed. Creates file if it doesn't exist. Uses `iar--with-suppressed-save-hooks` for atomic saves. Audit-logged via `my-gptel--audit-log-append`. Returns `Success:` or `Error:` string. Requires gptel, iar-file-guard, iar-audit-log, iar-utils. Provide symbol: `iar-tool--append-file`. |
| `tools/filesystem/replace_in_file.el` | `replace_in_file` | Surgical text replacement. Core function `iar--mygptel--fs-replace` (path, search-text, replace-text). Expands path via `expand-file-name`. File-guard enforced via `iar--guard-check-replace`. Buffer-aware: if file is open in a buffer, checks `buffer-read-only` and `buffer-modified-p` (returns error if either), then performs in-buffer replacement with `save-buffer` (using `iar--with-suppressed-save-hooks`). If file is NOT in a buffer, uses atomic write (temp file + rename) to avoid stale buffer overwrites. Exact text matching via `search-forward` (whitespace significant). Fails if search_text not found (returns `Error:` string, no silent no-ops). Audit-logged via `my-gptel--audit-log-replace`. Error handling via `condition-case`, returns `Error:` string on failure. Requires gptel, iar-file-guard, iar-audit-log, iar-utils. Provide symbol: `iar-tool--replace-in-file`. |
| `tools/code/execute_code_local.el` | `execute_code_local` | Async bash/shell command execution in the container. Async tool (callback pattern per gptel `:async` convention) -- calls callback with result when process completes, keeping Emacs responsive. Core function `iar--mygptel--async-shell-command` (callback, command, &optional timeout). Default timeout 3600s (kills process on hang via `run-with-timer`). Uses `:connection-type 'pipe` (no pty allocation -- programs detect non-interactive mode via isatty(), skip pagers/color/interactive prompts). Output sanitization: when `my-gptel--sanitize-exec-output` is non-nil (CTF/external ops), output passed through `my-gptel--sanitize-external-output`. Flag captured at call time (not in sentinel) because process sentinels run in unpredictable buffer context. Audit logging via `my-gptel--audit-log-exec` (exit code 0 on success, non-zero on error, -1 on timeout). Error handling via `condition-case` in tool lambda. Requires gptel, iar-output-sanitizer, iar-audit-log. Provide symbol: `iar-tool--execute-code-local`. |
| `tools/code/check_elisp.el` | `check_elisp` | Byte-compile .el files and report errors/warnings. Does NOT modify the file. |
| `tools/tasks/read_tasks.el` | `read_tasks` | Read all task files (.md) from current agent's tasks directory. Core function `iar--mygptel--tool-read-tasks` (no args). Resolves tasks dir via `iar--resolve-agent-tasks-dir`. Filters `.md` files via `directory-files`. Each task formatted as `=== <basename> ===` (extension stripped) with `string-trim`-ed content, joined by `\n\n`. Returns "No tasks found in <dir>" if empty. Error handling via `condition-case`, returns `Error reading tasks:` string on failure. Requires gptel, cl-lib, subr-x, iar-agent-utils. Provide symbol: `iar-tool--read-tasks`. |
| `tools/tasks/write_task.el` | `write_task` | Create a new task file in current agent's tasks directory. Core function `iar--mygptel--tool-write-task` (name, content). Resolves path via `iar--resolve-task-path` (from `iar-agent-utils`). Checks file existence -- errors if task already exists (refuses to overwrite, use remove_task first). Creates parent directory if needed via `make-directory` with parents flag. Writes content via `with-temp-file` + `insert`. Returns "Task '<name>' created at <full-path>" on success. Error handling via `condition-case`, returns "Error creating task: <detail>" on failure. Requires gptel, subr-x, iar-agent-utils. Provide symbol: `iar-tool--write-task`. |
| `tools/tasks/remove_task.el` | `remove_task` | Delete a task file from current agent's tasks directory. Core function `iar--mygptel--tool-remove-task` (name). Resolves path via `iar--resolve-task-path` (from `iar-agent-utils`). Checks file existence (errors if task not found). Deletes via `delete-file`. Returns "Task '<name>' removed (marked done)." on success. Error handling via `condition-case`, returns "Error removing task: <detail>" on failure. Requires gptel, subr-x, iar-agent-utils. Provide symbol: `iar-tool--remove-task`. |
| `tools/tasks/read_history.el` | `read_history` | Read per-agent or unified HISTORY.log. Core function `iar--mygptel--tool-read-history` (optional `agent-name`). If agent-name provided: validates via `iar--validate-agent-name`, reads `audit/<name>/HISTORY.log`. If omitted: scans all agent dirs in audit base, parses timestamp lines (regex `^\[YYYY-MM-DD HH:MM:SS\]`), merges sorted by timestamp, prefixes with `=== UNIFIED HISTORY LOG (merged by timestamp) ===`. Error handling via `condition-case`. Declares `iar-audit-path` defvar (from parameters.el). Requires gptel, cl-lib, subr-x, iar-agent-utils. Provide symbol: `iar-tool--read-history`. |
| `tools/notify/telegram.el` | `send_telegram` | Send Telegram notification via Bot API. Async tool (callback pattern). Message prefixed with `[AgentName]`. Credentials from `AGENT_TELEGRAM_BOT_TOKEN` and `AGENT_TELEGRAM_CHAT_ID` env vars. Uses curl POST with 15s timeout. Parses JSON response to verify `:ok` field. Audit-logged via `my-gptel--audit-log`. Requires gptel, iar-utils, iar-audit-log. Provide symbol: `iar-tool--telegram`. |
| `tools/git/git_commit.el` | `git_commit` | Stage all changes and commit in a git repository. Sync tool (local git operations are fast). Core function `iar--mygptel--tool-git-commit` (repo_path, message). Uses `call-process` directly -- no shell, no injection surface. Validates: repo directory exists, `.git` directory present, message non-empty. Git identity auto-configured from `iar-git-author-name` and `iar-git-author-email` defvars (from parameters.el); falls back to "i.ar Agent" / `<agent>@i.ar.local` if unset. Stages via `git add -A`, checks for changes via `git diff --cached --quiet` (returns "No changes to commit" if clean), commits via `git commit -m`. Audit-logged via `my-gptel--audit-log` with repo path, truncated message (100 chars), and exit code. Returns `Success:` or `Error:` string. Requires gptel, iar-utils, iar-audit-log. Provide symbol: `iar-tool--git-commit`. |

### Security and Safety

| Module | Purpose |
|--------|---------|
| `security/iar-output-sanitizer.el` | Output filtering for tool results. Strips ANSI escape sequences, control characters, zero-width/bidi Unicode characters. Neutralizes fake system message wrapper tags. Flags lines resembling prompt injection. Wraps result in `[SANITIZED EXTERNAL DATA]` envelope. |
| `security/iar-file-guard.el` | Protected path enforcement. Two tiers: always-protected (agent prompts, base context, history logs, LOGS.md) and conditionally-protected (.el files, Containerfile, git hooks). Protected paths defined as defcustoms in parameters.el with (regex reason append-allowed) triples. Self-modification mode relaxes tier 2 but never tier 1. |
| `security/iar-audit-log.el` | Audit logging for all file operations and command executions. Log at `audit/audit.log`. Rotates at configurable size. |
| `security/iar-loop-guard.el` | Detects repetitive tool call loops. Soft threshold: blocks and warns. Hard threshold: stops the request entirely. |
| `security/iar-tool-guard.el` | Unknown tool blocking utility. `iar--block-unknown-tools` intercepts hallucinated tool names. Used by delegate_tool and agent_cycle. |

### Debug and Monitoring

| Module | Purpose |
|--------|---------|
| `debug/iar-buffer-monitor.el` | Buffer size monitor. Logs conversation buffer size (bytes, chars, approx tokens) to audit.log and per-agent `audit/<agent>/BUFFER.log` before each `gptel-send` via advice-add `:before`. Warning threshold at `iar-buffer-warn-size` (default 5MB chars). Optional hard cap at `iar-buffer-hard-cap` (default nil = disabled). |
| `debug/iar-request-logger.el` | Request logger + token usage tracker. Captures full JSON payloads sent to and received from the LLM. Outgoing: advice-add `:around` on `gptel-curl--get-config` (extracts JSON from curl config string). Incoming: advice-add `:before` on `gptel-curl--stream-cleanup` and `gptel-curl--sentinel` (snapshots raw process buffer, strips HTTP headers, truncates at 100KB). Writes to `audit/<agent>/REQUESTS.log`. Token usage tracking: parses `prompt_eval_count` and `eval_count` from Ollama streaming response final chunk via `iar--usage-parse-tokens`. Global accumulators (`iar--usage-requests`, `iar--usage-input-tokens`, `iar--usage-output-tokens`, `iar--usage-model`, `iar--usage-start-time`). `iar--usage-reset` (called at cycle start by agent_cycle.el), `iar--usage-totals` (returns plist with :requests, :input-tokens, :output-tokens, :total-tokens, :duration-secs, :model), `iar--usage-write-log` (writes summary line to `audit/<agent>/USAGE.log` on `kill-emacs-hook`). Self-install via `iar-request-log-setup` (autoloaded). `defcustom iar-request-log-enabled` (buffer-local support). Requires subr-x, json, iar-utils. Provide symbol: `iar-request-logger`. |
| `debug/iar-fsm-tracer.el` | FSM state tracer + tool call inspector. Logs every `gptel--fsm-transition` call via advice-add `:before`. Also logs `gptel--process-tool-call` and `gptel--handle-tool-use` via advice-add `:before` (observe only, never override). Writes to `audit/<agent>/FSM.log`. |

### Session Management

| Module | Purpose |
|--------|---------|
| `session/iar-quit.el` | Session-aware shutdown. Summarizes before killing Emacs. |

## Keybindings

| Key | Command | Description |
|-----|---------|-------------|
| C-c a | `iar--load-agent` | Load agent personality |
| C-c k | `iar--load-knowledge` | Load knowledge folder/file |
| C-c p | `iar--prompt-info` | Show prompt size info |
| C-c m | `iar--memory-summarize` | Summarize conversation to memory |
| C-x C-c | `iar-quit` | Session-aware quit |

All keybindings are defcustoms in parameters.el and can be changed without editing module code.

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
- `memory_summarizer.org` -- Memory summarization prompt
- `loop_soft_block.org` -- Loop guard soft block message
- `loop_hard_stop.org` -- Loop guard hard stop message
- `unknown_tool.org` -- Unknown tool error message

## Test Suite

19 test files, 541 tests total. Run with:
```bash
emacs --batch -l /root/.emacs.d/test/run-tests.el
```

Test files live in `test/` and follow the naming convention `test-<module>.el`. The test runner (`run-tests.el`) loads the gptel fork on load-path (via `EMACBOROS_GPTEL_FORK_PATH` env var) to ensure tests use the fork with our fixes instead of stale ELPA `.elc` files.