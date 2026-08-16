# Modules

## Shared Library (`shared/`)

Package: `@secplatform/shared` v6.0.0. Mounted at `/app/shared` in all BFF containers.

### `src/db.js`
PostgreSQL connection manager. Creates control-plane pool and lazy per-tenant pools.
- `createDb(config)` -> `{ controlPool, getTenantPool(tid), query(sql, params), queryTenant(tid, sql, params), close() }`
- Tenant pools cached in a Map. Each pool: max 10 connections, 30s idle timeout.
- Tenant DB naming: `tenant_<tid>`, user: `tenant_<tid>`, password from config.

### `src/kc-admin.js`
Keycloak admin API client with token caching.
- `createKcAdmin(config)` -> `{ getToken(), get/post/put/delete(path, { realm, body, params }) }`
- Token cached with 5s expiry buffer. Uses password grant against master realm `admin-cli`.
- `validateStatus: () => true` -- never throws on HTTP errors, caller inspects `.status`.

### `src/jwks.js`
JWT verification via Keycloak JWKS URI.
- `createJwks(config)` -> `{ verify(token) }` returns decoded JWT payload.

### `src/lifecycle.js`
Unified identity + membership lifecycle. DB = source of truth, Keycloak = projection.
- Injected: `({ db, kcAdmin, config, logger })`
- All operations idempotent (404 = success, 409 = adopt existing).
- Key operations: `kcCreateUser`, `kcDeleteUser`, `kcSyncTenantIds`, `createIdentity`, `addMembership`, `removeMembership`, `deactivateIdentity`.
- KC user attributes: `tenant_ids` (array) for membership tracking.

### `src/lifecycleSchema.js`
Ensures lifecycle tables exist in control-plane DB. Idempotent.
- `ensureSchema()` creates tables if not present.

### `src/logger.js`
pino logger instance. Level from `LOG_LEVEL` env var (default: info).

### `tenantId.js`
Tenant ID validation and generation.
- `TENANT_ID_RE`: `/^[a-z0-9]{2,31}$/`
- `isValidTenantId(tid)`: boolean
- `assertTenantId(tid)`: throws if invalid
- `slugify(name)`: normalize display name to tenant ID base
- `generateTenantId(displayName, existsCallback)`: generates unique tenant ID with numeric suffix if needed

### `emailActions.js`
Single source of truth for Keycloak required-actions and deep-link lifespans.
- `buildActions(realm, { kind, hasOtp, hasWebauthn, includeVerifyEmail })`: returns array of required actions.
- `mfaEnabled(realm)`: checks `MFA_CUSTOMERS_ENABLED` / `MFA_BACKOFFICE_ENABLED` env.
- `passkeyEnabled(realm)`: checks `PASSKEY_*_ENABLED` env.
- `linkLifespan(kind)`: invite=21600s (6h), reset=1800s (30min).
- `envBool(name, default)`: robust env var boolean parser.

---

## BFF-Client Services (`bff-client/src/services/`)

### `findingsImporter.js`
Polls tenant findings directories on interval (`IMPORTER_INTERVAL_MS`, default 5s). Reads `findings.json` files and imports vulnerabilities into the tenant DB. Marks imported findings to avoid duplicates.

### `inviteTracker.js`
Tracks email invitations and password resets in `user_invites` table (control-plane DB).
- `ensureSchema()`: creates `user_invites` table if not exists.
- `recordInvite(...)`: logs invitation with action type, sent_at, expires_at.
- `deriveStatus(kcUser, tracking)`: derives user status from KC required actions + tracking record. Returns `{ status, mfa_pendiente }`.
  - Statuses: `activo`, `invitacion_enviada`, `reset_enviado`, `enlace_vencido`, `pass_configurado`, `pendiente`.

### `jobEnqueue.js`
Creates scan job JSON files in tenant's `jobs/queued/` directory. Job contains: job_id, asset_id, scan_type, depth, focus, requested_by.

### `kcUsers.js`
Keycloak admin operations for customer realm users. Includes ABAC enforcement.
- `assertUserInTenant(userId, tenantId)`: validates target user membership before destructive operations.

---

