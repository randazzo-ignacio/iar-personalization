# i.ar Tools Reference

## Tool Categories

### Filesystem Tools (tools/filesystem/)

| Tool | Args | Description |
|------|------|-------------|
| `read_file` | `filepath` (required) | Read file contents into context. Size-limited by `iar-fs-read-max-size` (default 1MB, from configs/debug.el) using character count. Truncation notice appended when limit exceeded. Error handling via `condition-case`, returns `Error:` string on failure. |
| `write_file` | `filepath`, `content` (required) | Create or overwrite a file. Core function `iar--fs-write-file`. File-guard enforced via `iar--guard-check-write`. Buffer-aware: if file is open in a buffer, checks `buffer-read-only` and `buffer-modified-p`, then erases/inserts/saves with `iar--with-suppressed-save-hooks`. If not in a buffer, uses atomic write (temp file + rename). Creates parent directories. Audit-logged via `iar--audit-log-write`. Returns `Success:` or `Error:` string. |
| `append_file` | `filepath`, `content` (required) | Append to end of file. Auto-prepends newline if needed. Used for HISTORY.log and LOGS.md. File-guard enforced via `iar--guard-check-append`. Audit-logged via `iar--audit-log-append`. |
| `list_directory` | `path` (required) | List directory contents. Returns newline-separated file names including hidden files. Directory entries suffixed with `/`. Results sorted alphabetically. |

### Code Execution (tools/code/)

| Tool | Args | Description |
|------|------|-------------|
| `execute_code_local` | `command` (required) | Run bash command in the container. Uses `:connection-type 'pipe` (no pty allocation). Full toolset available: bash, dig, nmap, openssl, python3, jq, whois, traceroute, tcpdump, rg, git, curl, find, gawk, sed, grep, gcc, make, tar, gzip, unzip. Audit-logged via `iar--audit-log-exec`. |

### Code Quality (tools/code/)

| Tool | Args | Description |
|------|------|-------------|
| `check_elisp` | `filepath` (required) | Check .el file for syntax errors, unbalanced parens, and byte-compilation warnings. Two-phase: 1) `check-parens` in temp buffer, 2) `byte-compile-file` with temp .elc (cleaned up). Validates .el extension and file existence. Returns "ISSUES FOUND" or "OK" report. Does NOT modify the file. |

### Task Management (tools/tasks/)

| Tool | Args | Description |
|------|------|-------------|
| `read_task` | `path` (optional) | Read tasks from the current agent's tasks directory. With no argument, returns a tree-like hierarchy of all tasks with descriptions. With a path argument (slash-separated, e.g. `track/subtask`), returns detail: if the path is a directory with subdirectories, returns the description and a tree of subdirectory descriptions; if a directory without subdirectories, returns the description and all subtask file contents; if a file, returns that single file content. |
| `create_task` | `path`, `description` (required) | Create a new task directory with a description.org file. Path is slash-separated (e.g. `track/subtask`). Does NOT auto-create parent directories -- warns if parent task directory or description.org is missing. Description is limited to `iar-task-description-limit` characters (default 500). |
| `write_subtask` | `path`, `content` (required) | Write a subtask .org file inside a task directory. Path is slash-separated where the last segment becomes the filename (e.g. `track/subtask-name`). Warns if the parent task directory or description.org does not exist. |
| `remove_task` | `path` (required) | Remove a task or subtask. If the path is a directory, removes the entire directory tree (task done). If a file, removes just that file (subtask done). |
| `read_history` | `agent_name` (optional) | Read per-agent HISTORY.log from `audit/<name>/` or unified merged history from all agents. If agent_name provided: validates name, reads single `audit/<name>/HISTORY.log`. If omitted: scans all agent dirs, parses timestamp lines, merges sorted by timestamp into unified timeline. |
| `read_roadmap` | none | Read the ROADMAP.org file from the current agent's tasks directory. The roadmap defines task ordering, dependencies, and cycle guidelines for continuous agents. |
| `write_roadmap` | `content` (required) | Write or overwrite the ROADMAP.org file in the current agent's tasks directory. File-guard protected (append-only for write_file). Use this tool to update the roadmap. |


### Knowledge Base (tools/knowledge/)

| Tool | Args | Description |
|------|------|-------------|
| `read_knowledge` | `path` (optional) | Read from the concept knowledge base directory (`knowledge/`). With no argument, returns a tree of knowledge bases with descriptions. With a path argument (slash-separated), returns: if the path is a directory with subdirectories, the description and a listing of subdirectory and file names (names only); if a directory without subdirectories, the description and full contents of all files; if a file, that single file's content. Handles arbitrary file extensions (.tex, .rb, .c, .v, .spice, .org, .md). Custom path validation allows dots for file extensions. |

### Agent Management (tools/agent/)

| Tool | Args | Description |
|------|------|-------------|
| `reload_os` | none | Re-evaluate init.el. Rebuilds gptel-tools list. Use after modifying .el files. |
| `reload_agent` | `agent_name` (optional) | Re-read agent prompt.org and update system prompt in current buffer. Use after modifying .org profiles. |

