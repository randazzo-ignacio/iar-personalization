# i.ar Agent System

## Three-Axis Assembly Model

Every agent instance is assembled from three independent primitives:

1. **Archetype** (behavioral mode) -- from `agents.d/archetypes/<name>.org`. Defines HOW the agent behaves: interactive, autonomous, continuous, or delegated. Determines memory injection mode and completion semantics. Has `#+MODE:` metadata.
2. **Personality** (voice/character) -- from `agents.d/personalities/<name>.org`. Defines WHO the agent is: its tone, perspective, blind spots, guiding principles. Pure character -- no tools, no knowledge, no behavioral rules.
3. **Project** (knowledge/tools/objective) -- from `personalization/projects/<name>.org`. Defines WHAT the agent works on: which doc labels to auto-load (`#+KNOWLEDGE`), which tools to register (`#+TOOLS`), which sidecar containers to start (`#+CONTAINERS`), what host paths to mount (`#+MOUNTS`), and a free-text objective (`#+OBJECTIVE`).

The assembly engine (`iar-prompt-assembly.el`) combines these into a single system prompt. Assembly order:

1. `base_context.org` (shared context, injected by assembly engine)
2. Archetype content
3. Personality content
4. Project objective
5. Auto-loaded knowledge (from project `#+KNOWLEDGE`)
6. Memory injection (mode-based: LOGS.md or STATE.org)
7. Mount info

Tool gating is per-project: `#+TOOLS` in the project file filters which tools from `gptel-tools` are registered for that agent. If `#+TOOLS` is absent, all tools are registered. Container gating is also per-project: `#+CONTAINERS` declares which sidecar containers to start. When present, the `execute_code_remote` tool is automatically registered (not listed in `#+TOOLS`) and available targets are injected into the system prompt.

## Archetypes

Seven fixed archetypes in `agents.d/archetypes/`. Each has `#+MODE:` metadata that determines memory injection and completion behavior.

| Archetype | Mode | Memory | Completion | Used By |
|-----------|------|--------|------------|---------|
| **interactive** | interactive | LOGS.md (last N lines) | None (human ends session) | mirror, davinci, colin |
| **autonomous** | autonomous | STATE.org (full) | LOOP_COMPLETE / CYCLE_COMPLETE | darwin |
| **continuous** | continuous | STATE.org (full) | LOOP_COMPLETE (every tick) | gardener, librarian |
| **agent-assistant** | delegated | None | Response is completion | agent-assistant personality (delegate tool default) |
| **implementer** | delegated | None | Response is completion | implementer personality (via agent-assistant) |
| **reviewer** | delegated | None | Response is completion | reviewer personality (via agent-assistant) |
| **one-shot** | one-shot | None | Final response between delimiters | iar.sh --one-shot --agent NAME --prompt "TEXT" |

### Personality-to-Archetype Mapping

The mapping is hardcoded in `iar-personality-archetype-map` in `iar-agent-loader.el`:

| Personality | Archetype | How invoked |
|-------------|-----------|-------------|
| mirror | interactive | C-c a (interactive session) |
| davinci | interactive | C-c a (interactive session) |
| colin | interactive | C-c a (interactive session) |
| agent-assistant | agent-assistant (delegated) | delegate tool (pipeline mode) |
| implementer | implementer (delegated) | delegate tool (via agent-assistant) |
| reviewer | reviewer (delegated) | delegate tool (via agent-assistant) |
| darwin | autonomous | iar.sh --loop --agent darwin |
| gardener | continuous | iar.sh --loop --agent gardener |
| librarian | continuous | iar.sh --loop --agent librarian |

For delegation: agent-assistant, implementer, and reviewer personalities each map to their own archetype file (same name). The delegate tool defaults to agent-assistant when no agent is specified (pipeline mode). When an agent is specified, it spawns that personality directly (direct mode). The delegate tool resolves the archetype and project from the personality name and assembles the prompt.

One-shot is not in the personality-to-archetype map. It is forced by the invocation mode (`iar.sh --one-shot`), not by the personality. Any personality can be used in one-shot mode -- the personality provides the voice, the one-shot archetype provides the behavior.

