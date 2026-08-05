# Infrastructure Overview

## What This Is

Ansible-based infrastructure as code for 5 hosts: 3 cloud VPS + 2 local machines. Unified by a WireGuard hub-and-spoke mesh network with Cloudflare Tunnel fallback. All servers run Fedora Server 44 or AlmaLinux 10 (RHEL family only).

## Network Topology

```
                         ┌─────────────────────────────────────────────────┐
                         │              INTERNET                           │
                         │                                                 │
    ┌────────────────────┤                    │                            │
    │  randazzo.ar       │  0b.ar             │  i.ar                     │
    │  randazzo.com.ar   │                    │  grafana.i.ar             │
    │  (redirect)        │                    │  camaras.randazzo.ar       │
    │                    │                    │                            │
    ▼                    ▼                    ▼                            │
┌──────────────┐  ┌──────────────┐  ┌──────────────┐                     │
│  rammstein   │  │   greenday   │  │   daftpunk   │                     │
│  VPS 2c/4GB  │  │  VPS 16c/16G │  │  16c/64GB    │                     │
│  Proxy Hub   │  │  AI Play     │  │  Ollama CPU  │                     │
│  Caddy + TLS │  │  Docker      │  │  Static page │                     │
│  CF Tunnel   │  │  SSH for AI  │  │  Grafana      │                     │
│  WG:10.66.0.1│  │  WG:10.66.0.2│  │  WG:10.66.0.3│                     │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘                     │
       │   WireGuard      │   WireGuard      │   WireGuard                 │
       │   (hub)          │   (spoke)        │   (spoke)                   │
       ═══════════════════════════════════════════════════════════════════ │
       │                  │                  │                              │
       ▼                                              ▼                     │
┌──────────────┐                              ┌──────────────┐             │
│    yoga      │                              │   sophon     │             │
│  Intel Ultra │                              │ 12c/96GB    │             │
│  NPU (future)│                              │ RTX 3080    │             │
│  WG:10.66.0.4│                              │ Ollama GPU  │             │
└──────────────┘                              │ Frigate NVR │             │
                                               │ WG:10.66.0.5│             │
                                               └──────────────┘             │
                                                                            │
                    randazzo.net.ar -> Cloudflare Tunnel (fallback VPN)     │
                                                                            │
                         └─────────────────────────────────────────────────┘
```

## Host Inventory

| Host | Codename | WG IP | Domain | Role | Hardware |
|------|----------|-------|--------|------|----------|
| rammstein | randazzo-ar | 10.66.0.1 | randazzo.ar, randazzo.com.ar | Proxy hub, Caddy, CF Tunnel | VPS 2c/4GB |
| greenday | ob-ar | 10.66.0.2 | 0b.ar | AI playground, Docker, SSH for AI agent | VPS 16c/16GB |
| daftpunk | i-ar | 10.66.0.3 | i.ar | Ollama (CPU), static page, Grafana | 16c/64GB |
| yoga | laptop | 10.66.0.4 | (none) | Future NPU agent | Intel Core Ultra |
| sophon | server-pc | 10.66.0.5 | (none) | Ollama GPU, Frigate NVR | 12c/96GB, RTX 3080 10GB |

## Inventory Groups (Functional)

Hosts can belong to multiple groups. Adding a host to a group auto-includes it in relevant playbooks.

| Group | Hosts | Purpose |
|-------|-------|---------|
| `cloud` | rammstein, greenday, daftpunk | All VPS hosts (get admin user, SSH key) |
| `local` | sophon, yoga | Local machines (use personal user `nacho`) |
| `proxy` | rammstein | Caddy + CF Tunnel |
| `ai_playground` | greenday | Docker + AI agent environment |
| `ollama_hosts` | daftpunk, sophon | Ollama instances |
| `frigate_hosts` | sophon | Frigate NVR |

## Variable Hierarchy (DRY)

Variables are layered -- each layer overrides the one above:

| Layer | File | Purpose |
|-------|------|---------|
| 1. Role defaults | `roles/<name>/defaults/main.yml` | Safe defaults for standalone role use |
| 2. Group vars (all) | `inventory/group_vars/all/main.yml` | Global: packages, domains, WG, SSH, Ollama defaults |
| 3. Group vars (group) | `inventory/group_vars/<group>.yml` | Per-group settings (cloud, local) |
| 4. Host vars | `inventory/host_vars/<host>.yml` | Per-host: WG IP, enabled services, models, cameras |
| 5. Vault | `inventory/group_vars/all/vault.yml` | Secrets (encrypted with ansible-vault) |

**Rule:** Define a variable at the highest layer where it is constant. Only push it down to host_vars when it varies per host.

## Ansible Configuration

- Inventory: `inventory/hosts.yml`
- Vault password: `.vault_pass` (gitignored)
- Fact caching: jsonfile in `.ansible/facts/` (24h timeout)
- SSH: ControlMaster auto, ControlPersist 60s
- Become: sudo as root by default
- Callbacks: profile_tasks (shows task timing)
- Retry files: disabled

## Key Files

| File | Purpose |
|------|---------|
| `ansible.cfg` | Ansible configuration |
| `inventory/hosts.yml` | Host inventory with functional groups |
| `inventory/group_vars/all/main.yml` | Global variables (domains, WG, packages, defaults) |
| `inventory/group_vars/all/vault.yml` | Encrypted secrets (WG keys, CF tokens, RTSP creds) |
| `inventory/host_vars/<host>.yml` | Per-host overrides (WG IP, enabled services, models) |
| `scripts/generate-wg-keys.sh` | One-time WireGuard keypair generation for all hosts |
| `.vault_pass` | Ansible vault password file (gitignored, must exist locally) |
| `.gitignore` | Protects secrets: .vault_pass, wg-keys/, *.private, *.key, .ansible/ |

## Domains and Web Services

| Domain | Served By | Type | Backend |
|--------|-----------|------|---------|
| randazzo.ar | rammstein (Caddy) | Static portfolio | file_server -> /var/www/randazzo.ar |
| randazzo.com.ar | rammstein (Caddy) | Redirect | -> https://randazzo.ar |
| camaras.randazzo.ar | rammstein (Caddy) | Reverse proxy | -> 10.66.0.5:8971 (Frigate) |
| i.ar | daftpunk (Caddy) | Static landing page | file_server -> /var/www/emacboros |
| grafana.i.ar | daftpunk (Caddy) | Reverse proxy | -> 10.66.0.3:3000 (Grafana) |
| 0b.ar | greenday (Caddy) | Reverse proxy | -> 127.0.0.1:80 (AI playground) |

All sites get automatic TLS via Caddy + Let's Encrypt. Security headers (HSTS, X-Frame-Options, nosniff, no-referrer) applied.

## Ollama Configuration

| Host | Mode | Listen Address | Models |
|------|------|---------------|--------|
| daftpunk | CPU-only | 10.66.0.3:11434 (WG only) | llama3.3:70b, north-mini-code-1.0:q8_0 |
| sophon | GPU offload | 10.66.0.5:11434 (WG only) | nemotron-3-super:120b, gpt-oss:120b |

Ollama never binds to 0.0.0.0 on production hosts. WireGuard IP only = no public exposure.

## Frigate NVR (sophon)

8 cameras (3 interior, 5 exterior) connected via RTSP. Camera IPs are in host_vars; credentials come from vault. Frigate runs via Podman Compose with NVIDIA TensorRT for object detection. Web UI at port 8971, proxied through rammstein as camaras.randazzo.ar.

Retention: continuous 3 days, motion 7 days, alerts/detections 30 days.