### Delegation (tools/agent/)

| Tool | Args | Description |
|------|------|-------------|
| `delegate` | `agent` (required), `task` (required), `context` (optional), `timeout` (optional) | Spawn sub-agent with specific profile. Async, returns final response as tool result. Default timeout 600s. Result extraction via `=== DELEGATION RESULT ===` marker -- only the sub-agent's final summary is returned, not raw tool output. |

**STATUS:** Matrix server (daftpunk) was killed. These tools are dead unless Matrix is redeployed.
### Matrix Communication (tools/matrix/)

| Tool | Args | Description |
|------|------|-------------|
| `list_matrix_chats` | none | List all Matrix rooms the current agent has joined. Returns room IDs. |
| `read_matrix_chat` | `room_id` (required), `limit` (optional) | Read recent messages from a Matrix room. Returns formatted transcript with timestamps and sender names. |
| `send_matrix_message` | `room_id` (required), `message` (required) | Send a text message to a Matrix room. Async tool. Credentials: per-agent Matrix token from env var (e.g., `MIRROR_BOT_MATRIX_TOKEN`). |

### Memory (agent/)

| Tool | Args | Description |
|------|------|-------------|
| `iar-summarize-session` | none (interactive, C-c m) | Summarize conversation to LOGS.md/SUMMARY.md via LLM. |

### Notification (tools/notify/)

| Tool | Args | Description |
|------|------|-------------|
| `send_telegram` | `message` (required) | Send Telegram notification via Bot API. Async tool. Core function `iar--tool-telegram`. Message prefixed with `[AgentName]` via `iar--get-agent-name`. Credentials from `AGENT_TELEGRAM_BOT_TOKEN` and `AGENT_TELEGRAM_CHAT_ID` env vars. Uses curl POST with `-m 10` (10s curl timeout). Emacs-level 15s timeout via `run-with-timer`. Audit-logged via `iar--audit-log`. |

### Git (tools/git/)

| Tool | Args | Description |
|------|------|-------------|
| `git_commit` | `repo_path`, `message` (required) | Stage all changes (`git add -A`) and commit in a git repository. Sync tool using `call-process` directly (no shell, no injection surface). Validates repo directory and `.git` presence. Git identity auto-configured from configs/git.el, falls back to "i.ar Agent" / `<agent>@i.ar.local`. Checks for staged changes before committing. Audit-logged with repo path, truncated message, and exit code. Returns `Success:` or `Error:` string. |

## File Guard Protection

The file guard (`iar-file-guard.el`) intercepts `write_file` and `append_file` calls. Protected paths are defined as defcustoms in `configs/file-guard.el` as (regex reason append-allowed) triples.

### Always Protected (cannot be bypassed)
- Agent prompt files: `agents.d/agents/<name>/prompt.org` (append not allowed)
- Shared context: `agents.d/base_context.org` (append not allowed)
- Common prompt templates: `agents.d/common/*.org` (append not allowed)
- HISTORY.log files (append only -- overwrite and replace blocked)
- LOGS.md files (append only -- overwrite and replace blocked)
- ROADMAP.org files (append only -- overwrite and replace blocked. Use write_roadmap tool to update.)

### Conditionally Protected (relaxed in self-modification mode)
- `init.el` (append not allowed)
- `init.d/**/*.el` (append not allowed)
- `Containerfile` (append not allowed)
- `iar.sh` (append not allowed)
- `containers/` directory (append not allowed)
- `.git/hooks/` directory (append not allowed)

Self-modification mode is controlled by the `EMACBOROS_SELF_MODIFICATION` environment variable (set via `--self-modification` flag on `iar.sh`). When unset, all guards are active. When set to `1`, tier 2 guards are relaxed but tier 1 (agent prompts, base context, history logs, LOGS.md) remains enforced.

## Audit Logging

All file operations (`write_file`, `append_file`) and command executions (`execute_code_local`) are logged to `audit/audit.log` via `iar--audit-log`. The log rotates at `iar-audit-log-max-size` (default 10MB, from configs/debug.el), keeping one generation (`audit.log.1`).

## Loop Guard

The loop guard (`iar-loop-guard.el`) detects repetitive tool calls via `iar-pre-tool-call-functions` (i.ar's own hook, bridged to gptel via the tool call layer):
- **Soft threshold** (default 3, from configs/loop-guard.el): After N identical consecutive tool calls, the call is blocked and a correction message is sent to the LLM.
- **Hard threshold** (default 6): After N identical consecutive tool calls, the entire request is stopped.
- History ring size: 20 entries.

## Debug Instrumentation

The old buffer-monitor, request-logger, and fsm-tracer modules have been removed. They are replaced by:

- **Status mode** (`iar-status-mode.el`): Custom mode-line display showing agent name, prompt size, last and cumulative token counts. All token data comes from the tool call layer's accumulators. No gptel internals.

The tool call layer (`iar-tool-call.el`) provides the underlying token usage tracking and audit logging that the old debug modules used to handle separately.