## Personalities

Personalities live in `agents.d/personalities/<name>.org`. They are pure voice/character -- no tools, no knowledge references, no behavioral rules. Those come from the archetype and project.

| Personality | Voice | Project |
|-------------|-------|---------|
| **mirror** | Reflects the user's thinking back, challenges assumptions, pushes back on practicality | iar |
| **darwin** | Autonomous organism that evolves its own code. Exists inside a system it can read, understand, and modify | darwin |
| **gardener** | Groundskeeper. Walks the grounds, checks fences, reports what it finds. Does not fix things | gardener |
| **librarian** | Keeper of the knowledge base. Checks source files against documentation, fixes drift | librarian |
| **davinci** | Insatiable curiosity that refuses to stay in one lane. Study companion for degree summarization | iar |
| **colin** | Game design partner and technical co-developer. Building an indie game together | colin |
| **agent-assistant** | Pragmatic coordinator. Plans, delegates, evaluates. Does not do the work itself | agent-assistant |
| **implementer** | Focused builder. Does the work, reports what was done. Does not question the task | implementer |
| **reviewer** | Critical evaluator. Finds real problems, not style preferences. Structured review | reviewer |

## Projects

Projects live in `personalization/projects/<name>.org`. Each project file contains:

- `#+KNOWLEDGE:` -- space-separated list of doc subdirectory labels to auto-load (e.g., `iar/`, `infra/`, `user/`)
- `#+TOOLS:` -- space-separated list of tool names to register. If absent, all tools registered
- `#+CONTAINERS:` -- space-separated list of sidecar container targets to start (e.g., `pentest`). When present, `execute_code_remote` is automatically registered and available targets are injected into the system prompt. If absent, no sidecar containers are started and `execute_code_remote` is not available.
- `#+MOUNTS:` -- space-separated list of `path:mode` pairs (e.g., `/var/home/nacho/repos/i.ar:rw`). If absent, no project-specific mounts
- `#+OBJECTIVE:` -- free-text scope/goal injected into the prompt

| Project | Knowledge | Tools | Containers | Mounts | Objective |
|---------|-----------|-------|------------|--------|-----------|
| **iar** | iar/, infra/, user/ | All tools | (none) | /var/home/nacho/repos/iar-infrastructure:rw | General-purpose i.ar development, infrastructure management, security research |
| **darwin** | iar/ | list, read, write, append, exec, check_elisp, task tools, git, roadmap | (none) | /var/home/nacho/repos/i.ar:rw | Autonomous code evolution. One small change per cycle, test, commit, log |
| **gardener** | iar/ | list, read, exec, task tools, roadmap | (none) | (none) | Codebase monitoring. Pull latest, run tests, diagnose failures, write tasks for darwin |
| **librarian** | iar/ | list, read, write, append, exec, task tools, git, telegram | (none) | /var/home/nacho/repos/i.ar:rw | Documentation sync. Check source against docs/iar/, fix drift, commit |
| **colin** | user/ | list, read, write, append, exec, check_elisp, task tools, git, delegate | (none) | (none) | Game design and development in Godot 4 |
| **agent-assistant** | iar/ | delegate, read, list, exec | (none) | (none) | Sub-orchestration for delegation pipeline |
| **implementer** | iar/ | list, read, write, append, exec, check_elisp, git | (none) | (none) | Focused code execution for delegation pipeline |
| **reviewer** | iar/ | list, read, exec, check_elisp | (none) | (none) | Critical evaluation for delegation pipeline |

The `iar--project-for-personality` function resolves projects: if a project file matching the personality name exists, it uses that. Otherwise, it falls back to the `iar` project.

## Cycles

Cycle prompts live in `agents.d/cycles/<name>.org`. They define what an autonomous/continuous agent does when it wakes up. The personality-to-cycle mapping is in `iar-personality-cycle-map` in `iar-agent-cycle.el`:

