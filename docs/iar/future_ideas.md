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

**Status:** Not yet implemented. Ready when pentesting SaaS work begins.

## CTF Network Restrictions

- Restrict outbound network access to whitelisted CTF challenge IPs/domains
- Log all outbound connections for post-CTF review
- Block exfiltration paths
- Add scope constraint, no-destructive-action, and stealth directives to CTF agents
- Consider a "frozen" mode where file modification tools are disabled
- Evaluate per-agent network policies

Relevant when actively doing CTFs, not blocking development.

## Per-Agent Tool Gating

Restrict tool availability per agent role. Orchestrators become pure reasoners (delegate, read, log, manage tasks -- no write/execute). Workers get role-specific tools.

**Why it's a future idea:** Delegate result extraction already solved the context bloat problem. The models taking the path of least resistance (doing work instead of delegating) is a behavioral issue, not a blocking one.

**Implementation:** Category-based grouping in parameters.el, agent_loader.el filters gptel-tools on load. ~20 lines of code when ready.

## Split Delegate and Reload into Tool + Logic Modules

Separate the gptel-make-tool call from the agent system logic in delegate_tool.el and reload_tools.el. Pure organizational purity. Code works fine as-is.

## Telegram Bot API Integration

Two-way messaging bridge between agents and the user's phone via Telegram Bot API.

- Bot API is HTTP POST -- no SDK, no library. Two curl calls, ~50 lines of elisp.
- Two-way: bot can send AND receive via long polling (getUpdates). No inbound port needed.
- Free: bot tokens from BotFather, no per-message cost.

**Integration points:** Continuous agent notifications, long-running delegate completion, token budget warnings, remote execution results.

Most relevant once continuous agents are running reliably.

## Token Budget Management for Ollama Cloud

Weekly counter for Ollama Cloud usage, persist across restarts. When budget exhausted, cloud-assigned agents fall back to local GPU. Reset weekly.

Not relevant with local-only setup. Becomes relevant when using cloud models regularly.

## Auditor: Create Test Target for Non-Destructive Demos

- Set up a local intentionally-vulnerable app (e.g., DVWA or custom)
- Ensure it has XSS, info disclosure, misconfig examples
- Keep it isolated from production

Relevant when doing live auditor demos or testing delegation chains.

## Auditor: Test Delegation Chain

- Verify auditor delegates to reader for recon
- Verify auditor routes to coder for payload crafting
- Verify auditor uses reviewer for safety checks before execution
- Confirm delegates receive engagement rules in context
- Confirm reviewer rejects destructive payloads
- Confirm auditor asks human before any borderline technique

Verification checklist for when auditor is next used. Can be recreated on demand.

## CTF Wizard: Session Hardening

- Lock down self-modification for CTF sessions (disable `iar--guard-allow-self-modification`)
- Enable output sanitizer in ctfwizard session (set `iar--sanitize-exec-output` buffer-local)
- Edit ctfwizard prompt.org to insert CTF rules and scope

Note: variable names updated after Layer 3 rename. Original task referenced pre-rename names (`my-gptel--guard-allow-self-modification`, `my-gptel--sanitize-exec-output`).

## Darwin: Investigate Non-Streaming Ollama Tool-Use Overwrite

The Ollama non-streaming parser (`gptel--parse-response` in `gptel-ollama.el`) uses `cl-loop ... finally (plist-put info :tool-use tool-use)` which overwrites `:tool-use` instead of appending. The streaming parser was fixed to use `append`, but the non-streaming parser was not. If a non-streaming response contains tool calls across multiple JSON objects, earlier tool calls would be silently lost.

Low priority -- non-streaming Ollama responses typically come as a single JSON object. This is an upstream gptel contribution, not an i.ar development task.