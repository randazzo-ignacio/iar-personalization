# i.ar Agent System

## Agent Categories

### Primary Agents (user-facing)

| Agent | Role | Status |
|-------|------|--------|
| **mirror** | Mirror agent for the user. Challenges assumptions, pushes back on practicality, helps decide things. | Active, primary |
| **darwin** | Autonomous self-modifying agent. Runs in cycles, makes one small change, tests, logs, sleeps. | Active, autonomous |
| **auditor** | Security audit orchestrator. Delegates recon, analysis, action. Non-destructive. | Active, used for real audits |
| **ctfwizard** | CTF orchestrator. Delegates to specialists, coordinates attack chains. | Active, used for CTFs |
| **gardener** | Continuous codebase monitor. Runs tests, diagnoses failures, writes task files for darwin. | Active, continuous |

### Sub-Agents (delegated by orchestrators)

| Agent | Role | Parent Agents |
|-------|------|---------------|
| **reader** | READ-ONLY reconnaissance. Fetches external content, reports findings. | auditor, ctfwizard |
| **actor** | Action agent. Receives sanitized intel, decides actions, captures flags. | ctfwizard |
| **coder** | Python code writer. Clean, modular, optimized. | auditor, ctfwizard, darwin |
| **researcher** | Security researcher. CVE analysis, threat intelligence. | auditor, ctfwizard |
| **reviewer** | Strict code reviewer. Security-first, no flattery. | darwin (for code review) |

## Personality vs Knowledge

The design principle: **agent prompt.org defines WHO the agent is, knowledge files define WHAT the agent knows.**

