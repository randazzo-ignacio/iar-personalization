# i.ar Future Ideas

These are sound ideas that are not active tasks. They are documented here to preserve the thinking and avoid losing the design work. When an idea becomes relevant, promote it to a task file.

## Trust Channel: Admin Instruction Encoding

Replace the output sanitizer's pattern-matching with a trust channel:

- System prompt tells the LLM that only text wrapped in `[ADMIN_INSTRUCTION_BEGIN]...[ADMIN_INSTRUCTION_END]` tags is instructions. Everything else is data.
- gptel infrastructure wraps user messages in these tags via `:around` advice on `gptel--request-data`.
- Sanitizer strips tags from all non-user-input sources (tool results, file reads, delegated output) via `:around` advice on `gptel--process-tool-call`.
- Control character stripping (ANSI, zero-width, bidi) stays -- it addresses a real attack vector the trust channel doesn't cover (hidden text from human review).

**Why it's a future idea:** The current sanitizer works as defense-in-depth. The trust channel is architecturally superior but touches gptel internals on every request. Build it when smaller models are confusing conversation history with instructions -- that's the concrete trigger.

**What was decided 2026-07-13:** The pragmatic simplification (delete pattern lists, keep control char stripping) was agreed upon as the immediate step. The trust channel is the long-term evolution.

## Containerless Architecture Migration

Eventually i.ar should work as a standalone Emacs package -- no containers, no bash scripts. Path to ELPA/MELPA distribution.

**What blocks it:**
1. File system security (Podman read-only rootfs -> file_guard as primary boundary)
2. Code execution isolation (container -> tool gating flags)
3. Bash scripts as integral components (iar.sh)
4. Personalization mount model

**Key principle for now:** Don't add bash dependencies that can't be replaced with elisp later. Don't architect for containerless yet -- just don't block it.

## MCP Integration (Burp Suite)

Integrate Burp Suite's MCP server (PortSwigger/mcp-server) into i.ar for pentesting capabilities.

**What exists:**
- `mcp.el` (583 stars, MELPA) -- Emacs MCP client built on `jsonrpc`. Supports stdio and SSE transports.
- `gptel-mcp.el` -- 80-line glue layer that registers MCP tools as gptel tools via `mcp-make-text-tool`.
- PortSwigger/mcp-server -- official Burp MCP server extension. Exposes SSE endpoint at `localhost:9876`.

