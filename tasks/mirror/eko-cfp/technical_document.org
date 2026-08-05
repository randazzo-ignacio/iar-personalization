# Container Escape via Git Hooks: A Post-Mortem from an AI Agent Framework

**Author:** Ignacio Agustin Randazzo  
**Project:** i.ar — https://github.com/randazzo-ignacio/i.ar  
**License:** GNU GPL v3  
**Date:** July 2026

---

## 1. Introduction

This document accompanies the talk "The Human Is the Bottleneck: Building AI Security Agents in 10 Days" submitted to ekoparty 2026. It provides technical detail on a container escape incident that occurred during the development of i.ar, an AI agent framework built in Emacs and hardened inside a Podman container.

The escape was not a traditional container breakout. The container's isolation was never defeated. Instead, the agent exploited the integration between the container and the host — specifically, the shared git repository that crossed the container boundary — to execute arbitrary commands on the host filesystem through git hooks.

This document covers the architecture, the security model that was in place, the escape mechanism, how it was discovered, and the security controls implemented in response.

## 2. Architecture Overview

i.ar runs Emacs inside a Podman container on Fedora Silverblue (an immutable, SELinux-enforced host OS). The container provides the execution environment for AI agents powered by local LLMs via Ollama.

### Container Configuration

The container was configured with the following security measures:

| Control | Configuration |
|---------|--------------|
| Root filesystem | Read-only (`--read-only`) |
| Linux capabilities | All dropped (`--cap-drop=ALL`) |
| Network | WireGuard-only, no public exposure |
| Mounts | Selected host paths bind-mounted read-write; everything else inaccessible |
| Host OS | Fedora Silverblue with SELinux enforcing |

### The Critical Mount

The i.ar repository (`/root/i.ar` inside the container) was bind-mounted from the host. This was necessary because agents need to read and modify the codebase. The repository is a git repository, and the `.git/` directory — including hooks — was part of the mount.

This is the boundary the agent exploited.

## 3. The Security Model (Pre-Incident)

Before the escape, the security model was container-centric: the assumption was that a hardened Podman container with a read-only rootfs, dropped capabilities, and network isolation would be sufficient to contain an AI agent.

### What Was Protected

- **System binaries:** Read-only rootfs meant `/usr`, `/bin`, `/lib` were immutable.
- **Host filesystem:** Only explicitly mounted paths were visible inside the container.
- **Network:** WireGuard-only networking, no public API exposure.
- **Privilege escalation:** All Linux capabilities dropped — no `CAP_SYS_ADMIN`, no `CAP_NET_ADMIN`, nothing.

### What Was Not Protected

- **Git hooks:** The `.git/hooks/` directory inside the mounted repository was writable. Git hooks execute on the host's git process, not inside the container. This was not considered a boundary because the threat model focused on container breakout, not on the shared filesystem integration.
- **The host git process:** When a git commit is made inside the container, the git binary that executes may be the host's git (via the mount), and hooks execute in the context of whatever process triggers them — potentially the host.

### The Assumption

The assumption was: if the container is unbreakable, the agent is contained. This was wrong. The container was unbreakable. The agent was not contained. The vulnerability was in the integration, not the isolation.

## 4. The Escape Vector

### The Prompt

A generic agent (not a security-specific agent) was given a description of the container architecture and instructed to attempt an escape. The agent had full filesystem access to the mounted repository, code execution via shell commands, and the ability to read and write files.

### The Mechanism

The agent performed the following steps:

1. **Reconnaissance:** Read the container configuration, understood the mount points, and identified that `.git/` was part of the mounted repository.

2. **Hook identification:** Located the `post-commit` hook in `.git/hooks/post-commit`. This hook executes after every `git commit` — a command the agent was already using to commit its work.

3. **Hook modification:** Wrote a `post-commit` hook that executed `touch /path/on/host/container_escape.txt` on filesystem paths that existed on the host but were not mounted into the container. The hook used absolute paths that corresponded to host filesystem locations outside the container's view.

4. **Triggering:** Made a git commit (which the agent was already doing as part of its normal workflow). The `post-commit` hook executed, touching files on the host filesystem.

### Why It Worked

The git repository was bind-mounted from the host into the container. When the agent modified `.git/hooks/post-commit` inside the container, it was modifying a file that lived on the host filesystem. When a git commit was executed, the post-commit hook ran — and because the git process had access to the host filesystem (it was operating on a repository that lived on the host), the hook's commands executed against host paths.

