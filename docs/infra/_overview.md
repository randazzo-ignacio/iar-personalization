# Infrastructure Overview

## Network

5 nodes via WireGuard mesh (10.66.0.0/16):

| Host | Codename | WG IP | Role | Hardware |
|------|----------|-------|------|----------|
| rammstein | randazzo-ar | 10.66.0.1 | Proxy hub, Caddy, CF Tunnel | VPS 2c/4GB |
| greenday | ob-ar | 10.66.0.2 | AI playground, Docker, SSH for AI | VPS 16c/16GB |
| daftpunk | i-ar | 10.66.0.3 | Ollama CPU, Grafana | 16c/64GB |
| yoga | laptop | 10.66.0.4 | Future NPU agent | Intel Ultra |
| sophon | server-pc | 10.66.0.5 | Ollama GPU, Frigate NVR | 12c/96GB, RTX 3080 |

Only rammstein has public web ports (80/443). All else WireGuard-only.

## Ansible Structure

- Inventory: `inventory/hosts.yml` with functional groups (cloud, local, proxy, ollama_hosts, etc.)
- Variables layered: role defaults -> group_vars/all -> group_vars/<group> -> host_vars -> vault
- Vault: `inventory/group_vars/all/vault.yml` (encrypted)
- Playbooks: site.yml (full), base.yml, wireguard.yml, ollama.yml, etc.

## Key Services

- Caddy: automatic TLS, reverse proxy for web services
- Ollama: daftpunk (CPU), sophon (GPU). WireGuard-only, never public.
- Frigate NVR: 8 cameras on sophon, proxied via rammstein
- i.ar debug containers: on sophon + rammstein, SSH over WireGuard, host root at /host (read-only)

## Security

- Key-only SSH, password auth disabled, fail2ban
- Firewalld default deny on all hosts
- Ollama binds to WireGuard IP only
- Cloudflare Tunnel as VPN fallback

## Domains

randazzo.ar (portfolio), i.ar (landing), grafana.i.ar (Grafana), camaras.randazzo.ar (Frigate), 0b.ar (AI playground).

## Full Docs

operations.md (deployment, recovery), overview.md (detailed topology), playbooks.md (playbook reference), roles.md (role reference), security.md (security details). Use read_file for details.