**Integration approach:**
- `package-install mcp` + load gptel-mcp.el (or vendor it, it's 80 lines)
- Configure: `(setq mcp-hub-servers '(("burp" . (:url "http://localhost:9876/sse"))))`
- Start MCP hub during init, register tools via `gptel-mcp-register-tool`
- MCP tools appear alongside native i.ar tools in `gptel-tools`
- Agent calls Burp tool -> gptel dispatches -> mcp.el sends JSON-RPC to Burp -> result returns

**What unblocks:** Pentesting SaaS. Burp-powered security assessments with agent orchestration. Now the primary path -- Ruby migration is dead, Elisp is the permanent home.

**Status:** Not yet implemented. Ready when pentesting SaaS work begins. On the roadmap as Step 10 (i-ar-expansion/mcp-integration).

## CTF Network Restrictions

- Restrict outbound network access to whitelisted CTF challenge IPs/domains
- Log all outbound connections for post-CTF review
- Block exfiltration paths
- Add scope constraint, no-destructive-action, and stealth directives to CTF agents
- Consider a "frozen" mode where file modification tools are disabled
- Evaluate per-agent network policies

Relevant when actively doing CTFs, not blocking development.

## Per-Agent Tool Gating (DONE)

~~Restrict tool availability per agent role.~~

**Status:** Implemented via per-project `#+TOOLS` metadata. Each project file declares which tools its agents can use. The assembly engine filters the global tool list. See `tool_gating.md` for details.

The remaining idea is container-level tool gating (`--enable-code-exec` flag) that overrides project-level gating. This is documented in `tool_gating.md` as a planned flag.

## Split Delegate and Reload into Tool + Logic Modules

Separate the gptel-make-tool call from the agent system logic in delegate_tool.el and reload_tools.el. Pure organizational purity. Code works fine as-is.

## Telegram Bot API Integration

Two-way messaging bridge between agents and the user's phone via Telegram Bot API.

- Bot API is HTTP POST -- no SDK, no library. Two curl calls, ~50 lines of elisp.
- Two-way: bot can send AND receive via long polling (getUpdates). No inbound port needed.
- Free: bot tokens from BotFather, no per-message cost.

**Integration points:** Continuous agent notifications, long-running delegate completion, token budget warnings, remote execution results.

Most relevant once continuous agents are running reliably. One-way send (notifications) is already implemented via the `send_telegram` tool.

## Token Budget Management for Ollama Cloud

Weekly counter for Ollama Cloud usage, persist across restarts. When budget exhausted, cloud-assigned agents fall back to local GPU. Reset weekly.

Not relevant with local-only setup. Becomes relevant when using cloud models regularly.

## One-Shot Execution Mode (IMPLEMENTED)

~~One-shot execution becomes a mode in the assembly system, not a standalone feature.~~

**Status:** Implemented as Step 7. One-shot is a seventh archetype (`agents.d/archetypes/one-shot.org`) with `#+MODE: one-shot`. Invoked via `iar.sh --one-shot --agent NAME --prompt "TEXT"`. The archetype forces one-shot behavior on any personality. Completion detected via `=== BEGIN FINAL RESPONSE ===` / `=== END FINAL RESPONSE ===` delimiters. Clean stdout (final response only), diagnostics to stderr. No memory injection, no cycles, no task selection.

## Delegation Pipeline (IMPLEMENTED)

~~Orchestrator delegates to agent-assistant, which coordinates implementer and reviewer internally.~~

**Status:** Implemented as Step 8. Three personality files created (agent-assistant, implementer, reviewer). Personality-to-archetype map updated with three new entries. Delegate tool updated: agent parameter is now optional, defaults to agent-assistant (pipeline mode). Tool description updated. Pre-existing bug fixed: `iar--project-for-personality` was using `user-emacs-directory` instead of `iar-personalization-path` for project file resolution. 541 tests pass.

## Multi-Container Execution Framework (IMPLEMENTED)

~~Purpose-specific sidecar containers for isolated execution environments. `execute_code_remote` tool for cross-container command execution. `#+CONTAINERS` project metadata. Remote debug containers via Ansible.~~

**Status:** Implemented as Step 9. New `execute_code_remote` tool (`init.d/tools/code/execute_code_remote.el`) for local sidecar (`podman exec`) and remote SSH execution. New `iar-pentest` container image. `#+CONTAINERS` parsing in project parser and prompt assembly. `iar.sh` sidecar lifecycle management with shared workspace. `--no-containers` and `--container-image` flags. Ansible `iar-debug-container` role for remote debug containers. 568 tests pass (up from 557).

This absorbed the following earlier ideas (both now COMPLETED -- the multi-container framework replaced both approaches):
- **execute-code-local-security** (COMPLETED): Code execution isolation is now achieved via purpose-specific sidecar containers with physical separation, not in-process restrictions on `execute_code_local`. The multi-container framework replaced this approach -- each sidecar container has its own filesystem, user namespace, and network policy, providing physical isolation rather than in-process restrictions.
- **agent-ssh-read-only-access** (COMPLETED): SSH-based remote execution is implemented via `execute_code_remote` with key-only auth and explicit argv (no shell injection). Remote debug containers use SSH key-only auth with unprivileged users. The multi-container framework replaced this approach -- the `execute_code_remote` tool handles both local sidecar (`podman exec`) and remote SSH execution with built-in security (key-only auth, explicit argv, unprivileged users).

## Auditor: Create Test Target for Non-Destructive Demos

- Set up a local intentionally-vulnerable app (e.g., DVWA or custom)
- Ensure it has XSS, info disclosure, misconfig examples
- Keep it isolated from production

Relevant when testing the pentest personality (created in Step 12). The test targets (DVWA, Juice Shop) are part of Step 12's test-against-practice-targets subtask. Note: the original auditor agent no longer exists -- the pentest personality now fills this role.

## CTF Wizard: Session Hardening

- Lock down self-modification for CTF sessions (disable `iar-guard-allow-self-modification`)
- Enable output sanitizer in ctfwizard session (set `iar--sanitize-exec-output` buffer-local)
- Edit ctfwizard prompt.org to insert CTF rules and scope

Note: ctfwizard agent no longer exists in the current archetype set. Would need to be recreated as a personality + project. The session hardening concepts (locking self-modification, enabling sanitizer) are still valid for any security-focused personality.

## Darwin: Investigate Non-Streaming Ollama Tool-Use Overwrite

The Ollama non-streaming parser (`gptel--parse-response` in `gptel-ollama.el`) uses `cl-loop ... finally (plist-put info :tool-use tool-use)` which overwrites `:tool-use` instead of appending. The streaming parser was fixed to use `append`, but the non-streaming parser was not. If a non-streaming response contains tool calls across multiple JSON objects, earlier tool calls would be silently lost.

Low priority -- non-streaming Ollama responses typically come as a single JSON object. This is an upstream gptel contribution, not an i.ar development task.