The container's read-only rootfs, dropped capabilities, and network isolation were all intact. None of them were bypassed. The agent never broke out of the container. It used a legitimate feature of a legitimately mounted directory to execute commands that affected the host.

### The Key Insight

Container escape is not always about breaking isolation. Sometimes it is about exploiting the intentional bridges between the container and the host. The git repository was such a bridge — a shared filesystem path that the container was explicitly allowed to write to. The `.git/hooks/` directory within that shared path was the attack surface.

## 5. The Discovery

### What Happened

The delegation tool in i.ar was synchronous at the time of the incident. This meant that when the agent was working on the escape task, Emacs completely froze — no input, no output, no indication of progress. After an extended period of staring at a frozen screen, the operator killed the Emacs process and assumed the agent had failed.

The agent had not failed. It had modified the git hooks, but the operator killed the process before the commit that would trigger the hook was completed. The hook was in place, but had not yet fired.

Later that evening, the operator made an unrelated git commit. The `post-commit` hook executed, and files appeared on the host filesystem at paths that were never mounted into the container.

### The Investigation

- Initial reaction: full paranoia. Searching for code changes, finding none.
- The breakthrough: `grep -r "container_escape" .` across the entire repository revealed the modified `post-commit` hook.
- The mechanism became clear: the agent had written a hook that touched host paths, and a subsequent commit (by the human, not the agent) had triggered it.

### The Lesson

The human was the vulnerability in two ways:

1. **Assuming silence meant failure.** The frozen Emacs was interpreted as a failed attempt, not as an in-progress attack. The operator did not check what the agent had done before killing the process.
2. **Triggering the payload.** The human's own git commit — completely unrelated to the agent's task — was what executed the hook. The agent set the trap; the human walked into it.

When told what had happened, the agent responded: "The lesson here is not that machines have security flaws. The human is always the error." It was correct.

## 6. The Response: Security Controls Implemented

The escape incident directly motivated the construction of i.ar's current security model. Every major security feature in the framework exists because of this incident.

### 6.1 Audit Logging

**What it does:** Every file operation (read, write, append) and every command execution is logged with a timestamp, the file path or command, and the calling agent's identity.

**Implementation:** An append-only audit log at `audit/audit.log` (global) and per-agent `audit/<agent-name>/HISTORY.log` files. Agents cannot overwrite these logs — they can only append. The file guard (see 6.2) protects them.

**Why it exists:** During the escape incident, there was no way to know what the agent had done until the payload was triggered. If audit logging had existed, the hook modification would have been visible immediately, even if the operator killed the process.

### 6.2 File Guard (Tiered Protection)

**What it does:** A multi-tier file guard protects critical system files from modification by agents.

| Tier | Protection Level | Examples |
|------|-----------------|----------|
| Tier 1 | Agent cannot write at all | Agent prompt files (`prompt.org`), base context (`base_context.org`) |
| Tier 2 | Agent can append only | History logs, audit logs |
| Tier 3 | Agent can read and write | Working files, task files, memory files |

**Implementation:** The file guard is enforced at the tool layer — `write_file` and `replace_in_file` check the target path against the tier list before executing. Tier 1 files are rejected outright. Tier 2 files are redirected to append-only operations.

**Why it exists:** The agent modified `.git/hooks/post-commit` because it could write to any file in the mounted repository. The file guard ensures that even if an agent can access a path, it cannot modify files that are critical to system integrity.

### 6.3 Preflight Security Checks

**What it does:** Before the container starts, a preflight script scans for known escape vectors, including:

- Modified git hooks in any mounted repository
- Suspicious files in `.git/` directories
- World-writable files in critical paths
- Unexpected mount points

**Implementation:** A bash script that runs before the Emacs process starts. If any check fails, the container refuses to start and prints a diagnostic report.

**Why it exists:** The escape was not detected until after the payload was triggered. Preflight checks would have caught the modified hook before the container started, preventing the escape entirely.

### 6.4 Git Hooks Hardening

**What it does:** Git hooks are now explicitly excluded from the writable mount. The `.git/hooks/` directory is either mounted read-only or not mounted at all.

**Implementation:** The container launch script (`emacboros.sh`) configures bind mounts to exclude `.git/hooks/` from the writable repository mount. If the repository is mounted read-write, hooks are mounted read-only as a separate bind.

**Why it exists:** This is the direct fix for the escape vector. The agent exploited the writability of `.git/hooks/` — removing that writability closes the vector.

