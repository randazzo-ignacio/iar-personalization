# Deployment

## Our Infrastructure

SecPlatform prod runs on **sophon** (10.66.0.5) via **podman compose**. Caddy on **rammstein** (10.66.0.1) terminates TLS and reverse-proxies over WireGuard.

### DNS Records

| Record | Target | Notes |
|--------|--------|-------|
| `app.i.ar` | rammstein public IP | A record |
| `app-bo.i.ar` | rammstein public IP | A record |
| `auth.i.ar` | rammstein public IP | A record |

All three are already configured.

### Caddy Config (rammstein, managed by Ansible)

The Caddy sites are defined in `inventory/host_vars/rammstein.yml` as `caddy_sites` entries with `type: proxy`, `backend_host: sophon`, and the appropriate `backend_port`. The Caddy role generates the Caddyfile from this list.

```
app.i.ar      -> reverse_proxy 10.66.0.5:8091
app-bo.i.ar   -> reverse_proxy 10.66.0.5:8092
auth.i.ar     -> reverse_proxy 10.66.0.5:8080
```

Caddy handles ACME TLS automatically. No Cloudflare.

### Port Binding (sophon)

All services bind to `10.66.0.5` (WireGuard IP), not `0.0.0.0`. Only rammstein can reach them over WireGuard.

## Container Runtime: Podman + docker-compose v2

The stack uses **podman** as the container runtime with **docker-compose v2** (Go binary) as the compose provider.

### Why Not podman-compose (Python)?

`podman-compose` v1.6.0 (Python) doesn't support `depends_on` with `condition: service_healthy`. Containers with dependencies fail to start with "not a valid container, cannot be used as a dependency". docker-compose v2 handles this correctly.

### How It Works

1. `podman compose` finds `docker-compose` v2 binary in PATH and uses it as the provider
2. docker-compose v2 connects to podman via the Docker-compatible socket API
3. `podman.socket` (systemd socket activation) provides the socket at `/run/podman/podman.sock` (system) or `/run/user/<uid>/podman/podman.sock` (user)
4. The stack runs as **root** (system podman socket), not rootless

### Podman-Specific Fixes

1. **SELinux `:z` labels on bind mounts**: `docker-compose.yml` uses `:z` on all host bind mounts (keycloak/realms, keycloak/themes, postgres/init). Without this, SELinux blocks containers from reading host-mounted directories.

2. **Nginx DNS**: Frontend nginx configs use direct `proxy_pass` with static upstream names (no `resolver` directive). Podman's aardvark-dns resolves container names at the network gateway (e.g. `10.89.0.1`), not Docker's `127.0.0.11`.

3. **DOCKER_HOST**: The systemd service and `spc.sh` set `DOCKER_HOST` so docker-compose v2 connects to podman's socket:
   - System (root): `unix:///run/podman/podman.sock`
   - User (nacho): `unix:///run/user/$(id -u)/podman/podman.sock`

## Ansible Deployment

The `secplatform` role in `iar-infrastructure` manages the full deployment.

### Role Variables (defaults)

| Variable | Default | Purpose |
|----------|---------|---------|
| `secplatform_enabled` | `false` | Opt-in flag |
| `secplatform_repo_url` | `""` | Git bare repo URL |
| `secplatform_repo_branch` | `main` | Branch to deploy |
| `secplatform_deploy_dir` | `""` | Deploy directory on target host |
| `secplatform_env` | `prod` | Compose environment |
| `secplatform_compose_project` | `sp-{{ env }}` | Podman compose project name |
| `secplatform_user` | `{{ ansible_user }}` | Owner of deploy dir |
| `secplatform_rebuild` | `false` | Force image rebuild on each run |
| `secplatform_compose_version` | `2.5.1` | docker-compose v2 version to install |

### Host Vars (sophon)

```yaml
secplatform_enabled: true
secplatform_repo_url: "git@10.66.0.1:/home/git/repos/iar-prod.git"
secplatform_repo_branch: "main"
secplatform_deploy_dir: "/home/nacho/repos/iar-prod"
secplatform_env: "prod"
secplatform_rebuild: true
```

### What the Role Does

1. Installs docker-compose v2 binary (`/usr/local/bin/docker-compose`)
2. Enables `podman.socket` (system + user) for Docker-compatible API
3. Clones the repo from the git bare repo
4. Creates `.env` (non-interactive, replaces `setup.sh`)
5. Creates tenant directories and manifest files
6. Ensures scripts are executable (chmod +x)
7. Creates systemd service (`secplatform-prod.service`)
8. When `secplatform_rebuild: true`:
   - Stops the systemd service
   - Runs `podman compose down --remove-orphans`
   - Runs `podman compose up -d --build`
9. When `secplatform_rebuild: false`:
   - Just starts the systemd service

### Deploying

