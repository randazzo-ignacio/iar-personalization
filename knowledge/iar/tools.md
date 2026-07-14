# i.ar Tools Reference

## Tool Categories

### Filesystem Tools (tools/filesystem/)

| Tool | Args | Description |
|------|------|-------------|
| `read_file` | `filepath` (required) | Read file contents into context. Size-limited by `iar-fs-read-max-size` (default 1MB) using character count (not byte count, since `insert-file-contents` decodes and token consumption correlates with characters). Truncation notice appended when limit exceeded. Error handling via `condition-case`, returns `Error:` string on failure. |
| `write_file` | `filepath`, `content` (required) | Create or overwrite a file. Core function `iar--mygptel--fs-write-file`. File-guard enforced via `iar--guard-check-write`. Buffer-aware: if file is open in a buffer, checks `buffer-read-only` and `buffer-modified-p`, then erases/inserts/saves with `iar--with-suppressed-save-hooks`. If not in a buffer, uses atomic write (temp file + rename). Creates parent directories. Audit-logged via `my-gptel--audit-log-write`. Returns `Success:` or `Error:` string. |
| `append_file` | `filepath`, `content` (required) | Append to end of file. Auto-prepends newline if needed. Used for HISTORY.log and LOGS.md. |
| `list_directory` | `path` (required) | List directory contents. |
| `replace_in_file` | `path`, `search_text`, `replace_text` (required) | Surgical text replacement. Fails if search_text not found (no silent no-ops). |

### Code Execution (tools/code/)

| Tool | Args | Description |
|------|------|-------------|
| `execute_code_local` | `command` (required) | Run bash command in the container. Uses `:connection-type 'pipe` (no pty allocation). Full toolset available: bash, dig, nmap, openssl, python3, jq, whois, traceroute, tcpdump, rg, git, curl, find, gawk, sed, grep, gcc, make, tar, gzip, unzip. |

### Code Quality (tools/code/)

| Tool | Args | Description |
|------|------|-------------|
| `check_elisp` | `filepath` (required) | Check .el file for syntax errors, unbalanced parens, and byte-compilation warnings. Two-phase: 1) `check-parens` in temp buffer, 2) `byte-compile-file` with temp .elc (cleaned up). Validates .el extension and file existence. Returns "ISSUES FOUND" or "OK" report. Does NOT modify the file. Requires gptel, bytecomp, cl-lib, subr-x. |

### Task Management (tools/tasks/)

| Tool | Args | Description |
|------|------|-------------|
| `read_tasks` | none | Read all task .md files from current agent's tasks directory (`tasks/<name>/`). Each file is a separate task. |
| `write_task` | `name`, `content` (required) | Create a new task file in `tasks/<name>/`. Core function `iar--mygptel--tool-write-task`. Resolves path via `iar--resolve-task-path`. Checks file existence -- errors if task already exists (refuses to overwrite, use remove_task first). Creates parent directory if needed. Writes via `with-temp-file`. Returns "Task '<name>' created at <full-path>" on success. Error handling via `condition-case`. Requires gptel, subr-x, iar-agent-utils. |
| `remove_task` | `name` (required) | Delete a task file from `tasks/<name>/`. Core function `iar--mygptel--tool-remove-task`. Resolves path via `iar--resolve-task-path`. Checks file existence (errors if not found). Deletes via `delete-file`. Returns "Task '<name>' removed (marked done)." on success. Error handling via `condition-case`. Requires gptel, subr-x, iar-agent-utils. |
| `read_history` | `agent_name` (optional) | Read per-agent HISTORY.log from `audit/<name>/` or unified merged history from all agents. Core function `iar--mygptel--tool-read-history`. If agent_name provided: validates name via `iar--validate-agent-name`, reads single `audit/<name>/HISTORY.log`. If omitted: scans all agent dirs, parses timestamp lines, merges sorted by timestamp into unified timeline. Error handling via `condition-case`. Requires gptel, cl-lib, subr-x, iar-agent-utils. |

### Agent Management (agent/)

| Tool | Args | Description |
|------|------|-------------|
| `reload_os` | none | Re-evaluate init.el. Rebuilds gptel-tools list. Use after modifying .el files. |
| `reload_agent` | `agent_name` (optional) | Re-read agent prompt.org and update system prompt in current buffer. Use after modifying .org profiles. |

