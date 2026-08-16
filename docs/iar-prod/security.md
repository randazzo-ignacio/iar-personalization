# Security

## Tenant Isolation (3-Layer)

### Layer 1: Middleware `tenantRequired` (BFF-client)

File: `bff-client/src/middleware/tenant-context.js`

- Active tenant from `X-Active-Tenant` header or `?tenant_id=` query param (never from body).
- Validated against `req.auth.tenantIds` (from JWT `tenant_ids` claim).
- If token doesn't include the tenant -> 403 forbidden (fail-closed).
- Tenant manifest loaded from control-plane filesystem (`tenants.json`), not from client.
- Sets `req.tenant.dbPool` to the per-tenant DB pool.

### Layer 2: Physical DB Per Tenant

File: `shared/src/db.js`

- `getTenantPool(tid)` creates a separate `pg.Pool` with `database: tenant_<tid>`, `user: tenant_<tid>`.
- All tenant-scoped queries use `req.tenant.dbPool` (not the global pool).
- Even if an attacker guesses a UUID from another tenant, the query runs against the attacker's tenant DB -> 404 (no cross-tenant data leak).

### Layer 3: ABAC for User Operations

File: `bff-client/src/services/kcUsers.js`

- `assertUserInTenant(userId, tenantId)` validates that the target user has `tenant_ids` including the caller's tenant.
- Called before `reset-password` and `delete` operations on users.
- If user doesn't belong to caller's tenant -> 403.

## RBAC

### BFF-Client Permissions

| Role | Permissions |
|------|------------|
| tenant-owner | `*` (all) |
| asset-operator | asset:read, asset:write, asset:scan, vpn:read, vpn:write, esam:read, esam:approve, vuln:read, vuln:triage, users:read |
| asset-auditor | asset:read, vpn:read, esam:read, vuln:read, users:read, audit:read |
| vulnerability-manager | asset:read, vuln:read, vuln:triage, vuln:write, vpn:read |
| report-viewer | asset:read, vuln:read |

### BFF-Backoffice Permissions

| Role | Permissions |
|------|------------|
| owner-backoffice | `*` (all) |
| organization-provisioner | org:read, org:create, audit:read |
| triage-lead | triage:read, triage:action, triage:manual, org:read, tenant-data:read, bo-users:read, bo-users:create-limited |
| triage-analyst | triage:read, triage:action, triage:manual, org:read, tenant-data:read |
| billing-manager | billing:read, billing:write, org:read |
| support-readonly | audit:read, audit:filter, support:reset-poc-password, org:read, bo-users:read |

Enforced via `requirePerm(perm)` middleware. Returns 403 with `missing_permission` and `your_roles` for debugging.

## Audit Logging

- Both BFFs log to `audit_log` table in control-plane DB.
- Fields: actor, actor_role, scope (tenant/backoffice), tenant_id, event, resource, ip, severity, result, metadata (JSONB).
- `logMw` middleware logs on response finish, captures status code and method.
- Severity auto-set to `warn` for HTTP >= 400.

## Authentication

- OIDC via Keycloak (authorization code flow).
- JWT stored in cookie: `sp_at` (client), `sp_bo_at` (backoffice).
- Also accepts `Authorization: Bearer` header.
- JWT verification via Keycloak JWKS endpoint (`shared/src/jwks.js`).
- Realm validation: client rejects non-`customers` realm, BO rejects non-`backoffice` realm.
- Scope validation: client requires `scope_type=tenant`, BO requires `scope_type=backoffice`.

## MFA

- TOTP (Google Authenticator compatible): `CONFIGURE_TOTP` required action, env-flag `MFA_CUSTOMERS_ENABLED` / `MFA_BACKOFFICE_ENABLED`.
- WebAuthn (passkey): `CONFIGURE_WEBAUTHN_PASSWORDLESS`, env-flag `PASSKEY_CUSTOMERS_ENABLED` / `PASSKEY_BACKOFFICE_ENABLED`, `WEBAUTHN_RPID_*` for RP ID.
- MFA is additive: `UPDATE_PASSWORD` always sent, `CONFIGURE_TOTP` added only if MFA enabled and user doesn't already have OTP.
- Password reset never blocked by MFA state.

## Email Security

- **Prod**: Postfix + OpenDKIM container (`mailer/`). DKIM 2048-bit keys, selector configurable. Direct MX delivery (no relay). Postfix restricts to Docker internal networks (no open relay). STARTTLS opportunistic on outbound.
- **Dev/Local**: MailHog (catch-all SMTP, web UI on :8025/:9025/:10025).
- Invitation links: 6h lifespan (invite), 30min (reset). Keycloak `execute-actions-email` with required actions from `shared/emailActions.js`.

## Container Hardening

- BFFs and scanner: `security_opt: ["no-new-privileges:true"]`, `cap_drop: ["ALL"]`.
- Keycloak themes and realm imports mounted read-only.
- Postgres init scripts mounted read-only.
- No `container_name` in base compose (prevents collisions between environments).

## Known Issues (from SECURITY_AUDIT.md)

1. **Issue #1 (MINOR)**: `triage.js` BO endpoints accept `:tid` without `assertTenantId` format validation. Low risk (used as DB name, not SQL string). Fixed with defense-in-depth `assertTenantId` call.
2. **Issue #2 (MINOR)**: `support.js` BO endpoints accept `tenant_id` from body without `assertTenantId`. Very low risk (parameterized queries). Fixed with defense-in-depth.

## Password Policy

Keycloak realm config: `length(15) and upperCase(1) and lowerCase(1) and digits(1) and specialChars(2)`.

Applies to both `customers` and `backoffice` realms.