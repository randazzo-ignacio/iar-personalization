# Life Organization Integration

## Overview

The life-org container provides agents with access to personal financial data (hledger), inventory, and routine tracking. All access is via `execute_code_remote(target="life-org", command="...")`. No new Elisp tools -- everything through the container.

## Container

- **Image:** `iar-life-org` (built from `containers/images/life-org/Containerfile`)
- **Network:** none (no outbound internet)
- **Tools:** hledger, Ruby, jq, bash
- **User:** lifeorg (unprivileged)
- **Mounts:** `/workspace` (shared with Emacs container), `/life-org` (personal data, future)

## File Locations

Personal data files live in the personalization repo. The container accesses them via the shared workspace or a dedicated mount (configured via `#+MOUNTS` in project files or `--mount` on iar.sh).

### hledger Journal

- **Location:** `personalization/life-org/finance/journal.journal` (or `.hledger` directory)
- **Format:** hledger plain-text accounting format
- **Usage:** `hledger -f /path/to/journal.journal balance`, `hledger -f /path/to/journal.journal register`

### Inventory

- **Location:** `personalization/life-org/inventory/` (directory with YAML/JSON files)
- **Format:** Structured files (one per category: electronics, tools, books, etc.)
- **Usage:** Read files, parse with jq or Ruby, query by category or item

### Routines

- **Location:** `personalization/life-org/routines/` (directory with org/markdown files)
- **Format:** Org-mode or markdown checklists with timestamps
- **Usage:** Read files, surface due/overdue items

## Querying via Agent

Agents query the life-org container using `execute_code_remote`:

```
# Financial balance check
execute_code_remote(target="life-org", command="hledger -f /life-org/finance/journal.journal balance")

# Specific account register
execute_code_remote(target="life-org", command="hledger -f /life-org/finance/journal.journal register expenses:food --depth 2")

# Inventory check
execute_code_remote(target="life-org", command="cat /life-org/inventory/electronics.yaml")

# Routine items due
execute_code_remote(target="life-org", command="cat /life-org/routines/maintenance.org")
```

## Project Configuration

To use the life-org container, a project file must declare it:

```
#+CONTAINERS: life-org
#+KNOWLEDGE: life-org/ iar/
#+OBJECTIVE: Life organization and personal finance management.
```

## Security

- No outbound internet -- container cannot exfiltrate data
- Unprivileged user -- cannot escalate privileges
- No personalization mount by default -- data must be explicitly mounted via `#+MOUNTS` or `--mount`
- The container only has access to what is explicitly mounted into it