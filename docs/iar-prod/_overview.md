# iar-prod Overview

## What iar-prod Is

SecPlatform -- a multi-tenant SaaS PoC for vulnerability management and asset scanning. Frontend for the i.ar SaaS idea. Originally developed by a friend on their infrastructure (SL437, dellasantina.com.ar), now adapted to run on our infra.

Repo at `/var/home/nacho/repos/iar-prod/` (bind-mounted into i.ar container). GitHub: `github.com/randazzo-ignacio/i.ar` (shared with the i.ar repo name).

## Our Hosting Model

SecPlatform prod runs on **sophon** (10.66.0.5, 12c/96GB, RTX 3080) via **podman compose**. **Caddy** on **rammstein** (10.66.0.1, public IP) terminates TLS and reverse-proxies over WireGuard to sophon.

No Cloudflare. No CI/CD (manual deploy via Ansible). No external mailer (MVP has no email; MailHog disabled in prod).

### URL Structure

| Domain | Service | Caddy Proxy Target |
|--------|---------|-------------------|
| `i.ar` | Landing page (existing) | Existing Caddy config |
| `app.i.ar` | Customer portal (frontend-client + bff-client) | `10.66.0.5:8091` |
| `app-bo.i.ar` | Back-office (frontend-backoffice + bff-backoffice) | `10.66.0.5:8092` |
| `auth.i.ar` | Keycloak | `10.66.0.5:8080` |

### Network Flow

```
Browser -> Caddy (rammstein, TLS) -> WireGuard -> sophon (10.66.0.5)
  app.i.ar     -> frontend-client:8091 (Nginx -> bff-client:3001)
  app-bo.i.ar  -> frontend-backoffice:8092 (Nginx -> bff-backoffice:3002)
  auth.i.ar    -> keycloak:8080
```

All services bind to `10.66.0.5` (WireGuard IP), not `0.0.0.0`. Only rammstein can reach them.

### OIDC Auth Flow

1. Browser -> `app.i.ar/api/auth/login` (Caddy -> Nginx -> BFF)
2. BFF redirects to `auth.i.ar/realms/customers/protocol/openid-connect/auth`
3. User logs in at Keycloak (Caddy -> Keycloak)
4. Keycloak redirects back to `app.i.ar/api/auth/callback?code=...`
5. BFF exchanges code internally (`http://keycloak:8080` on docker network) for tokens
6. BFF sets httpOnly cookies, redirects to portal

No CORS issues -- BFF handles everything server-side. Frontend just does `location.href = '/api/auth/login'`.

## Container Runtime: Podman (not Docker)

The stack runs on **podman compose** with **docker-compose v2** (Go binary) as the compose provider. This was necessary because:

- **podman-compose** (Python, v1.6.0) doesn't support `depends_on` with `condition: service_healthy` -- containers with dependencies fail to start.
- **docker-compose v2** (Go binary) handles healthcheck conditions correctly. `podman compose` uses it as the provider when found in PATH.
- docker-compose v2 connects to podman via the Docker-compatible socket API (`podman.socket`, systemd socket activation).

The Ansible `secplatform` role installs docker-compose v2 binary at `/usr/local/bin/docker-compose` and enables `podman.socket` (system + user).

### Podman-Specific Fixes Applied

1. **SELinux labels on bind mounts**: Added `:z` flag to all host bind mounts in `docker-compose.yml` (keycloak/realms, keycloak/themes, postgres/init). Without this, SELinux blocks containers from reading host-mounted directories.

2. **Nginx DNS resolution**: Removed Docker-specific `resolver 127.0.0.11` directive from frontend nginx configs. Podman uses `aardvark-dns` at the network gateway (e.g. `10.89.0.1`), not Docker's `127.0.0.11`. Switched to direct `proxy_pass` with static upstream names -- nginx resolves at startup via `/etc/resolv.conf`.

3. **DOCKER_HOST environment**: The systemd service and `spc.sh` set `DOCKER_HOST=unix:///run/podman/podman.sock` (system) or `unix:///run/user/$(id -u)/podman/podman.sock` (user) so docker-compose v2 connects to podman's socket.

4. **Root podman context**: The stack runs as root (via system podman socket), not rootless. This matches the pattern used by frigate and monitoring roles. All containers, volumes, and images live in root's podman storage.

## Architecture

```
Frontends (Nginx)     frontend-client :8091    frontend-backoffice :8092
       |                    |                           |
       v                    v                           v
BFFs (Node.js/Express) bff-client :3001     bff-backoffice :3002
       |                    |                           |
       +---- OIDC ----> Keycloak :8080 <----+------+
       |                    |                     |
       v                    v                     v
  Postgres BFF :5432    Postgres KC (internal)   MailHog (disabled in prod MVP)
  (control-plane +     (Keycloak DB)
   tenant DBs)
       |
       v
  Scanner Worker (background, filesystem-based job queue)
```

## Services (docker-compose.yml)

| Service | Image | Purpose |
|---------|-------|---------|
| postgres-keycloak | postgres:16-alpine | Keycloak internal DB |
| keycloak | quay.io/keycloak/keycloak:26.7.0 | Identity Provider (OIDC) |
| postgres-bff | postgres:16-alpine | Control-plane DB + per-tenant DBs |
| bff-client | Build local (Node 20) | API for customer portal |
| bff-backoffice | Build local (Node 20) | API for back-office |
| frontend-client | Build local (Nginx) | SPA customer portal |
| frontend-backoffice | Build local (Nginx) | SPA back-office |
| scanner-worker | Build local (Node 20) | Background scan worker |
| mailhog | mailhog/mailhog:latest | SMTP testing (dev only, disabled in prod MVP) |