## BFF-Backoffice Services (`bff-backoffice/src/services/`)

### `tenantProvisioner.js`
Creates new tenants end-to-end. Idempotent.
- Creates PostgreSQL role + database for tenant.
- Creates schema, tables, seed data.
- Creates tenant volume directories (assets, vpns, findings, evidence, secrets, audit, jobs/*).
- Updates `tenants.json` manifest in control-plane volume.
- Calls `lifecycle` for initial POC user provisioning.
- `seed()`: provisions `acme` and `globex` on startup if not present.

### `inviteTracker.js`
Same as BFF-client version. Shared `user_invites` table.

### `kcBackofficeUsers.js`
Keycloak admin operations for backoffice realm users. Role assignment, invitation via execute-actions-email.

### `applyRealmConfig.js`
Idempotent realm configuration applied on startup. Retries on failure.
- Configures SMTP server from env vars.
- Sets MFA flags (TOTP, WebAuthn) per realm.
- Updates redirect URI whitelist.
- Ensures protocol mappers exist (tenant_ids, roles, scope_type).
- Configures event listeners for mail notifications (credential changes).
- `applyWithRetry()`: attempts configuration with backoff.

---

## Scanner Worker (`scanner/src/`)

Standalone Node.js process. No DB access, pure filesystem operations.

- Polls `/tenants/<tid>/jobs/queued/` every 3s (configurable via `POLL_INTERVAL_MS`).
- Job lifecycle: `queued` -> `claimed` -> `running` -> `completed` (or `failed`).
- Simulates scan with 5s delay (`SCAN_DURATION_MS`).
- Generates findings from static vulnerability bank (6 categories, randomized selection).
- Writes `findings.json` to `/tenants/<tid>/findings/<job_id>/`.
- Updates job file with `state`, `finished_at`, `findings_count`.

---

## Frontend Modules

### frontend-client (`frontend-client/public/`)
Vanilla JS SPA. No framework, no build step.

**Core JS**:
- `api.js` -- fetch wrapper with auth cookie handling
- `login.js` -- OIDC login redirect
- `portal.js` -- main portal logic, view router
- `permissions.js` -- client-side permission checks (UI gating)
- `safe-ui.js` -- safe rendering helpers (XSS prevention)

**Views** (`js/views/`):
- `dashboard.js` -- overview dashboard
- `assets.js` -- asset CRUD + scan trigger
- `vulnerabilities.js` -- vulnerability list + triage
- `scans.js` -- scan job list + detail
- `users.js` -- user management (invite, reset, delete)
- `esam.js` -- external surface management
- `federation.js` -- Entra ID federation config
- `vpns.js` -- VPN management

### frontend-backoffice (`frontend-backoffice/public/`)
Vanilla JS SPA for internal staff.

**Views** (`js/views/`):
- `overview.js` -- platform overview
- `orgs.js` -- tenant/organization management
- `triage.js` -- cross-tenant triage queue
- `audit.js` -- audit log viewer
- `billing.js` -- billing/plan management
- `bo-users.js` -- backoffice user management
- `support.js` -- support operations
- `manual-vuln.js` -- manual vulnerability entry

---

## Scripts (`scripts/`)

| Script | Purpose |
|--------|---------|
| `healthcheck-stack.sh` | Check all services in a stack are healthy |
| `verify-kc.sh` | Verify Keycloak realm is accessible |
| `kc-users.py` | Keycloak user management utility |
| `kc-backup-all.sh` | Backup all Keycloak realms |
| `kc-prune-all.sh` | Prune inactive Keycloak users |
| `kc-prune-users.sh` | Prune specific users |
| `install-email-templates.sh` | Install email templates to Keycloak |
| `fix_bo_otp.py` | Fix backoffice OTP configuration |
| `patch_onboarding.py` | Patch user onboarding state |
| `patch_webauthn_policy.py` | Patch WebAuthn policy in realm |
| `resolve_theirs.py` | Git merge conflict resolver |
| `seed-lifecycle.sh` | Seed lifecycle tables |
| `discover-lifecycle.sh` | Discover lifecycle state from DB |
| `migration-001-lifecycle.sql` | SQL migration for lifecycle tables |