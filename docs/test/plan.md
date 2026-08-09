# E2E Test Plan

Execute each test in order. Use /workspace as the working directory for file I/O tests to avoid polluting real data. Report PASS, FAIL, or SKIP for each.

## Filesystem Tools

### T01: read_file
- Call: read_file on /etc/hostname
- Pass: Returns a non-empty string containing the hostname

### T02: write_file
- Call: write_file to /workspace/test-t02.txt with content "hello from test agent"
- Pass: Returns "Success"

### T03: append_file
- Call: append_file to /workspace/test-t02.txt with content "appended line"
- Pass: Returns "Success"

### T04: read_file (verify append)
- Call: read_file on /workspace/test-t02.txt
- Pass: Content contains both "hello from test agent" and "appended line"

### T05: list_directory
- Call: list_directory on /workspace
- Pass: Returns a listing that includes test-t02.txt

## Code Execution

### T06: execute_code_local (basic)
- Call: execute_code_local with command "echo hello-e2e"
- Pass: Output contains "hello-e2e"

### T07: execute_code_local (multiline)
- Call: execute_code_local with command "echo line1; echo line2"
- Pass: Output contains both "line1" and "line2"

### T08: execute_code_local (exit code)
- Call: execute_code_local with command "exit 42"
- Pass: Output contains "exit" and "42" (non-zero exit reported)

### T09: execute_code_local (stderr)
- Call: execute_code_local with command "echo err >&2"
- Pass: Output contains "err" (stderr is captured)

### T10: check_elisp
- Call: check_elisp on /root/.emacs.d/init.d/shared/iar-utils.el
- Pass: Returns "OK" or no issues found

## Container Execution (execute_code_remote)

### T11: pentest container (nmap)
- Call: execute_code_remote with target="pentest", command="nmap --version"
- Pass: Output contains "Nmap" version string
- Skip condition: IAR_CONTAINER_PENTEST env var not set (container not started)

### T12: pentest container (curl)
- Call: execute_code_remote with target="pentest", command="curl -s http://example.com | head -5"
- Pass: Output contains HTML or "Example Domain"
- Skip condition: IAR_CONTAINER_PENTEST env var not set

### T13: life-org container (hledger)
- Call: execute_code_remote with target="life-org", command="hledger --version"
- Pass: Output contains hledger version string
- Skip condition: IAR_CONTAINER_LIFE-ORG env var not set

### T14: concepts container (basic)
- Call: execute_code_remote with target="concepts", command="echo hello-from-concepts"
- Pass: Output contains "hello-from-concepts"
- Skip condition: IAR_CONTAINER_CONCEPTS env var not set

## Task Management

### T15: create_task
- Call: create_task with path="e2e-test/temp-task", description="E2E test task"
- Pass: Returns "Success"

### T16: read_task (tree)
- Call: read_task with no arguments
- Pass: Returns a tree that includes "temp-task" or "e2e-test"

### T17: read_task (specific)
- Call: read_task with path="e2e-test/temp-task"
- Pass: Returns the task description "E2E test task"

### T18: write_subtask
- Call: write_subtask with path="e2e-test/temp-task/test-subtask", content="* Test subtask"
- Pass: Returns "Success"

### T19: remove_task (subtask)
- Call: remove_task with path="e2e-test/temp-task/test-subtask"
- Pass: Returns "Success" or "marked done"

### T20: remove_task (task)
- Call: remove_task with path="e2e-test/temp-task"
- Pass: Returns "Success" or "marked done"

## Knowledge Base

### T21: read_knowledge (tree)
- Call: read_knowledge with no arguments
- Pass: Returns a tree listing knowledge bases (at least "linux" or "concepts")

### T22: read_knowledge (specific)
- Call: read_knowledge with path="linux"
- Pass: Returns content (description or listing)

## Agent Management

### T23: reload_agent
- Call: reload_agent with no arguments
- Pass: Returns "Success"

### T24: delegate
- Call: delegate with agent="implementer", task="Echo the word 'delegation-test' in your response", context="This is an E2E test"
- Pass: Returns a result string (any non-error response)
- Note: This spawns a real sub-agent. If the model is unreachable, SKIP.

## Git

### T25: git_commit
- Call: First create a file in /workspace/test-git/ with execute_code_local: "mkdir -p /workspace/test-git && cd /workspace/test-git && git init && echo test > README.md && git add -A"
- Then call: git_commit with repo_path="/workspace/test-git", message="E2E test commit"
- Pass: Returns "Success"

## Security Features

### T26: file_guard (protected file)
- Call: write_file to /root/.emacs.d/init.d/shared/iar-utils.el with content "hacked"
- Pass: Returns an error mentioning "protected", "guard", or "file guard"

### T27: file_guard (HISTORY.log overwrite)
- Call: write_file to your audit HISTORY.log with content "fake log"
- Pass: Returns an error mentioning "protected", "guard", or "append"

## Notifications

### T28: send_telegram
- Call: send_telegram with message="E2E test notification"
- Pass: Returns "Success"
- Skip condition: AGENT_TELEGRAM_BOT_TOKEN or AGENT_TELEGRAM_CHAT_ID env vars not set

## Audit

### T29: audit_log verification
- Call: execute_code_local with command "tail -5 /root/personalization/audit/audit.log"
- Pass: Output contains recent audit entries (file operations from this test run)

## Roadmap

### T30: read_roadmap
- Call: read_roadmap with no arguments
- Pass: Returns roadmap content or "No roadmap found" message

## MCP (if available)

### T31: MCP tools registered
- Check: Use execute_code_local to inspect if MCP tools are in gptel-tools (this is implicit -- if MCP is configured and auto-start is on, tools should be available)
- Pass: MCP tools appear in the tool list OR no MCP servers configured (SKIP if not configured)
- Skip condition: No #+MCP in project file or mcp package not loaded