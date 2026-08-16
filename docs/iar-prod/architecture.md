# Architecture

## Service Topology

All services run on a single Docker bridge network (`spnet`). No service is exposed to the internet directly -- in production, Cloudflare proxies to the appropriate ports.

### Request Flow

1. User hits frontend (Nginx SPA) -> static HTML/JS/CSS served.
2. SPA calls BFF API endpoints (same origin via Nginx proxy or direct port).
3. BFF validates JWT (from cookie `sp_at` / `sp_bo_at` or `Authorization: Bearer`).
4. BFF validates tenant context (client only: `X-Active-Tenant` header).
5. BFF queries control-plane DB and/or per-tenant DB.
6. Scanner worker polls filesystem job queues per tenant.

### BFF-Client (port 3001)

Customer-facing API. Realm: `customers`.

**Middleware chain**: cookie-parser -> helmet -> cors -> express.json -> pino-http -> auth (JWT verify, realm=customers, scope=tenant) -> tenant-context (X-Active-Tenant validation) -> audit.

**Routes**:
- `GET /health` -- health check
- `/auth` -- OIDC login/callback/logout (Keycloak authorization code flow)
- `GET /me` -- current user profile
- `GET /me/tenants` -- tenants accessible by current user
- `/tenants/*` -- tenant-scoped operations (assets, vulnerabilities, scans, ESAM)
- `/users` -- user management within tenant (invite, reset password, delete)
- `/federation` -- Entra ID (Azure AD) federation config per tenant
- `/vpns` -- VPN configuration per tenant
- `/esam` -- External Surface Attack Management (discoveries, config, approvals)
- `GET /version` -- build info

**Services**:
- `findingsImporter` -- polls tenant findings directories, imports into DB (interval-based).
- `inviteTracker` -- tracks invitation emails, derives user status (invitacion_enviada, reset_enviado, enlace_vencido, pass_configurado, pendiente, activo).
- `kcUsers` -- Keycloak admin operations for customer realm users (with ABAC via `assertUserInTenant`).
- `jobEnqueue` -- creates scan jobs in tenant filesystem queue.

### BFF-Backoffice (port 3002)

Internal staff API. Realm: `backoffice`.

**Middleware chain**: cookie-parser -> helmet -> cors -> express.json -> pino-http -> auth (JWT verify, realm=backoffice, scope=backoffice) -> audit.

**Routes**:
- `GET /health` -- health check
- `/auth` -- OIDC login/callback/logout
- `/organizations` -- CRUD for tenants (provision, deprovision, lifecycle)
- `/triage` -- vulnerability triage queue and actions across tenants
- `/tenant/:tid/*` -- cross-tenant data access (assets, vulnerabilities) with check middleware
- `/bo-users` -- back-office user management
- `/audit-log` -- audit log queries
- `/billing` -- billing/plan management
- `/support` -- support operations (reset POC password, replace POC)

**Services**:
- `tenantProvisioner` -- creates new tenants (DB, role, volume, Keycloak realm config, seed data). Idempotent.
- `inviteTracker` -- same as client, shared table.
- `kcBackofficeUsers` -- Keycloak admin for backoffice realm users.
- `applyRealmConfig` -- idempotent realm configuration (SMTP, MFA flags, redirect URIs, protocol mappers, event listeners).
- `lifecycle` -- unified identity + membership lifecycle (DB = source of truth, KC = projection).

### Scanner Worker

Filesystem-based job queue processor. No DB access.

1. Polls `/tenants/<tid>/jobs/queued/` every 3s.
2. Claims job (rename queued -> claimed -> running).
3. Simulates scan (5s delay).
4. Generates findings from a static vulnerability bank (randomized selection by focus area).
5. Writes findings to `/tenants/<tid>/findings/<job_id>/findings.json`.
6. Moves job to `completed/`.

**Vulnerability bank categories**: auth, injection, business_logic (IDOR), api, xss, ssrf.

### Frontends

Vanilla JS SPAs served by Nginx. No build step.

**frontend-client**: Customer portal with views for dashboard, assets, vulnerabilities, scans, users, ESAM, federation, VPNs.

**frontend-backoffice**: Back-office portal with views for overview, organizations, triage, audit, billing, BO users, support, manual vulnerability entry.

## Data Model

### Control-Plane DB (`bff_control_plane`)

```
tenants
  tenant_id TEXT PK
  display_name TEXT
  plan TEXT (trial|pro|enterprise)
  status TEXT (active|suspended|deleted)
  volume_path TEXT
  db_name TEXT
  db_user TEXT
  authorized_domains TEXT[]
  poc_email TEXT
  runs_included INT
  runs_consumed INT
  assets_licensed INT
  created_at / updated_at TIMESTAMPTZ

audit_log
  id BIGSERIAL PK
  ts TIMESTAMPTZ
  actor TEXT
  actor_role TEXT
  scope TEXT (tenant|backoffice)
  tenant_id TEXT
  event TEXT
  resource TEXT
  ip INET
  severity TEXT (info|warn)
  result TEXT (ok|error)
  metadata JSONB

user_invites (inviteTracker)
  -- tracks email invitations and password resets

lifecycle tables (lifecycleSchema)
  -- identities + memberships (DB = truth, KC = projection)
```

