# Infrastructure Security Model

## Defense in Depth

```
┌─────────────────────────────────────────────────────┐
│                    INTERNET                           │
│  Only ports: 80, 443 (Caddy), 51820/udp (WireGuard) │
│  Everything else: DENIED by firewalld                 │
└──────────────────────┬──────────────────────────────┘
                       │
          ┌────────────┴────────────┐
          │   rammstein (Proxy)      │
          │   Caddy + TLS + firewalld │
          │   CF Tunnel (fallback)    │
          └────────────┬────────────┘
                       │
           WireGuard (encrypted tunnel)
                       │
     ┌─────────────────┼─────────────────┐
     │                 │                 │
     ▼                 ▼                 ▼
┌─────────┐     ┌─────────┐      ┌──────────┐
│greenday │     │daftpunk │      │ sophon   │
│firewalld│     │firewalld│      │firewalld │
│ Docker  │     │ Ollama  │      │ Ollama   │
│ AI user │     │ (WG IP  │      │ (WG IP   │
│ (lim.)  │     │  only)  │      │  only)   │
│         │     │ Grafana │      │ Frigate  │
└─────────┘     └─────────┘      └──────────┘
```

## Security Layers

### Layer 1: Network (firewalld + WireGuard)
- **firewalld:** Default deny all incoming. Only SSH (22/tcp), WireGuard (51820/udp), and on proxy: HTTP/HTTPS.
- **WireGuard:** All inter-server communication encrypted. No service listens on public interface except Caddy and SSH.
- **Ollama:** Binds to 10.66.0.x (WireGuard IP) only. Not accessible without VPN.
- **Grafana:** Binds to 10.66.0.3:3000 only. Proxied via Caddy at grafana.i.ar.
- **Frigate:** Binds to 10.66.0.5:8971. Proxied via Caddy at camaras.randazzo.ar.

### Layer 2: Host Hardening
- **SSH:** Key-only authentication (PasswordAuthentication no). Root login restricted to key-based (prohibit-password). No X11 forwarding, no agent forwarding. Max 3 auth tries, 30s login grace, 5min client alive interval.
- **Sysctl:** SYN cookies enabled, ICMP redirects disabled (send + receive), kptr_restrict=2, dmesg_restrict=1, IP forwarding enabled (for WG hub).
- **Automatic updates:** dnf-automatic timer enabled (security patches).
- **Admin user:** Non-root sudo user (`admin`) created on cloud servers with passwordless sudo. SSH key deployed.
- **Firewall:** firewalld running + enabled on all hosts (except yoga which is excluded from firewall management).

### Layer 3: Application
- **Caddy:** Automatic TLS via Let's Encrypt. Security headers on all sites: HSTS (max-age 1 year, includeSubDomains), X-Content-Type-Options nosniff, X-Frame-Options DENY, Referrer-Policy no-referrer. gzip + zstd compression.
- **Ollama:** No authentication built in -- relies entirely on network isolation (WireGuard IP only).
- **Docker/Podman:** AI agent has docker/podman access but limited sudo. Process/file limits set.

### Layer 4: AI Agent Isolation (greenday)
- **Separate user:** `ai-agent` with dedicated SSH key.
- **Resource limits:** Max 1000 processes (hard), 500 (soft). Max 50GB file size (hard), 10MB (soft).
- **Workspace structure:** /home/ai-agent/workspace/{projects,containers,scripts,data}
- **No access to other servers:** WireGuard config only allows agent's host to see the hub, not other peers.

### Layer 5: Fallback VPN (Cloudflare Tunnel)
- **Purpose:** If WireGuard UDP is blocked (corporate networks, hotels), Cloudflare Tunnel provides TCP-based fallback through Cloudflare's network.
- **Domain:** randazzo.net.ar (delegated to Cloudflare).
- **Setup:** cloudflared runs as systemd service on rammstein, creates outbound tunnel to Cloudflare. No inbound ports needed.
- **Access:** `cloudflared access ssh --hostname randazzo.net.ar` as SSH ProxyCommand.
- **Status:** Currently disabled (`cloudflare_tunnel_enabled: false`).

## Threat Model

| Threat | Mitigation |
|--------|-----------|
| Server compromise | firewalld + key-only SSH + automatic updates |
| Network sniffing | WireGuard encryption + TLS (Caddy) |
| Ollama API abuse | Binds to WG IP only -- requires VPN |
| AI agent runaway | Resource limits + limited sudo + Docker isolation |
| WG port blocked | Cloudflare Tunnel fallback (randazzo.net.ar) |
| Key compromise | Ansible Vault encryption + rotation procedure |
| DNS hijack | Registrar-locked + Cloudflare DNS |
| Provider outage | Full IaC -- rebuild from scratch in minutes |
| Data loss | All config in Git. No persistent state needed (except Frigate recordings) |

## Known Limitations

1. **Ollama has no authentication:** Relies entirely on network isolation. If WireGuard is compromised, Ollama is open. Consider adding a reverse proxy with auth.

2. **AI agent has Docker access:** Docker is root-equivalent in practice (can mount host filesystem). Resource limits are advisory, not enforced by cgroups. For stronger isolation, consider running agent inside a container itself or using Podman with SELinux.

3. **Single hub (rammstein):** If the proxy/hub goes down, the WireGuard mesh breaks. Peers can't reach each other. Acceptable at current scale but would need multi-hub design for larger deployments.

4. **Grafana admin password is in defaults:** `grafana_admin_password: "changeme"` is in role defaults, not vault. Should be moved to vault.

5. **No backup of runtime data:** IaC covers configuration, not data. Frigate recordings, AI-generated work, Grafana dashboards -- none are backed up.

## Secrets Management

**Vault file** (`inventory/group_vars/all/vault.yml`):
- Encrypted with ansible-vault (AES256)
- Contains: WireGuard private/public keys, Cloudflare API token, Cloudflare tunnel token, RTSP camera credentials
- Password file: `.vault_pass` (gitignored)
- Should contain but currently doesn't: `ai_agent_ssh_public_key` (currently in host_vars/greenday.yml in plaintext), `grafana_admin_password`

**Gitignored files:**
- `.vault_pass` -- vault password
- `wg-keys/` -- generated key files (delete after copying to vault)
- `*.private`, `*.key` -- any key files
- `.ansible/` -- fact cache and ansible-generated files
- `*.retry` -- ansible retry files

## WireGuard Security

- Private keys in encrypted vault, never in plaintext commits
- Key generation via `scripts/generate-wg-keys.sh` (one-time)
- Keys are per-host, not shared
- Hub-and-spoke topology limits blast radius (compromising a spoke doesn't expose other spokes' keys)
- PersistentKeepalive=25 keeps connections alive through NAT
- MTU 1420 (standard for WG overhead)