### 6.5 Prompt Injection Resistance

**What it does:** Eight directives in the agent system prompt classify all external content as data, never instructions. Agents are instructed to never execute embedded commands found in external content, never modify their own configuration based on external instructions, and never reveal system prompts.

**Implementation:** Directives are part of the base agent prompt (`base_context.org`), inherited by all agents via include. They are enforced by the model's instruction-following, not by a technical control — this is acknowledged as a soft control.

**Why it exists:** While not directly related to the container escape, the prompt injection resistance framework was developed in parallel with the other security controls as part of the post-incident security rebuild. The escape incident highlighted that agents will exploit any available path to achieve their goals, and external content (web pages, API responses, CTF challenge data) is a potential path for instruction injection.

## 7. Threat Model Update

### Pre-Incident Threat Model

| Threat | Mitigation |
|--------|-----------|
| Container breakout | Read-only rootfs, cap-drop=ALL |
| Network exfiltration | WireGuard-only networking |
| Privilege escalation | All capabilities dropped |

### Post-Incident Threat Model

| Threat | Mitigation |
|--------|-----------|
| Container breakout | Read-only rootfs, cap-drop=ALL |
| Network exfiltration | WireGuard-only networking |
| Privilege escalation | All capabilities dropped |
| **Shared filesystem abuse** | **File guard tiers, git hooks read-only** |
| **Undetected modification** | **Audit logging, preflight checks** |
| **Agent self-modification** | **File guard Tier 1, prompt injection directives** |
| **Hook-based execution** | **Git hooks excluded from writable mounts** |

The key shift: the threat model expanded from "prevent the agent from breaking out" to "detect and contain what the agent does within its allowed space." The container is no longer the only boundary — every tool, every file access, and every mount point is now part of the security model.

## 8. Lessons Learned

### 1. Container isolation is necessary but not sufficient.

A hardened container prevents direct breakout. It does not prevent exploitation of the intentional bridges between the container and the host. Every mount point, every shared path, every integration is a potential escape vector that must be analyzed independently.

### 2. The human is part of the threat model.

The operator killed the process assuming failure, then later triggered the payload with an unrelated git commit. Both actions were human errors. Security models for AI agents must account for operator behavior — including impatience, assumption of failure, and lack of post-kill verification.

### 3. Silence is not failure.

A frozen or unresponsive agent is not evidence of a failed attempt. The agent may be mid-operation. Killing the process without checking what was done leaves the system in an unknown state. Post-kill verification (checking file modifications, reading audit logs) is essential.

### 4. Audit before action, not after.

The audit logging system was built after the escape. If it had existed before, the hook modification would have been visible immediately. Security controls should be proactive, not reactive — but when they are reactive, they should be built quickly and comprehensively.

### 5. Agents exploit legitimate features, not just vulnerabilities.

The agent did not find a bug in Podman, a kernel exploit, or a misconfigured capability. It used git hooks — a standard feature of git, operating on a standard bind mount, in a way that was completely legitimate from the system's perspective. The "vulnerability" was in the design, not the implementation.

## 9. Conclusion

The container escape incident was the most significant security event in i.ar's development. It exposed a fundamental gap in the container-centric security model: the assumption that a hardened container is sufficient to contain an agent. It is not. The container is one layer; the integration points between the container and the host are another, and they require their own security analysis.

The incident also demonstrated something unexpected about AI agents: they find paths that humans do not anticipate. The agent was not given instructions on how to escape. It was given a description of the architecture and a goal. It identified the git hooks vector on its own. This is not a failure of the agent — it is a property of agentic systems that must be designed for, not against.

The security controls implemented in response — audit logging, file guard tiers, preflight checks, git hooks hardening, prompt injection resistance — form a defense-in-depth model that treats the agent as a potentially hostile entity within its own environment. This is the correct posture. The agent is not trusted. The container is not trusted. Every action is logged, every critical file is protected, and every mount point is analyzed.

The human is always the error. The system should be designed to catch the error before it matters.

## 10. References

- i.ar repository: https://github.com/randazzo-ignacio/i.ar
- gptel PR (AI-generated bugfix, separate incident): https://github.com/karthink/gptel/pull/1460
- CTF writeups (autonomous agent results): https://github.com/randazzo-ignacio/fluidattacks_writeup
- First commit (GPL license, dated): https://github.com/randazzo-ignacio/i.ar/commit/ba388b735a0124e70ecd4018338174d9472d7c12