## Multi-Tenant Model

- **Physical DB separation**: each tenant gets its own PostgreSQL database (`tenant_<tid>`) with its own role (`tenant_<tid>`).
- **Control-plane DB** (`bff_control_plane`): stores `tenants` registry, `audit_log`, `user_invites`, lifecycle tables.
- **Tenant DBs**: store `app.assets`, `app.vulnerabilities`, `app.scan_jobs`, `app.vpns`, `app.esam_config`, `app.esam_discoveries`, `app.federation_config`, `app.audit_log`.
- **Filesystem isolation**: each tenant has a volume at `/tenants/<tid>/` with `assets/`, `vpns/`, `findings/`, `evidence/`, `secrets/`, `audit/`, `jobs/{queued,claimed,running,completed,failed}`.
- **Tenant context**: BFF-client middleware reads `X-Active-Tenant` header, validates against JWT `tenant_ids` claim, resolves to per-tenant DB pool.

## Keycloak Realms

| Realm | Purpose | Roles |
|-------|---------|-------|
| `customers` | Tenant user auth | tenant-owner, asset-operator, asset-auditor, vulnerability-manager, report-viewer |
| `backoffice` | Internal staff auth | owner-backoffice, organization-provisioner, triage-lead, triage-analyst, billing-manager, support-readonly |

JWT claims: `tenant_ids` (multivalued, customers only), `roles` (realm roles), `scope_type` (hardcoded: `tenant` for customers, `backoffice` for BO).

Realm redirect URIs (prod):
- customers: `https://app.i.ar/api/auth/callback`
- backoffice: `https://app-bo.i.ar/api/auth/callback`

## Environments

| Env | Compose Project | Host | Key Overrides |
|-----|----------------|------|---------------|
| prod | sp-prod | sophon (10.66.0.5) | KC `start` (production mode), Caddy TLS, MFA OFF (MVP), no email |
| dev | sp-dev | sophon (10.66.0.5) | KC `start-dev`, MailHog, MFA OFF, debug logging |
| local | sp-local | sophon (10.66.0.5) | KC `start-dev` with `/kc` relative path, MailHog, MFA OFF |

Wrapper: `./spc.sh {prod|dev|local} <compose-cmd>`. Uses docker-compose v2 if available, falls back to `podman compose`.

Only prod is internet-facing (via Caddy on rammstein). Dev/local are WireGuard-only.

## Ansible Deployment

The `secplatform` Ansible role in `iar-infrastructure` manages the deployment:

1. Installs docker-compose v2 binary
2. Enables podman sockets (system + user)
3. Clones the repo from the git bare repo on rammstein
4. Creates `.env` and tenant directories (non-interactive, replaces `setup.sh`)
5. Ensures scripts are executable
6. Creates a systemd service (`secplatform-prod.service`)
7. When `secplatform_rebuild: true`: stops service, tears down containers, rebuilds images, restarts

Playbook: `ansible-playbook playbooks/secplatform.yml --ask-vault-pass`

Host vars (sophon): `secplatform_enabled`, `secplatform_repo_url`, `secplatform_deploy_dir`, `secplatform_env`, `secplatform_rebuild`.

## MVP Status

- No email (invite/reset flows will fail silently; users created manually in KC admin)
- No MFA (disabled, can enable later)
- No CI/CD (Ansible manual deploy)
- No Cloudflare (Caddy handles TLS directly with ACME)
- Seed users exist in realm JSONs (poc.acme, operator.globex, etc.)

## Security Model

1. **Container hardening**: BFFs and scanner have `no-new-privileges:true`, `cap_drop: ALL`.
2. **Tenant isolation**: physical DB per tenant + JWT `tenant_ids` validation (fail-closed 403).
3. **RBAC**: role-based permission maps in middleware (client and BO have separate permission sets).
4. **Audit logging**: all significant actions logged to `audit_log` table (control-plane).
5. **IDOR protection**: 3-layer -- middleware validates tenant membership, queries use tenant-scoped pool, ABAC for user operations.
6. **MFA**: TOTP + WebAuthn (passkey), env-flag controlled per realm. Disabled for MVP.
7. **Email**: not configured for MVP. MailHog available in dev/local.

## Seed Tenants

| tenant_id | Display | Plan | Domains | POC Email |
|-----------|---------|------|---------|-----------|
| acme | Acme Corp | enterprise | acme.com | poc.acme@customers.local |
| globex | Globex S.A. | pro | globex.com | poc.globex@customers.local |

## Tech Stack

- Node.js 20, Express, Helmet, pino (logging)
- PostgreSQL 16 (alpine)
- Keycloak 26.7.0 (OIDC, token-exchange, admin-fine-grained-authz)
- Nginx (SPA serving + API proxy)
- Podman + docker-compose v2 (multi-env via compose overrides)
- Vanilla JS frontends (no framework)

## Full Docs

architecture.md (service architecture, data model), security.md (tenant isolation, RBAC, audit), api.md (BFF endpoints), deployment.md (compose, Ansible, environments), modules.md (shared library, services).