### Delegation (agent/)

| Tool | Args | Description |
|------|------|-------------|
| `delegate` | `agent` (required), `task` (required), `context` (optional), `timeout` (optional) | Spawn sub-agent with specific profile. Async, returns final response as tool result. Default timeout 600s. Result extraction via `=== DELEGATION RESULT ===` marker -- only the sub-agent's final summary is returned, not raw tool output. |

### Memory (agent/)

| Tool | Args | Description |
|------|------|-------------|
| `iar-summarize-session` | none (interactive, C-c m) | Summarize conversation to LOGS.md/SUMMARY.md via LLM. |

### Notification (tools/notify/)

| Tool | Args | Description |
|------|------|-------------|
| `send_telegram` | `message` (required) | Send Telegram notification via Bot API. Async tool (callback pattern). Message auto-prefixed with `[AgentName]`. Credentials from `AGENT_TELEGRAM_BOT_TOKEN` and `AGENT_TELEGRAM_CHAT_ID` env vars. Uses curl POST with 15s timeout. Parses JSON response to verify success. Audit-logged. |

### Git (tools/git/)

| Tool | Args | Description |
|------|------|-------------|
| `git_commit` | `repo_path`, `message` (required) | Stage all changes (`git add -A`) and commit in a git repository. Sync tool using `call-process` directly (no shell, no injection surface). Validates repo directory and `.git` presence. Git identity auto-configured from `iar-git-author-name`/`iar-git-author-email` defvars (parameters.el), falls back to "i.ar Agent" / `<agent>@i.ar.local`. Checks for staged changes before committing (returns "No changes to commit" if clean). Audit-logged with repo path, truncated message (100 chars), and exit code. Returns `Success:` or `Error:` string. |

## File Guard Protection

The file guard (`iar-file-guard.el`) intercepts `write_file`, `replace_in_file`, and `append_file` calls. Protected paths are defined as defcustoms in `parameters.el` as (regex reason append-allowed) triples.

### Always Protected (cannot be bypassed)
- Agent prompt files: `agents.d/agents/<name>/prompt.org` (append not allowed)
- Shared context: `agents.d/base_context.org` (append not allowed)
- Common prompt templates: `agents.d/common/*.org` (append not allowed)
- HISTORY.log files (append only -- overwrite and replace blocked)
- LOGS.md files (append only -- overwrite and replace blocked)

### Conditionally Protected (relaxed in self-modification mode)
- `init.el` (append not allowed)
- `init.d/**/*.el` (append not allowed)
- `Containerfile` (append not allowed)
- `emacboros.sh` (append not allowed)
- `containers/` directory (append not allowed)
- `.git/hooks/` directory (append not allowed)

Self-modification mode is controlled by the `EMACBOROS_SELF_MODIFICATION` environment variable (set via `--self-modification` flag on `emacboros.sh`). When unset, all guards are active. When set to `1`, tier 2 guards are relaxed but tier 1 (agent prompts, base context, history logs, LOGS.md) remains enforced.

## Audit Logging

All file operations (`write_file`, `append_file`, `replace_in_file`) and command executions (`execute_code_local`) are logged to `audit/audit.log`. The log rotates at `iar-audit-log-max-size` (default 10MB), keeping one generation (`audit.log.1`).

## Loop Guard

The loop guard (`iar-loop-guard.el`) detects repetitive tool calls:
- **Soft threshold** (default 3): After N identical consecutive tool calls, the call is blocked and a correction message is sent to the LLM.
- **Hard threshold** (default 6): After N identical consecutive tool calls, the entire request is stopped.
- History ring size: 20 entries.

## Debug Instrumentation

Three debug modules provide always-on instrumentation via Emacs advice-add:

- **Buffer monitor**: Logs buffer size before each `gptel-send` to `audit/<agent>/BUFFER.log`. Warns at 5MB, optional hard cap.
- **Request logger**: Captures full JSON payloads sent to and received from the LLM to `audit/<agent>/REQUESTS.log`.
- **FSM tracer**: Logs every FSM state transition and tool call to `audit/<agent>/FSM.log`.

All debug modules use `:before` advice only (observe, never replace). The `:override` pattern was found to silently swallow errors and leave the FSM stuck -- it is banned.