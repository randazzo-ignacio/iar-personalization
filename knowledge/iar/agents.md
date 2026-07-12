# i.ar Agent System

## Agent Categories

### Primary Agents (user-facing)

| Agent | Role | Status |
|-------|------|--------|
| **mirror** | Mirror agent for the user. Challenges assumptions, pushes back on practicality, helps decide things. | Active, primary |
| **darwin** | Autonomous self-modifying agent. Runs in cycles, makes one small change, tests, logs, sleeps. | Active, autonomous |
| **auditor** | Security audit orchestrator. Delegates recon, analysis, action. Non-destructive. | Active, used for real audits |
| **ctfwizard** | CTF orchestrator. Delegates to specialists, coordinates attack chains. | Active, used for CTFs |

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

2. **LOGS.md** -- Semantic session notes. What was discussed, decided, learned. Lives at `audit/<name>/LOGS.md`. Injected into agent prompt programmatically by `agent_loader.el` (not via #+INCLUDE). Updated after significant sessions.

3. **SUMMARY.md** -- Compressed memory. Lives at `audit/<name>/SUMMARY.md`. The `C-c m` command (memory_tools.el) sends the conversation to the LLM for summarization, producing a compressed set of bullet points. Injected into agent prompt programmatically by `agent_loader.el`.

4. **MEMORIES.md** -- Darwin's compressed memory (replaces LOGS.md + SUMMARY.md for darwin). Lives at `audit/<name>/MEMORIES.md`. Injected into agent prompt programmatically by `agent_loader.el`.

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

## Darwin Autonomous Mode

Darwin is special. It runs in a loop without human direction:

1. MEMORIES.md (last 200 lines) is in system prompt -- no need to re-read
2. Read recent HISTORY.log via read_history tool
3. Read tasks via read_tasks tool (continuity across cycles)
4. Make one small change
5. Delegate to reviewer for code review
6. Run tests (revert if fail)
7. Commit, log, update memories
8. Use remove_task to delete completed tasks, write_task to create new ones
9. Sleep
10. Repeat

Darwin's constraints:
- `init.el` is immutable (cannot modify the entry point)
- Cannot delete other agents
- Tests must pass (or the change is reverted)
- One change per cycle (small, deliberate mutations)
- Self-modification mode must be enabled for .el file changes

Darwin uses the shared agent cycle infrastructure (`agent_cycle.el`, `agent_loop.sh`) for autonomous operation. Any orchestrator agent can be run autonomously via `agent_loop.sh --agent <name>`.