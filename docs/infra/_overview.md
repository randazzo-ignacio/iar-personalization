# Infrastructure Overview

## Network

3 nodes via WireGuard mesh (10.66.0.0/16):

| Host | Codename | WG IP | Role | Hardware |
|------|----------|-------|------|----------|
| rammstein | randazzo-ar | 10.66.0.1 | Proxy hub, Caddy, WG hub | VPS 2c/4GB |
| yoga | laptop | 10.66.0.4 | Daily driver, backup client | Intel Ultra, Silverblue |
| sophon | server-pc | 10.66.0.5 | GPU Ollama, Frigate NVR, SecPlatform | 12c/96GB, RTX 3080 |

Consolidated 2026-08-04: daftpunk + greenday killed. rammstein is sole VPS.

Only rammstein has public web ports (80/443). All else WireGuard-only.

## Ansible Structure

- Inventory: `inventory/hosts.yml` with functional groups (cloud, local, proxy, ollama_hosts, secplatform_hosts, etc.)
- Variables layered: role defaults -> group_vars/all -> group_vars/<group> -> host_vars -> vault
- Vault: `inventory/group_vars/all/vault.yml` (encrypted)
- Playbooks: site.yml (full), base.yml, wireguard.yml, ollama.yml, secplatform.yml, etc.

## Key Services

- Caddy: automatic TLS, reverse proxy for all web services
- Ollama: sophon (GPU). WireGuard-only, never public.
- Frigate NVR: 8 cameras on sophon, proxied via rammstein
- SecPlatform: multi-tenant SaaS on sophon (podman compose + docker-compose v2), proxied via rammstein
- i.ar debug containers: on sophon + rammstein, SSH over WireGuard, host root at /host (read-only)

## SecPlatform

Multi-tenant SaaS (vulnerability management + asset scanning) running on sophon via podman compose. Originally developed by a friend, adapted to our infra.

### URLs

| Domain | Service | Backend |
|--------|---------|---------|
| i.ar | Landing page (static) | rammstein local |
| app.i.ar | Customer portal | sophon:8091 |
| app-bo.i.ar | Back-office | sophon:8092 |
| auth.i.ar | Keycloak (OIDC) | sophon:8080 |

### Container Runtime

- **Podman** (not Docker) with **docker-compose v2** (Go binary) as compose provider
- `podman-compose` (Python) is installed but not used -- doesn't support `depends_on` with healthcheck conditions
- docker-compose v2 connects to podman via `podman.socket` (Docker-compatible API)
- Stack runs as root (system podman socket), not rootless
- SELinux `:z` labels on all bind mounts
- Nginx uses direct `proxy_pass` (no Docker-specific DNS resolver)

### Ansible Role

`roles/secplatform/` in iar-infrastructure:
- Installs docker-compose v2 binary
- Enables podman sockets (system + user)
- Clones repo, creates .env + tenant dirs (non-interactive)
- Creates systemd service (`secplatform-prod.service`)
- On rebuild: stops service, tears down containers, rebuilds, restarts

### MVP Status

- No email, no MFA, no CI/CD
- Seed users in Keycloak realm JSONs
- Manual deploy via `ansible-playbook playbooks/secplatform.yml`

## Security

- Key-only SSH, password auth disabled, fail2ban
- Firewalld default deny on all hosts
- Ollama binds to WireGuard IP only
- SecPlatform services bind to WireGuard IP only (10.66.0.5)

## Domains

randazzo.ar (portfolio), i.ar (landing), app.i.ar (SecPlatform client), app-bo.i.ar (SecPlatform BO), auth.i.ar (Keycloak), camaras.randazzo.ar (Frigate), wiki.randazzo.ar (wiki), caldav.randazzo.ar (Radicale).

## Full Docs

operations.md (deployment, recovery), overview.md (detailed topology), playbooks.md (playbook reference), roles.md (role reference), security.md (security details). Use read_file for details.