### Per-Tenant DB (`tenant_<tid>`)

Schema: `app`. Owner: `tenant_<tid>`.

```
assets
  id UUID PK
  name TEXT UNIQUE
  asset_type TEXT (web_api|web_app|...)
  environment TEXT
  source TEXT (manual|esam)
  relevance TEXT (critical|high|medium|low)
  url TEXT
  tags TEXT[]
  triage_mode TEXT (manual|auto)
  testing_depth TEXT (quick|standard|deep)
  frequency TEXT
  status TEXT (active|retired)
  auth_config JSONB
  test_identities JSONB
  triggers JSONB
  restrictions JSONB

vulnerabilities
  id UUID PK
  asset_id UUID FK -> assets
  external_id TEXT UNIQUE
  scan_job_id TEXT
  title TEXT
  description TEXT
  severity TEXT
  cvss_v4 NUMERIC
  cwe TEXT
  owasp TEXT
  state TEXT (pending_manual_triage|triaged|...)
  source TEXT (scanner|manual)
  evidence_paths TEXT[]
  reproduction_steps TEXT[]
  evidence JSONB
  triage_notes TEXT
  triaged_by TEXT
  triaged_at TIMESTAMPTZ

scan_jobs
  id UUID PK
  asset_id UUID FK -> assets
  job_id TEXT UNIQUE
  scan_type TEXT (baseline)
  depth TEXT (quick|standard|deep)
  focus TEXT[]
  state TEXT (queued|claimed|running|completed|failed)
  requested_by TEXT
  findings_count INT

vpns
  id UUID PK
  name TEXT UNIQUE
  vpn_type TEXT (wireguard)
  config_file_path TEXT
  config_snippet TEXT

esam_config
  id INT PK (singleton, CHECK id=1)
  domains TEXT[]
  subdomains TEXT[]
  ip_ranges TEXT[]
  asn_list TEXT[]
  brand_names TEXT[]
  allowlist TEXT[]
  blocklist TEXT[]

esam_discoveries
  id UUID PK
  identifier TEXT
  discovery_type TEXT
  source TEXT
  confidence NUMERIC
  approval_state TEXT (pending|approved|rejected)
  approved_by TEXT
  asset_id UUID FK -> assets (nullable)

federation_config
  id INT PK (singleton)
  enabled BOOLEAN
  provider TEXT (entra-id)
  entra_tenant_id TEXT
  entra_client_id TEXT
  role_mappings JSONB

audit_log (tenant-scoped)
  id BIGSERIAL PK
  ts TIMESTAMPTZ
  actor TEXT
  event TEXT
  resource TEXT
  metadata JSONB
```

## Shared Library (`@secplatform/shared` v6.0.0)

Located in `shared/`, mounted at `/app/shared` in containers.

**Modules**:
- `db.js` -- `createDb(config)` returns `{ controlPool, getTenantPool, query, queryTenant, close }`. Connection pooling with `pg`.
- `kc-admin.js` -- `createKcAdmin(config)` returns Keycloak admin API client with token caching. Methods: `get/post/put/delete(path, { realm, body, params })`.
- `jwks.js` -- `createJwks(config)` returns JWT verification via Keycloak JWKS endpoint.
- `lifecycle.js` -- Unified identity + membership lifecycle. Idempotent primitives. DB = source of truth, KC = projection. Operations: createUser, deleteUser, syncTenantIds, addMembership, removeMembership, etc.
- `lifecycleSchema.js` -- Ensures lifecycle tables exist in control-plane DB.
- `logger.js` -- pino logger instance.
- `tenantId.js` -- `isValidTenantId`, `assertTenantId`, `slugify`, `generateTenantId`. Tenant ID format: `[a-z0-9]`, max 31 chars, no leading digits.
- `emailActions.js` -- Single source of truth for Keycloak required-actions (UPDATE_PASSWORD, CONFIGURE_TOTP, CONFIGURE_WEBAUTHN_PASSWORDLESS, VERIFY_EMAIL). Env-flag controlled MFA/passkey per realm. Link lifespans (invite: 6h, reset: 30min).

## Keycloak Configuration

### Realm Import (`keycloak/realms/`)

Two realm JSON files imported on startup: `customers.json`, `backoffice.json`.

**Password policy**: `length(15) and upperCase(1) and lowerCase(1) and digits(1) and specialChars(2)`.

**Token lifespans**: access token 900s, SSO idle 3600s, SSO max 36000s.

**Features enabled**: token-exchange, admin-fine-grained-authz.

### Themes (`keycloak/themes/`)

Custom themes for both `iar` (customer) and `iar-bo` (backoffice):
- Login pages (login.ftl, error.ftl, info.ftl, OTP, TOTP config, password reset, password update, page expired)
- Email templates (executeActions.ftl, template.ftl) in en/es/pt_BR
- Custom CSS for login pages

### Runtime Realm Configuration (`applyRealmConfig`)

Idempotent configuration applied on BFF-backoffice startup:
- SMTP server setup (from env vars)
- MFA flags (TOTP, WebAuthn) per realm
- Redirect URI whitelist
- Protocol mappers (tenant_ids, roles, scope_type)
- Event listeners (mail notifications for credential changes)