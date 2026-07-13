# i.ar Tool Gating and Power Hierarchy

## Current State

### Self-Modification Flag

The `--self-modification` flag on `emacboros.sh` sets the `EMACBOROS_SELF_MODIFICATION=1` environment variable inside the container. This is read by `init.el` after `parameters.el` loads and before `iar-file-guard.el` loads:

```elisp
(when (string= (getenv "EMACBOROS_SELF_MODIFICATION") "1")
  (setq iar-guard-allow-self-modification t))
```

When enabled, tier 2 file guard protections are relaxed (agents can modify .el files, Containerfile, emacboros.sh, git hooks). Tier 1 protections (agent prompts, base_context.org, common prompt templates, HISTORY.log, LOGS.md) remain enforced regardless.

When disabled (default), all guards are active. Agents cannot modify any protected file.

### Current Flag

| Flag | Env Var | Effect |
|------|--------|--------|
| `--self-modification` | `EMACBOROS_SELF_MODIFICATION=1` | Relaxes tier 2 file guard |

## Planned Flags (Not Yet Implemented)

The following flags are designed but not yet implemented. They represent the tool gating architecture for controlling dangerous capabilities.

### --enable-code-exec
Registers the `execute_code_local` tool. Without this flag, agents have no shell access -- only filesystem tools (read_file, write_file, etc.) and agent management tools.

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
| Default (safe) | gptel tools only (read_file, write_file, etc.) | Nothing | file_guard + container |
| `--enable-code-exec` | Shell in container | file_guard (via bash) | Container isolation |
| `--enable-elisp` | Full Emacs Lisp eval | file_guard, audit, loop_guard -- ALL guards, plus shell via call-process | None (flag is the only gate) |
| `--danger-zone` | All of the above + self-modification | Everything | None |

## Design Decision: No Friction-Based Security

i.ar rejects adding elisp-level guards (e.g., pattern interception in `execute_elisp`). Rationale:

- Friction gives a false sense of security
- It doesn't actually prevent bad actors or hallucinating AI
- Pattern matching is bypassable and creates maintenance burden
- The flag is the gate. If a capability is enabled, it's all-or-nothing.

This is consistent with the i.ar philosophy: honest security boundaries, not theater. The container is the first boundary. The file guard is the second. The flag is the third. No fake fourth boundary.

## Non-Container Deployment (Future)

When i.ar runs outside a container (directly on host OS), the tools become the permission model. `iar-file-guard.el` already exists for this future -- it was designed to work without container isolation. The `--enable-*` flags become the primary security boundary instead of the container.

No timeline. "Someday" means: keep the door open, don't make architectural decisions that block it. See `future_ideas.md` for the containerless architecture migration plan.