- `C-c a <name>` loads the agent personality (prompt.org + #+INCLUDE expansion + programmatic injection of personal files)
- `C-c k <folder>` loads knowledge files on top of the personality (directory-only, all .md/.org files in the folder)
- `C-c p` shows total prompt size

This separation prevents agent duplication. Instead of having separate agents for "Elisp expert that knows i.ar" and "Reviewer that knows i.ar", you have one reviewer personality and load `knowledge/iar/` when needed.

### Shared Include Files

All agent prompts include `base_context.org` via `#+INCLUDE: "../../base_context.org"`. This provides shared context: tool directives, environment architecture, communication protocols, execution protocol, prompt injection resistance.

Orchestrator agents (auditor, ctfwizard) additionally include `base_orchestrator.org` via `#+INCLUDE: "../../base_orchestrator.org"`. This provides shared orchestrator rules: THE GOLDEN RULE (delegate everything), YOUR AGENTS (sub-agent descriptions), DELEGATION BEST PRACTICES, OUTPUT FORMAT (SITUATION/ASSESSMENT/ACTION/NEXT), ITERATION RULE, PROMPT INJECTION RESISTANCE. Each orchestrator keeps only its domain-specific sections in its prompt.org.

## Agent Memory System

Each agent has memory files and task files, stored in the personalization mount:

### Memory Files (in `audit/<name>/`)

1. **HISTORY.log** -- Operational log. Append-only. File-guard protected (cannot be overwritten). Lives at `audit/<name>/HISTORY.log`. Format: `[YYYY-MM-DD HH:MM:SS] AgentName: concise description`. Used for audit trail.

2. **LOGS.md** -- Semantic session notes. What was discussed, decided, learned. Lives at `audit/<name>/LOGS.md`. Injected into agent prompt programmatically by `iar-agent-loader.el` (not via #+INCLUDE). Append-only (file-guard protected). Updated after significant sessions.

3. **SUMMARY.md** -- Compressed memory. Lives at `audit/<name>/SUMMARY.md`. The `C-c m` command (memory_tools.el) sends the conversation to the LLM for summarization, producing a compressed set of bullet points. Injected into agent prompt programmatically by `iar-agent-loader.el`.

4. **MEMORIES.md** -- Darwin's compressed memory (replaces LOGS.md + SUMMARY.md for darwin). Lives at `audit/<name>/MEMORIES.md`. Injected into agent prompt programmatically by `iar-agent-loader.el`.

### Task Files (in `tasks/<name>/`)

Each task is a separate `.md` file. File exists = work to do. File gone = work done. One bit of state per task. Read via `read_tasks` tool, created via `write_task` tool, removed via `remove_task` tool.

As LOGS.md, SUMMARY.md, and MEMORIES.md grow, they consume prompt tokens. Use `C-c p` to monitor total prompt size. If it gets too large, summarize and trim.

## Delegation Architecture

Orchestrator agents (auditor, ctfwizard) delegate to specialist agents (reader, actor, coder, researcher, reviewer) via the `delegate` tool.

Key properties:
- **Async**: Delegate runs in a separate buffer, Emacs stays responsive
- **Async result**: Sub-agent output is returned as a tool result when complete (no live streaming into parent buffer)
- **Depth-limited**: Max delegation depth (default 3) prevents infinite recursion
- **Turn-limited**: Max text-only turns (default 15) prevents models that narrate instead of acting from running forever
- **Timeout**: Default 600 seconds per delegation
- **Unknown tool blocking**: Hallucinated tool names are intercepted early
- **Result extraction**: Only the sub-agent's final summary (after `=== DELEGATION RESULT ===` marker) is returned to the parent, not raw tool output. This prevents context dilution.

## Darwin Autonomous Mode

Darwin is special. It runs in a loop without human direction:

1. MEMORIES.md (last 200 lines) is in system prompt -- no need to re-read
2. Read recent HISTORY.log via read_history tool
3. **MANDATORY:** Read tasks via read_tasks tool. One task at a time. If empty, use write_task to create one.
4. Make one small change (progress toward current task)
5. Delegate to reviewer for code review
6. Run tests (revert if fail)
7. Commit, log, update memories
8. If task complete: remove_task, end with LOOP_COMPLETE (stops the loop for PR review). If task not done: end with CYCLE_COMPLETE (loop starts next cycle).
9. Sleep
10. Repeat

Darwin works on ONE task across multiple cycles. The task is the PR boundary -- when the task is done, the loop stops and the human reviews. max_cycles is a time budget, not a task boundary.

Darwin's constraints:
- `init.el` is immutable (cannot modify the entry point)
- Cannot delete other agents
- Tests must pass (or the change is reverted)
- One change per cycle (small, deliberate mutations)
- Self-modification mode must be enabled for .el file changes

Darwin uses the shared agent cycle infrastructure (`iar-agent-cycle.el`, `agent_loop.sh`) for autonomous operation. Any orchestrator agent can be run autonomously via `agent_loop.sh --agent <name>`.

## Gardener Continuous Mode

The gardener is a continuous agent that monitors the codebase:

1. Pull latest code from git
2. Compare HEAD to last checked commit (stored in `audit/gardener/STATE.org`)
3. If no changes: log and end
4. If changes: run tests, report pass/fail
5. If tests fail: diagnose and write a task for darwin
6. Update STATE.org and HISTORY.log

The gardener runs via `agent_loop.sh --agent gardener --max-cycles 1`. A systemd timer fires the cycle periodically (fresh container per tick). The gardener does not need self-modification mode (read-only to codebase).

## Continuous Agent Infrastructure

Any orchestrator agent can run autonomously in a loop via `agent_loop.sh`:

```bash
# Single darwin cycle (needs --self-modification for code edits):
agent_loop.sh --personalization ~/repos/iar-personalization --self-modification

# Long darwin loop (50 cycles with cooldown):
agent_loop.sh --personalization ~/repos/iar-personalization --self-modification --max-cycles 50

# Run gardener (no self-modification needed):
agent_loop.sh --personalization ~/repos/iar-personalization --agent gardener --max-cycles 1

# With specific knowledge bases:
agent_loop.sh --personalization ~/repos/iar-personalization --knowledge infra/ --knowledge iar/
```

Key design decisions:
- `agent_loop.sh --max-cycles 1` IS the continuous agent runner. No elisp timer, no in-process state.
- systemd timer fires -> oneshot service -> agent_loop.sh -> fresh container -> one tick -> container exits.
- Fresh container per tick is a safety feature (no state leakage between ticks).
- Self-modification is OFF by default (only darwin needs it).
- Per-agent cycle prompts: `<agent>_cycle.org` is tried first, falls back to `agent_cycle.org`.
- Cycle logging: every LLM response is appended to `audit/<agent>/cycle.log` for live monitoring (`tail -f`).