```bash
# Push code to bare repo first
cd ~/repos/iar-prod && git push rammstein main

# Run the playbook
ansible-playbook playbooks/secplatform.yml --ask-vault-pass

# Or run just the Caddy update (if only proxy config changed)
ansible-playbook playbooks/caddy.yml --ask-vault-pass
```

### Systemd Service

```
secplatform-prod.service
  Type: oneshot, RemainAfterExit=yes
  ExecStart: podman compose ... up -d
  ExecStop: podman compose ... down
  Environment: COMPOSE_PROJECT_NAME=sp-prod
  Environment: DOCKER_HOST=unix:///run/podman/podman.sock
```

Manual management on sophon:
```bash
sudo systemctl start secplatform-prod    # Start
sudo systemctl stop secplatform-prod     # Stop
sudo systemctl status secplatform-prod   # Status
```

## Environments

Three environments can coexist on sophon via Docker Compose project name namespacing (`sp-prod`, `sp-dev`, `sp-local`). Only prod is internet-facing (via Caddy).

### Port Map

| Service | PROD | DEV | LOCAL |
|---------|------|-----|-------|
| Keycloak | 10.66.0.5:8080 | 9080 | 7080 |
| Postgres BFF | 10.66.0.5:5432 | 6432 | 7432 |
| BFF-client | 10.66.0.5:3001 | 4001 | 5001 |
| BFF-backoffice | 10.66.0.5:3002 | 4002 | 5002 |
| Frontend client | 10.66.0.5:8091 | 9091 | 10091 |
| Frontend backoffice | 10.66.0.5:8092 | 9092 | 10092 |
| MailHog UI | 10.66.0.5:8025 | 9025 | 10025 |
| MailHog SMTP | 10.66.0.5:1025 | 2025 | 3025 |

### Compose File Layering

```
docker-compose.yml          # Base: services, networks, volumes (NO ports)
compose/ports.<env>.yml     # Port mappings per environment
compose/env.<env>.yml       # Environment variable overrides per env
```

Base compose has NO `ports:` directives. All ports live in overrides. This prevents collisions.

### Wrapper Script (`spc.sh`)

```bash
./spc.sh prod up -d         # Start prod
./spc.sh dev up -d          # Start dev
./spc.sh prod ps            # Status
./spc.sh dev logs -f        # Follow logs
```

Uses docker-compose v2 if available, falls back to `podman compose`. Sets `COMPOSE_PROJECT_NAME=sp-<env>` and `DOCKER_HOST` for podman socket.

## Environment-Specific Overrides

### PROD (`compose/env.prod.yml`)

- Keycloak: `start` (production mode), `--proxy-headers=xforwarded`, hostname `https://auth.i.ar`
- BFF URLs: `https://app.i.ar/`, `https://app-bo.i.ar/`
- MFA: OFF (MVP -- enable later)
- Passkey: OFF (MVP -- enable later), RPID `i.ar`
- SMTP: none (MVP -- no email)
- MailHog: disabled (profile `dev-only`)
- Verify email on invite: false

### DEV (`compose/env.dev.yml`)

- Keycloak: `start-dev` mode
- Keycloak URL: `http://10.66.0.5:9080`
- MFA: OFF
- SMTP: MailHog
- Log level: debug
- Verify email on invite: true

### LOCAL (`compose/env.local.yml`)

- Keycloak: `start-dev` with `--http-relative-path=/kc`
- Keycloak URL: `http://10.66.0.5:10091/kc`
- MFA: OFF
- SMTP: MailHog
- Log level: debug

## CI/CD

Not configured for our infra. Manual deploy via Ansible:

```bash
cd ~/repos/iar-prod && git push rammstein main
ansible-playbook playbooks/secplatform.yml --ask-vault-pass
```

The `.github/workflows/` directory contains the original author's CI/CD config (deploy to SL437). These are not used in our setup and can be removed later.

## Reset (Destructive)

```bash
./reset.sh   # podman compose down -v + rm -rf tenants/
```

## Keycloak Realm Import

Realm JSON files in `keycloak/realms/` are imported on first startup (`--import-realm`). Subsequent restarts use the persisted DB state.

**Important**: If you change redirect URIs in the realm JSON after first boot, you must either:
- Delete the Keycloak volume and re-import, OR
- Update the client redirect URIs via Keycloak admin console

Themes in `keycloak/themes/` are mounted read-only at `/opt/keycloak/themes`.

## Postgres Initialization

`postgres/init/01-create-databases.sh` runs on first start:
1. Creates `tenants` and `audit_log` tables in control-plane DB
2. Seeds `acme` and `globex` tenant records
3. For each seed tenant: creates role, database, schema, tables, seed data (assets, ESAM discoveries)

## Adding a New Environment

1. Create `compose/ports.<env>.yml` with unique ports
2. Create `compose/env.<env>.yml` with env-specific overrides (optional)
3. Add env name to `spc.sh` validation
4. Update port map in docs