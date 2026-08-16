# API Reference

## BFF-Client (port 3001/4001/5001)

Realm: `customers`. Auth: cookie `sp_at` or `Authorization: Bearer`. All tenant-scoped routes require `X-Active-Tenant` header.

### Health & Info
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/health` | none | Health check (DB connectivity) |
| GET | `/version` | none | Build info (APP_VERSION, APP_ENV, service) |

### Auth (`/auth`)
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/auth/login` | none | Redirect to Keycloak OIDC login |
| GET | `/auth/callback` | none | OIDC callback, sets cookie |
| POST | `/auth/logout` | cookie | Clear session cookie |

### Profile
| Method | Path | Auth | Description |
|--------|------|------|-------------|
| GET | `/me` | authMw | Current user profile (sub, email, roles, tenant_ids) |
| GET | `/me/tenants` | authMw | Tenants accessible by user |

### Tenant-Scoped (`/tenants`)
All require `authMw + tenantRequired`.

| Method | Path | Perm | Description |
|--------|------|------|-------------|
| GET | `/tenants/assets` | asset:read | List assets |
| POST | `/tenants/assets` | asset:write | Create asset |
| GET | `/tenants/assets/:id` | asset:read | Get asset detail |
| PUT | `/tenants/assets/:id` | asset:write | Update asset |
| DELETE | `/tenants/assets/:id` | asset:write | Delete asset |
| POST | `/tenants/assets/:id/scan` | asset:scan | Enqueue scan job |
| GET | `/tenants/vulnerabilities` | vuln:read | List vulnerabilities |
| GET | `/tenants/vulnerabilities/:id` | vuln:read | Get vulnerability detail |
| PATCH | `/tenants/vulnerabilities/:id` | vuln:triage | Triage (update state, notes) |
| GET | `/tenants/scans` | asset:read | List scan jobs |
| GET | `/tenants/scans/:id` | asset:read | Get scan job detail |

### Users (`/users`)
| Method | Path | Perm | Description |
|--------|------|------|-------------|
| GET | `/users` | users:read | List tenant users (from KC, filtered by tenant_ids) |
| POST | `/users` | asset:write (canManage) | Invite user (email + execute-actions) |
| POST | `/users/:userId/reset-password` | asset:write (canManage) | Reset password (assertUserInTenant) |
| DELETE | `/users/:userId` | asset:write (canManage) | Delete user (assertUserInTenant) |

### Federation (`/federation`)
| Method | Path | Perm | Description |
|--------|------|------|-------------|
| GET | `/federation` | esam:read | Get federation config |
| POST | `/federation/entra-id` | asset:write (owner) | Configure Entra ID federation |
| DELETE | `/federation/entra-id` | asset:write (owner) | Remove Entra ID federation |

### VPNs (`/vpns`)
| Method | Path | Perm | Description |
|--------|------|------|-------------|
| GET | `/vpns` | vpn:read | List VPNs |
| POST | `/vpns` | vpn:write | Create VPN |
| DELETE | `/vpns/:id` | vpn:write | Delete VPN |

### ESAM (`/esam`)
| Method | Path | Perm | Description |
|--------|------|------|-------------|
| GET | `/esam/config` | esam:read | Get ESAM config |
| PUT | `/esam/config` | esam:read | Update ESAM config |
| GET | `/esam/discoveries` | esam:read | List discoveries |
| POST | `/esam/discoveries/:id/approve` | esam:approve | Approve discovery (creates asset) |

---

## BFF-Backoffice (port 3002/4002/5002)

Realm: `backoffice`. Auth: cookie `sp_bo_at` or `Authorization: Bearer`.

### Health
| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Health check |

### Auth (`/auth`)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/auth/login` | Redirect to Keycloak OIDC |
| GET | `/auth/callback` | OIDC callback |
| POST | `/auth/logout` | Clear session |

### Organizations (`/organizations`)
| Method | Path | Perm | Description |
|--------|------|------|-------------|
| GET | `/organizations` | org:read | List all tenants |
| GET | `/organizations/:id` | org:read | Get tenant detail |
| POST | `/organizations` | org:create | Provision new tenant (DB, volume, KC config, seed) |
| DELETE | `/organizations/:id` | `*` (owner) | Deprovision tenant (lifecycle.deleteOrg) |

### Triage (`/triage`)
| Method | Path | Perm | Description |
|--------|------|------|-------------|
| GET | `/triage/queue` | triage:read | Cross-tenant vulnerability triage queue |
| POST | `/triage/tenant/:tid/finding/:id/action` | triage:action | Act on finding |
| GET | `/triage/tenant/:tid/finding/:id` | triage:read | Get finding detail |

### Tenant Data (`/tenant`)
| Method | Path | Perm | Description |
|--------|------|------|-------------|
| GET | `/tenant/:tid/assets` | tenant-data:read | List tenant assets (cross-tenant) |
| GET | `/tenant/:tid/vulnerabilities` | tenant-data:read | List tenant vulns (cross-tenant) |

### BO Users (`/bo-users`)
| Method | Path | Perm | Description |
|--------|------|------|-------------|
| GET | `/bo-users` | bo-users:read | List backoffice users |
| POST | `/bo-users` | bo-users:create-limited | Invite BO user |

### Audit Log (`/audit-log`)
| Method | Path | Perm | Description |
|--------|------|------|-------------|
| GET | `/audit-log` | audit:read | Query audit log (with filters) |

### Billing (`/billing`)
| Method | Path | Perm | Description |
|--------|------|------|-------------|
| GET | `/billing` | billing:read | List billing info for all tenants |
| PATCH | `/billing/:id` | billing:write | Update plan/limits |

### Support (`/support`)
| Method | Path | Perm | Description |
|--------|------|------|-------------|
| POST | `/support/reset-poc-password` | support:reset-poc-password | Reset POC user password |
| POST | `/support/replace-poc` | support:reset-poc-password | Replace POC user |