| Personality | Cycle File | Description |
|-------------|-----------|-------------|
| darwin | self_modification.org | Read state, read tasks, make one change, review, test, commit, log, update state |
| gardener | monitoring.org | Pull latest, compare HEAD to last checked commit, run tests, diagnose failures, write tasks for darwin |
| librarian | documentation_sync.org | Pick one source file, compare against docs, fix drift, commit, log |

Cycle files are loaded by `iar-agent-cycle.el` when running in loop mode (`iar.sh --loop`). The cycle prompt is sent as the initial message after the assembled system prompt is set.

## Memory System

Memory is mode-based, determined by the archetype's `#+MODE:` metadata:

### Memory Files (in `audit/<project>/<personality>/`)

1. **HISTORY.log** -- Operational log. Append-only. File-guard protected (cannot be overwritten). Format: `[YYYY-MM-DD HH:MM:SS] AgentName: concise description`. Used for audit trail. All modes.

2. **LOGS.md** -- Semantic session notes. What was discussed, decided, learned. Injected into agent prompt programmatically (last N lines via `iar-personal-file-max-lines`). Append-only (file-guard protected). Interactive mode only.

3. **STATE.org** -- Structured checkpoint. Injected into agent prompt programmatically (full, it's short). Written at end of each cycle/tick. Autonomous and continuous modes only.

Format:
```
#+LAST_CYCLE: <timestamp>
#+CURRENT_TASK: <task path or "none">
#+TASK_PROGRESS: <brief status>
#+LAST_ACTION: <what you just did>
#+NEXT_ACTION: <what to do next>
#+NOTES: <anything useful for next cycle>
```

Delegated archetypes (agent-assistant, implementer, reviewer) have no persistent memory. They are ephemeral -- their work is captured in the final response returned to the spawner.

### Task Files (in `tasks/<project>/`)

Tasks are per-project. Each task is a directory with a `description.org` file and optional subtask `.org` files. File exists = work to do. File gone = work done. Read via `read_task` tool, created via `create_task` tool, removed via `remove_task` tool.

## Delegation Architecture

The delegate tool spawns sub-agents with assembled prompts. Two modes:

### Direct Delegation

`delegate(agent="mirror", task="...")` spawns the specified personality directly. The archetype and project are resolved from the personality name via `iar-personality-archetype-map` and `iar--project-for-personality`.

### Pipeline Delegation (Default)

`delegate(task="...", context="...")` (no agent specified) defaults to agent-assistant. The agent-assistant interprets the request, plans the work, delegates to implementer and reviewer using the delegate tool internally, coordinates a correction loop (default max 2 rounds), and returns a final summary.

### Pipeline Flow

1. Orchestrator calls `delegate(task="...")` (no agent specified)
2. agent-assistant is spawned with delegated archetype + agent-assistant project
3. agent-assistant uses its delegate tool to spawn implementer (depth 2)
4. agent-assistant uses its delegate tool to spawn reviewer (depth 2)
5. If reviewer finds issues, agent-assistant re-delegates to implementer with corrections
6. After max 2 correction rounds (or if reviewer approves), agent-assistant returns final summary
7. Orchestrator receives only the agent-assistant's final summary

### Depth Limiting

- Depth 0: Top-level agent (orchestrator)
- Depth 1: agent-assistant (can delegate)
- Depth 2: implementer, reviewer (cannot delegate -- delegate tool removed at depth 3)
- `iar-delegate-max-depth` (default 3) enforces this

Key properties:
- **Async**: Delegate runs in a separate buffer, Emacs stays responsive
- **Async result**: Sub-agent output is returned as a tool result when complete (no live streaming into parent buffer)
- **Depth-limited**: Max delegation depth (default 3) prevents infinite recursion
- **Turn-limited**: Max text-only turns (default 15) prevents models that narrate instead of acting from running forever
- **Timeout**: Default 600 seconds per delegation
- **Unknown tool blocking**: Hallucinated tool names are intercepted early
- **Result extraction**: Only the sub-agent's final summary (after `=== DELEGATION RESULT ===` marker) is returned to the parent, not raw tool output. This prevents context dilution.
- **Correction loop**: agent-assistant self-limits to 2 correction rounds (instructed in archetype prompt, not code-enforced). After that, returns best result with "needs human review" note.

## Autonomous and Continuous Modes

Any personality with an autonomous or continuous archetype can run autonomously in a loop via `iar.sh --loop`:

```bash
# Single darwin cycle (needs --self-modification for code edits):
iar.sh --loop --personalization ~/repos/iar-personalization --agent darwin --self-modification

# Run gardener (no self-modification needed):
iar.sh --loop --personalization ~/repos/iar-personalization --agent gardener --max-cycles 1

# Long darwin loop (50 cycles with cooldown):
iar.sh --loop --personalization ~/repos/iar-personalization --agent darwin --self-modification --max-cycles 50
```

Key design decisions:
- `iar.sh --loop --max-cycles 1` IS the continuous agent runner. No elisp timer, no in-process state.
- systemd timer fires -> oneshot service -> iar.sh --loop -> fresh container -> one tick -> container exits.
- Fresh container per tick is a safety feature (no state leakage between ticks).
- Self-modification is OFF by default (only darwin needs it).
- Per-agent cycle prompts: `<personality>_cycle.org` is tried first, falls back to `agent_cycle.org`.
- Cycle logging: every LLM response is appended to `audit/<project>/<personality>/cycle.log` for live monitoring (`tail -f`).

### Darwin (Autonomous)

Darwin runs in cycles without human direction:

1. STATE.org is in system prompt (injected by assembly engine)
2. Read recent HISTORY.log via read_history tool
3. **MANDATORY:** Read tasks via read_task tool. One task at a time.
4. Make one small change (progress toward current task)
5. Delegate to reviewer for code review
6. Run tests (revert if fail)
7. Commit, log, update STATE.org
8. If task complete: remove_task, end with LOOP_COMPLETE. If not: end with CYCLE_COMPLETE.

Darwin works on ONE task across multiple cycles. The task is the PR boundary.

### Gardener (Continuous)

1. Pull latest code from git
2. Compare HEAD to last checked commit (stored in STATE.org)
3. If no changes: log and end
4. If changes: run tests, report pass/fail
5. If tests fail: diagnose and write a task for darwin
6. Update STATE.org and HISTORY.log

### Librarian (Continuous)

1. Pull latest code from git
2. Compare HEAD to last checked commit
3. Pick one source file to verify against documentation
4. Read source file, find corresponding docs/iar/ section
5. Compare and assess: IN SYNC, DRIFT, UNDOCUMENTED, or UNCERTAIN
6. If drift or undocumented: fix the docs, commit
7. Update STATE.org and HISTORY.log
### One-Shot Mode

One-shot mode runs a single instruction through an agent and exits. No human conversation, no task tree, no cycles, no state.

```bash
# One-shot with mirror personality:
iar.sh --one-shot --personalization ~/repos/iar-personalization \
  --project iar --agent mirror \
  --prompt "Review init.el and report any issues" \
  --model granite4.1:8b-q8_0 --ctx 131072
```

Key design decisions:
- The archetype is forced to "one-shot" by the entry point, not by the personality map. Any personality can be used in one-shot mode.
- The prompt text is passed via the `IAR_ONE_SHOT_PROMPT` environment variable to avoid bash/elisp quoting issues.
- The agent wraps its final response in `=== BEGIN FINAL RESPONSE ===` and `=== END FINAL RESPONSE ===` delimiters. The system extracts the content between them and prints it to stdout.
- Diagnostics (token counts, progress messages) go to stderr and the log file. Stdout is clean -- only the final response.
- Completion is detected by the delimiters, not by an explicit signal like LOOP_COMPLETE. If the agent produces a text-only response without delimiters, a nudge prompt is sent reminding it to wrap its output.
- No continue prompts, no CYCLE_COMPLETE/LOOP_COMPLETE. Single execution, then exit.
- Audit logging works as usual -- every tool call is logged to `audit/audit.log`. LLM responses are logged to `audit/<project>/<personality>/cycle.log`.