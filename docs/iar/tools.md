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
| `read_task` | `path` (optional) | Read tasks from the current agent's tasks directory (`tasks/<project>/`). With no argument, returns a tree-like hierarchy of all tasks with descriptions. With a path argument (slash-separated), returns detail: directory listing, subtask contents, or single file content. |
| `create_task` | `path`, `description` (required) | Create a new task directory with a description.org file. Path is slash-separated. Description limited to `iar-task-description-limit` characters (default 500, from configs/tasks.el). |
| `write_subtask` | `path`, `content` (required) | Write a subtask .org file inside a task directory. Path is slash-separated where the last segment becomes the filename. |
| `remove_task` | `path` (required) | Remove a task or subtask. If the path is a directory, removes the entire directory tree (task done). If a file, removes just that file (subtask done). |
| `read_history` | `agent_name` (optional) | Read per-agent HISTORY.log from `audit/<project>/<name>/` or unified merged history from all agents. If agent_name provided: validates name, reads single log. If omitted: scans all agent dirs, parses timestamp lines, merges sorted by timestamp into unified timeline. |
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
| `reload_agent` | `agent_name` (optional) | Re-read personality .org and update system prompt in current buffer. Re-assembles via `iar--setup-assembled-buffer` with current archetype + project. Use after modifying personality files. |

### Delegation (tools/agent/)

| Tool | Args | Description |
|------|------|-------------|
| `delegate` | `agent` (required), `task` (required), `context` (optional), `timeout` (optional) | Spawn sub-agent with specific profile. Async, returns final response as tool result. Default timeout 600s. Resolves archetype and project from personality name, assembles prompt via `iar--assemble-prompt`, applies tool gating from project `#+TOOLS`. Result extraction via `=== DELEGATION RESULT ===` marker -- only the sub-agent's final summary is returned, not raw tool output. |

**STATUS:** Matrix server (daftpunk) was killed. These tools are dead unless Matrix is redeployed.
### Matrix Communication (tools/matrix/)

| Tool | Args | Description |
|------|------|-------------|
| `list_matrix_chats` | none | List all Matrix rooms the current agent has joined. Returns room IDs. |
| `read_matrix_chat` | `room_id` (required), `limit` (optional) | Read recent messages from a Matrix room. Returns formatted transcript with timestamps and sender names. |
| `send_matrix_message` | `room_id` (required), `message` (required) | Send a text message to a Matrix room. Async tool. Credentials: per-agent Matrix token from env var. |

### Notification (tools/notify/)

| Tool | Args | Description |
|------|------|-------------|
| `send_telegram` | `message` (required) | Send Telegram notification via Bot API. Async tool. Message prefixed with `[AgentName]` via `iar--get-agent-name`. Credentials from `AGENT_TELEGRAM_BOT_TOKEN` and `AGENT_TELEGRAM_CHAT_ID` env vars. Uses curl POST with 10s timeout. Audit-logged. |

### Git (tools/git/)

| Tool | Args | Description |
|------|------|-------------|
| `git_commit` | `repo_path`, `message` (required) | Stage all changes (`git add -A`) and commit in a git repository. Sync tool using `call-process` directly (no shell, no injection surface). Validates repo directory and `.git` presence. Git identity auto-configured from configs/git.el. Audit-logged. Returns `Success:` or `Error:` string. |

## Tool Gating

Tool availability is controlled per-project via `#+TOOLS` metadata in project files (`personalization/projects/<name>.org`). The assembly engine (`iar-prompt-assembly.el`) filters the global `gptel-tools` list to only those listed in the project's `#+TOOLS` line.

Example from `personalization/projects/darwin.org`:
```
#+TOOLS: list_directory read_file write_file append_file execute_code_local check_elisp read_task create_task write_subtask remove_task read_history git_commit read_roadmap write_roadmap
```

This gives darwin filesystem, code execution, task management, git, and roadmap tools -- but no delegate, no telegram, no reload, no knowledge, no matrix tools.

If `#+TOOLS` is absent from a project file, all registered tools are available (backward compat).

See `tool_gating.md` for the planned `--enable-code-exec`, `--enable-elisp`, and `--danger-zone` flags that will add container-level tool gating on top of the project-level gating.

## File Guard Protection

The file guard (`iar-file-guard.el`) intercepts `write_file` and `append_file` calls. Protected paths are defined as defcustoms in `configs/file-guard.el` as (regex reason append-allowed) triples.

### Always Protected (cannot be bypassed)
- Archetype files: `agents.d/archetypes/<name>.org` (append not allowed)
- Personality files: `agents.d/personalities/<name>.org` (append not allowed)
- Cycle files: `agents.d/cycles/<name>.org` (append not allowed)
- Shared context: `agents.d/base_context.org` (append not allowed)
- Common prompt templates: `agents.d/common/*.org` (append not allowed)
- HISTORY.log files (append only -- overwrite and replace blocked)
- LOGS.md files (append only -- overwrite and replace blocked)
- STATE.org files (append only -- overwrite and replace blocked. Use write_file for updates -- STATE.org is not append-only in the file guard because it needs full rewrites each cycle.)
- ROADMAP.org files (append only -- overwrite and replace blocked. Use write_roadmap tool to update.)

### Conditionally Protected (relaxed in self-modification mode)
- `init.el` (append not allowed)
- `init.d/**/*.el` (append not allowed)
- `Containerfile` (append not allowed)
- `iar.sh` (append not allowed)
- `containers/` directory (append not allowed)
- `.git/hooks/` directory (append not allowed)

Self-modification mode is controlled by the `EMACBOROS_SELF_MODIFICATION` environment variable (set via `--self-modification` flag on `iar.sh`). When unset, all guards are active. When set to `1`, tier 2 guards are relaxed but tier 1 (archetype/personality/cycle files, base context, history logs, LOGS.md, STATE.org) remains enforced.

## Audit Logging

All file operations (`write_file`, `append_file`) and command executions (`execute_code_local`) are logged to `audit/audit.log` via `iar--audit-log`. The log rotates at `iar-audit-log-max-size` (default 10MB, from configs/debug.el), keeping one generation (`audit.log.1`).

## Loop Guard

The loop guard (`iar-loop-guard.el`) detects repetitive tool calls via `iar-pre-tool-call-functions` (i.ar's own hook, bridged to gptel via the tool call layer):
- **Soft threshold** (default 3, from configs/loop-guard.el): After N identical consecutive tool calls, the call is blocked and a correction message is sent to the LLM.
- **Hard threshold** (default 6): After N identical consecutive tool calls, the entire request is stopped.
- History ring size: 20 entries.

## Debug Instrumentation

- **Status mode** (`iar-status-mode.el`): Custom mode-line display showing agent name, prompt size, last and cumulative token counts. All token data comes from the tool call layer's accumulators. No gptel internals.

The tool call layer (`iar-tool-call.el`) provides the underlying token usage tracking and audit logging.