# i.ar Philosophy and Design Decisions

## Core Principles

### 1. Local-First, Always
All processing occurs on local hardware. No cloud dependencies, no telemetry, no external API calls. The LLM runs on your GPU via Ollama. The agent framework runs in Emacs on your machine. The only network traffic is WireGuard mesh between your own nodes. If the internet goes down, i.ar still works.

### 2. Containment First
Every autonomous capability has a kill switch. The container is the first boundary -- read-only rootfs, dropped capabilities, preflight audit. The file guard is the second boundary -- agent prompts and shared context are always protected. Self-modification mode is opt-in via flag, never default. The principle: if an agent can do something dangerous, it should require explicit human authorization.

### 3. Human Agency
Systems empower individuals, not control them. No backdoors, no hidden capabilities, no telemetry. All code is auditable. The user can read every prompt, every tool definition, every audit log entry. The system does not hide what it does.

### 4. Precision Over Speed
Measured approaches to system changes. One change per darwin cycle. File guard tiers. Audit logging. The cost of a mistake in infrastructure is real -- conservative security posture is not cowardice, it's engineering.

## The Duct Tape Method

What feels like a shortcut or a hack is actually the creative edge. Constraint forces a different path, and the different path is where innovation lives.

Key example: i.ar's self-modification capability. The original goal was to write Emacs Lisp modules for the framework. When the creator couldn't learn Lisp fast enough, instead of abandoning the project, the tool was made self-modifying -- agents write their own modules. That "failure" became one of the most unique features of the framework. No other agentic framework gives users this capability.

The principle: the results are the proof. The method is the advantage. Don't fight the chaos -- channel it.

## AI-First Documentation

i.ar's documentation lives in the knowledge base, not in READMEs or wikis. The knowledge files are written for the thing that reads them -- the LLM. This provides something no other project has:

- Load `knowledge/iar/` into any agent and ask it to explain the architecture, design decisions, or code structure interactively.
- It's like being able to talk to the maintainer.
- It helps the maintainer stay consistent by conversing with the mirror agent before making changes, then updating the knowledge base after.

The knowledge base IS the documentation. READMEs are quickstart guides only.

## Security Model Design Decisions

### Why no friction-based security
The file guard uses explicit tiers, not pattern interception. If self-modification is enabled, it's all-or-nothing for tier 2. No "dangerous pattern detection" in elisp evaluation, no partial blocks. Rationale: friction gives a false sense of security. It doesn't actually prevent bad actors or hallucinating AI. The flag is the gate. Accept the risk or don't enable it.

### Why container isolation
The container is the current security boundary. Read-only rootfs, dropped capabilities, preflight audit. Outside the container, the tools themselves become the permission model. The file guard was designed for this future -- it works without container isolation.

### Why no cloud
Cloud dependencies mean someone else controls your compute. For an AI agent framework that can modify its own code, send network requests, and execute arbitrary commands, cloud dependency is an unacceptable trust surface. Local LLMs on local hardware, connected via WireGuard, with no external API calls.