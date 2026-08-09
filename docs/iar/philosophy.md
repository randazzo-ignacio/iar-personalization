# i.ar Philosophy and Design Decisions

## Core Principles

### 1. Local-First, Always
All processing occurs on local hardware. No cloud dependencies, no telemetry, no external API calls. The LLM runs on your GPU via Ollama. The agent framework runs in Emacs on your machine. The only network traffic is WireGuard mesh between your own nodes. If the internet goes down, i.ar still works.

### 2. Containment First
Every autonomous capability has a kill switch. The container is the first boundary -- read-only rootfs, dropped capabilities, preflight audit. The file guard is the second boundary -- archetype/personality/cycle files and shared context are always protected. Self-modification mode is opt-in via flag, never default. The principle: if an agent can do something dangerous, it should require explicit human authorization.

### 3. Human Agency
Systems empower individuals, not control them. No backdoors, no hidden capabilities, no telemetry. All code is auditable. The user can read every prompt, every tool definition, every audit log entry. The system does not hide what it does.

### 4. Precision Over Speed
Measured approaches to system changes. One change per darwin cycle. File guard tiers. Audit logging. The cost of a mistake in infrastructure is real -- conservative security posture is not cowardice, it's engineering.

## The Duct Tape Method

What feels like a shortcut or a hack is actually the creative edge. Constraint forces a different path, and the different path is where innovation lives.

Key example: i.ar's self-modification capability. The original goal was to write Emacs Lisp modules for the framework. When the creator couldn't learn Lisp fast enough, instead of abandoning the project, the tool was made self-modifying -- agents write their own modules. That "failure" became one of the most unique features of the framework. No other agentic framework gives users this capability.

The principle: the results are the proof. The method is the advantage. Don't fight the chaos -- channel it.

## AI-First Documentation

i.ar's documentation lives in the knowledge base, not in READMEs or wikis. The knowledge files in `docs/iar/` are the single source of truth for how the project works. This provides something no other project has:

- Load `docs/iar/` into any agent and ask it to explain the architecture, design decisions, or code structure interactively.
- It's like being able to talk to the maintainer.
- It helps the maintainer stay consistent by conversing with the mirror agent before making changes, then updating the knowledge base after.

The knowledge base IS the documentation. READMEs are quickstart guides only.

## Architecture Design Decisions

### Why three-axis assembly

The original architecture had one monolithic `prompt.org` per agent. Adding a new agent meant copying an existing one and editing it. Shared context was via `#+INCLUDE` directives. This led to duplication: every agent that needed security knowledge had it copied into its prompt. Every agent that needed tool directives had them duplicated.

The three-axis model (archetype + personality + project) separates concerns:
- **Archetype** defines behavioral mode (how the agent operates). Only 6 exist, rarely change.
- **Personality** defines voice/character (who the agent is). Changes are isolated to character.
- **Project** defines knowledge, tools, and objective (what the agent works on). Changes are isolated to the domain.

Adding a new agent means creating a personality file (voice) and optionally a project file (domain). The archetype is reused. Tools and knowledge are declared in the project, not copied into the prompt. This eliminates duplication and makes the system composable.

### Why mode-based memory

Different agent modes have different memory needs:
- **Interactive** agents have conversations with a human. They need session notes (LOGS.md) to maintain continuity across sessions.
- **Autonomous** agents run in cycles. They need a structured checkpoint (STATE.org) to know where they were and what to do next.
- **Continuous** agents wake up on a timer. They need the same checkpoint (STATE.org) but with different semantics (last-checked state, not current task).
- **Delegated** agents are ephemeral. They have no memory -- their work is captured in the response they return.

The assembly engine reads the `#+MODE:` metadata from the archetype and injects the appropriate memory file. This is cleaner than having each agent manage its own memory loading.

### Why per-project tool gating

Different agents need different tools. Darwin needs filesystem and code execution but not delegation. The gardener needs read-only tools but not write access. The reviewer needs read and check_elisp but not write or commit.

Tool gating via `#+TOOLS` in the project file is simpler and more maintainable than runtime tool filtering or per-agent tool registration. It is declarative: the project file says what tools are available, the assembly engine filters the global tool list. No code changes needed to adjust an agent's toolset.

### Why per-project task and audit paths

Tasks and audit logs are scoped to projects, not personalities. This means:
- `tasks/iar/` contains tasks for the i.ar project, regardless of which personality is working on them
- `audit/iar/mirror/HISTORY.log` is mirror's operational log within the iar project
- `audit/iar/darwin/STATE.org` is darwin's checkpoint within the iar project

This allows multiple personalities to work on the same project (mirror and darwin both work on iar) while keeping their audit logs separate. It also allows a personality to work on different projects (darwin works on the darwin project, which is scoped to code evolution).

## Security Model Design Decisions

### Why no friction-based security
The file guard uses explicit tiers, not pattern interception. If self-modification is enabled, it's all-or-nothing for tier 2. No "dangerous pattern detection" in elisp evaluation, no partial blocks. Rationale: friction gives a false sense of security. It doesn't actually prevent bad actors or hallucinating AI. The flag is the gate. Accept the risk or don't enable it.

### Why container isolation
The container is the current security boundary. Read-only rootfs, dropped capabilities, preflight audit. Outside the container, the tools themselves become the permission model. The file guard was designed for this future -- it works without container isolation.

### Why multi-container isolation
Different tasks need different capabilities and different risk profiles. A pentest container needs outbound internet and security tools but should never touch personal data. A concept exploration container should have no network at all. A life organization container should have no network and no access to codebase or security tools. Running these in the same container as the Emacs agent would require either granting excessive capabilities or implementing complex in-process isolation.

The multi-container model solves this with physical separation: each purpose-specific container has its own filesystem, user namespace, and network policy. The Emacs container (where agents live) has no outbound internet. The pentest container has bridge networking but no personal data -- it cannot see the personalization repo, docs, or knowledge bases. The concepts and life-org containers have no networking at all -- they cannot reach the internet. The debug container mounts the host root filesystem read-only at `/host` for inspection, accessed via SSH over WireGuard with an unprivileged user. The only shared surface between the Emacs container and sidecars is the workspace directory at `/workspace`.

This is purpose-specific isolation: the security boundary is the container itself, not a pattern matcher or a permission flag inside a shared process. Each container type is purpose-built with only the tools it needs. The pentest container cannot see personalization data; the life-org container cannot reach the internet; the concepts container has no network at all. The `#+CONTAINERS` project metadata declares which containers a project needs, and `iar.sh` manages their lifecycle -- starting sidecars before Emacs and tearing them down on exit via trap-based cleanup.

### Why no cloud
Cloud dependencies mean someone else controls your compute. For an AI agent framework that can modify its own code, send network requests, and execute arbitrary commands, cloud dependency is an unacceptable trust surface. Local LLMs on local hardware, connected via WireGuard, with no external API calls.