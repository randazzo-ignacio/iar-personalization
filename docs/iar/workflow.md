# i.ar Maintenance Workflow

## The Documentation IS the Knowledge Base

i.ar uses AI-first documentation. The knowledge base files in `docs/iar/` are the single source of truth for how the project works. READMEs are quickstart guides only. There is no separate wiki, no separate architecture document, no separate design doc. If something isn't in the knowledge base, it doesn't exist as far as the system is concerned.

This means: when you change the code, you update the knowledge base. When you add a feature, you document it in the knowledge base. When you remove something, you remove it from the knowledge base. The knowledge base and the code are a coupled system.

## The Workflow

### Before Making a Change

1. Load the mirror agent: `C-c a mirror`
2. The iar project auto-loads `docs/iar/` knowledge into the prompt
3. Describe the change you want to make
4. The mirror will challenge you on scope, time estimate, dependencies, pragmatism, and finish line
5. The mirror can catch inconsistencies between your plan and the current documentation
6. Iterate until you and the mirror agree on the change

### Making the Change

1. Make the code change
2. Test it (run the test suite, verify behavior)
3. If the change affects architecture, modules, tools, agents, or security -- update the relevant docs/iar/ file

### After Making a Change

1. Update `docs/iar/` files to reflect the new state
2. If the change is significant, append session notes to LOGS.md
3. Commit both the code change and the knowledge base update together
4. If using the personalization submodule, update the submodule pointer in the main repo

### When Darwin Makes Changes

Darwin runs autonomously and makes one change per cycle. After each cycle:
- Darwin logs to its HISTORY.log and updates STATE.org
- Darwin commits its change to the i.ar repo
- If darwin's change affects documented behavior, the knowledge base should be updated (either by darwin if capable, or by the librarian agent, or by the human in the next session)

### When the Librarian Runs

The librarian is a continuous agent that checks source files against `docs/iar/` documentation:
1. Picks one source file per tick
2. Reads the source code
3. Finds the corresponding documentation section
4. Compares and assesses: IN SYNC, DRIFT, UNDOCUMENTED, or UNCERTAIN
5. If drift or undocumented: fixes the docs, commits
6. Updates STATE.org with checked files list

This provides automated drift detection between code and documentation.

## What to Update and When

| Change Type | Update Which File |
|---|---|
| New or removed module | `modules.md` |
| Module moved to different subdirectory | `modules.md` |
| New or removed tool | `tools.md` + `modules.md` |
| Tool behavior change | `tools.md` |
| New or removed container image | `architecture.md` + `modules.md` |
| New or removed sidecar container target | `architecture.md` + `agents.md` + `tool_gating.md` |
| Container network policy change | `architecture.md` + `tool_gating.md` |
| `#+CONTAINERS` metadata change in projects | `agents.md` + `architecture.md` + `usage.md` |
| Remote debug container deployment change | `architecture.md` + `infra/roles.md` + `infra/overview.md` |
| New or removed archetype | `agents.md` + `modules.md` |
| New or removed personality | `agents.md` |
| New or removed project | `agents.md` + `architecture.md` |
| New or removed cycle file | `agents.md` + `modules.md` |
| Personality-to-archetype mapping change | `agents.md` + `modules.md` |
| File guard tiers change | `tools.md` |
| New flag on iar.sh | `architecture.md` + `usage.md` |
| Container hardening change | `architecture.md` |
| Bind mount change | `architecture.md` |
| Personalization mount structure change | `architecture.md` + `usage.md` |
| Design decision or philosophy change | `philosophy.md` |
| Maintenance process change | this file (`workflow.md`) |
| Roadmap updated | `tasks/<project>/ROADMAP.org` (via write_roadmap tool) |
| Tool gating behavior change | `tools.md` + `tool_gating.md` |

## Size Management

As the knowledge base grows, loading a project with `#+KNOWLEDGE: iar/ infra/ user/` consumes more context. Monitor with `C-c i`. If it gets too large:

1. Split into sub-knowledge bases (e.g., `iar-core/`, `iar-agents/`, `iar-infra/`)
2. Summarize older sections into compressed form
3. Move stable, rarely-changing content to a reference knowledge base and keep only active content in `iar/`
4. Use per-project `#+KNOWLEDGE` to load only what each project needs (e.g., darwin loads only `iar/`, colin loads only `user/`)

The current `docs/iar/` is organized as one directory with topic-specific files. This works because the total size is manageable. The split strategy is available when needed.