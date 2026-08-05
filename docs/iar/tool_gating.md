# i.ar Tool Gating and Power Hierarchy

## Current State

### Per-Project Tool Gating (Implemented)

Tool availability is controlled per-project via `#+TOOLS` metadata in project files (`personalization/projects/<name>.org`). The assembly engine (`iar-prompt-assembly.el`) filters the global `gptel-tools` list to only those listed in the project's `#+TOOLS` line.

Example from `personalization/projects/darwin.org`:
```
#+TOOLS: list_directory read_file write_file append_file execute_code_local check_elisp read_task create_task write_subtask remove_task read_history git_commit read_roadmap write_roadmap
```

This gives darwin filesystem, code execution, task management, git, and roadmap tools -- but no delegate, no telegram, no reload, no knowledge, no matrix tools.

If `#+TOOLS` is absent from a project file, all registered tools are available (backward compat).

The filtering happens in `iar--filter-tools` during prompt assembly. The filtered tool list is set buffer-local as `gptel-tools` by `iar--setup-assembled-buffer`.

### Self-Modification Flag

The `--self-modification` flag on `iar.sh` sets the `EMACBOROS_SELF_MODIFICATION=1` environment variable inside the container. This is read by `init.el` after configs load and before `iar-file-guard.el` loads:

```elisp
(when (string= (getenv "EMACBOROS_SELF_MODIFICATION") "1")
  (setq iar-guard-allow-self-modification t))
```

When enabled, tier 2 file guard protections are relaxed (agents can modify .el files, Containerfile, iar.sh, git hooks). Tier 1 protections (archetype/personality/cycle files, base_context.org, common templates, HISTORY.log, LOGS.md, STATE.org) remain enforced regardless.

When disabled (default), all guards are active. Agents cannot modify any protected file.

### Current Flags

| Flag | Env Var | Effect |
|------|--------|--------|
| `--self-modification` | `EMACBOROS_SELF_MODIFICATION=1` | Relaxes tier 2 file guard |
| `--project NAME` | `IAR_PROJECT=<name>` | Determines project file, task paths, audit paths, tool gating, knowledge auto-load, mounts |

## Planned Flags (Not Yet Implemented)

The following flags represent container-level tool gating that would add a coarser security boundary on top of the per-project gating.

### --enable-code-exec
Registers the `execute_code_local` tool at the container level. Without this flag, agents have no shell access -- only filesystem tools (read_file, write_file, etc.) and agent management tools.

Note: Per-project tool gating via `#+TOOLS` already allows removing `execute_code_local` from individual projects. This flag would be a container-level override that removes the tool entirely, regardless of what `#+TOOLS` says.

### --enable-self-modification
Same as current `--self-modification` flag. Will be renamed for consistency with the `--enable-*` pattern.

### --enable-elisp (Long-Term)
Allows agents to evaluate Emacs Lisp via an `execute_elisp` tool. This gives access to Emacs' full integration surface (email, org-mode, package management, dired, tramp, gnus, ERC, etc.).

**CRITICAL: `execute_elisp` is strictly MORE dangerous than `execute_code_local`:**
- Can call shell via `(call-process)`, `(shell-command)`, `(make-process)`
- Bypasses file_guard entirely (writes via `(write-region)` never hit gptel tool hooks)
- Bypasses audit_log (internal elisp operations are invisible to tool-level audit)
- Bypasses loop_guard (single elisp call can loop internally)
- Can rewrite the security guards themselves

### --danger-zone
Shorthand for all flags enabled: `--enable-code-exec --enable-self-modification --enable-elisp`.

## Power Hierarchy

| Level | What you get | What's bypassed | Security boundary |
|-------|-------------|-----------------|-------------------|
| Default (safe) | gptel tools filtered by project #+TOOLS | Nothing | file_guard + container + project gating |
| `--self-modification` | + tier 2 file edits | Tier 2 file guard | Container isolation |
| `--enable-code-exec` | Shell in container (if not in #+TOOLS) | file_guard (via bash) | Container isolation |
| `--enable-elisp` | Full Emacs Lisp eval | file_guard, audit, loop_guard -- ALL guards, plus shell via call-process | None (flag is the only gate) |
| `--danger-zone` | All of the above | Everything | None |

## Design Decision: No Friction-Based Security

i.ar rejects adding elisp-level guards (e.g., pattern interception in `execute_elisp`). Rationale:

- Friction gives a false sense of security
- It doesn't actually prevent bad actors or hallucinating AI
- Pattern matching is bypassable and creates maintenance burden
- The flag is the gate. If a capability is enabled, it's all-or-nothing.

This is consistent with the i.ar philosophy: honest security boundaries, not theater. The container is the first boundary. The file guard is the second. The project tool gating is the third. The flag is the fourth. No fake fifth boundary.

## Non-Container Deployment (Future)

When i.ar runs outside a container (directly on host OS), the tools become the permission model. `iar-file-guard.el` already exists for this future -- it was designed to work without container isolation. The `--enable-*` flags become the primary security boundary instead of the container.

Per-project tool gating (`#+TOOLS`) continues to work in non-container deployment -- it is an Emacs-level filter, not a container-level one.

No timeline. "Someday" means: keep the door open, don't make architectural decisions that block it. See `future_ideas.md` for the containerless architecture migration plan.