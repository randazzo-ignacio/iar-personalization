# Agent Integration Design

## Goal

Allow the SecPlatform frontend to trigger `iar.sh --one-shot` agent scans against assets, with results parsed back into the vulnerabilities table.

## Architecture

```
Frontend (app.i.ar)
  |
  | POST /api/scans/agent { asset_id, scan_type, depth, focus, rate_limit }
  v
BFF (bff-client, in podman container)
  |
  | POST http://10.66.0.5:4700/scan { agent, prompt, project, personalization, timeout }
  v
Agent Runner (host systemd service on sophon, NOT containerized)
  |
  | subprocess: iar.sh --one-shot --agent pentest --prompt "..." --project pentest --personalization /home/nacho/repos/iar-personalization
  v
iar.sh -> podman run (i.ar container with pentest personality)
  |
  | Agent does its thing, produces free-text output
  v
Agent Runner captures stdout, returns to BFF
  |
  | BFF sends output to agent-runner for parsing (second LLM call)
  v
Parsed JSON -> BFF inserts into vulnerabilities table
  |
  v
Frontend polls BFF, sees new vulnerabilities
```

## Components

### 1. Agent Runner (`agent-runner/`)

Location: `~/repos/iar-prod/agent-runner/` (same repo, deployed on host).

A tiny Python or Node HTTP service running directly on sophon (not in a container). Exposes:

```
POST /scan
  Body: {
    agent: "pentest",
    prompt: "...",
    project: "pentest",
    personalization: "/home/nacho/repos/iar-personalization",
    timeout: 300,
    rate_limit: 5
  }
  Response: { job_id: "abc123", status: "queued" }

GET /scan/{job_id}
  Response: {
    status: "running" | "completed" | "failed",
    output: "...",       # raw agent stdout (when completed)
    exit_code: 0         # (when completed/failed)
  }

POST /parse
  Body: { output: "...", asset_id: "...", scan_type: "..." }
  Response: { vulnerabilities: [ { title, severity, description, ... } ] }
```

The `/parse` endpoint runs a second one-shot LLM call (via `iar.sh --one-shot --agent <parser-agent>`) to convert free-text pentest output into structured JSON matching the `vulnerabilities` table schema. Keeps separation of concerns: the pentest agent discovers, the parser agent structures.

**Security:**
- Binds to `10.66.0.5:4700` (WireGuard only, not public)
- Shared secret in env var (`AGENT_RUNNER_SECRET`) -- BFF sends `Authorization: Bearer <secret>`
- Validates agent name against allowlist (only `pentest` for MVP)
- Validates project name against allowlist
- Timeout enforcement (kills subprocess if exceeded)

**Deployment:** systemd service (`agent-runner.service`), deployed by the Ansible `secplatform` role. Runs as `nacho` (needs podman access for `iar.sh`).

**Job tracking:** in-memory dict (ephemeral). If the runner restarts, in-flight jobs are lost. Acceptable for MVP -- the podman container keeps running but the runner loses track. Can add SQLite persistence later.

### 2. BFF Integration (`bff-client/src/routes/`)

New routes in `bff-client`:

**`POST /scans/agent`** -- Create an agent scan job
- Receives: `{ asset_id, scan_type, depth, focus, rate_limit }`
- Loads asset from tenant DB (URL, environment, type, tags)
- Constructs pentest prompt from asset + scan parameters
- Calls agent-runner `POST /scan` with constructed prompt
- Stores `agent_job_id` in `scan_jobs` table
- Returns job info to frontend

**`GET /scans/agent/{job_id}/status`** -- Poll for scan status
- Calls agent-runner `GET /scan/{job_id}`
- If completed: calls agent-runner `POST /parse` with raw output
- Parses JSON response, inserts into `vulnerabilities` table
- Returns status + vulnerability count to frontend

**Prompt construction** (in BFF, not frontend):
```
You are a security researcher. Perform a {scan_type} scan against {asset_url}.

Context:
- Environment: {environment}
- Asset type: {asset_type}
- Testing depth: {depth}
- Focus areas: {focus}

Constraints:
- Rate limit: {rate_limit} seconds between tool calls
- Do not attempt to exploit -- discovery and documentation only
- Document all findings with evidence

Report your findings with: title, severity, description, evidence, CWE if applicable.
```

### 3. Frontend Integration

New UI elements:
- "Run Agent Scan" button on asset detail page
- Scan configuration form: scan type (baseline/deep), depth (standard/deep), focus areas (checkboxes), rate limit (slider or input, default 5s)
- Job status indicator (polling BFF)
- Results display in existing vulnerabilities view

### 4. Database Changes

`scan_jobs` table -- add column:
```sql
ALTER TABLE app.scan_jobs ADD COLUMN IF NOT EXISTS agent_job_id TEXT;
```

No new tables needed. Vulnerabilities go into existing `app.vulnerabilities` table.

### 5. Ansible Role Updates

The `secplatform` role gains:
- Install agent-runner dependencies (Python + Flask, or Node)
- Deploy agent-runner script from repo
- Create `agent-runner.service` systemd unit
- Enable and start the service
- Add `agent-runner` config to sophon host_vars (secret, port, iar.sh path, personalization path)

### 6. Parser Agent

A new agent personality (or reuse existing one) that:
- Receives raw pentest output text
- Returns structured JSON: `[{ "title": "...", "severity": "...", "description": "...", "evidence": "...", "cwe": "..." }]`
- Runs via `iar.sh --one-shot --agent <parser-agent> --prompt "Parse this output into JSON: <output>"`

Could be a simple personality with a strict output format instruction, or we could use a raw LLM call without the full agent infrastructure. TBD during implementation.

## Decisions Log

1. **Agent-runner location:** `~/repos/iar-prod/agent-runner/` (same repo)
2. **Deployment:** systemd service on host (not containerized), deployed by Ansible
3. **Model selection:** use default (no `--model` flag). Add selector later.
4. **Output parsing:** second LLM call (separation of concerns). Agent discovers, parser structures.
5. **Rate limiting:** user-configurable in frontend, passed through to `iar.sh --rate-limit`

## Open Questions (for implementation phase)

- Python or Node for agent-runner? (BFF is Node, but agent-runner is independent)
- Parser agent: new personality or raw LLM call?
- How to handle long-running scans (timeout, partial results)?
- Error handling: what if the pentest agent produces no output, or crashes?
- Audit logging: should agent scans be logged in `audit_log`?