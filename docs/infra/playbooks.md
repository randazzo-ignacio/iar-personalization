# Infrastructure Playbooks

## Playbook Inventory

| Playbook | Hosts | Roles | Purpose |
|----------|-------|-------|---------|
| site.yml | all | everything (ordered) | Full infrastructure deployment |
| base.yml | all | base, wireguard | Hardening + WireGuard only |
| wireguard.yml | all (hub first) | wireguard | Re-keying or mesh changes |
| proxy.yml | proxy | caddy, cloudflare-tunnel | Caddy + CF Tunnel |
| ai_playground.yml | ai_playground | podman, ai-environment | AI playground setup |
| ollama.yml | ollama_hosts | podman?, nvidia?, ollama | Ollama installation |
| cloudflare.yml | proxy | cloudflare-tunnel | CF Tunnel only |
| monitoring.yml | all + daftpunk | node-exporter, monitoring | Monitoring stack |
| portfolio-page.yml | rammstein | portfolio-page | Portfolio deployment |
| static-page.yml | daftpunk | static-page | Landing page deployment |

---

## site.yml -- Master Playbook

Runs all roles in dependency order. This is the main entry point.

**Execution order:**

1. **base** on all hosts -- hardening, updates, packages, SSH, firewall, sysctl
2. **wireguard** on hub (rammstein) first -- config + flush handlers (restart hub)
3. **wireguard** on all other hosts (serial: 1) -- spokes connect to updated hub
4. **caddy** on cloud hosts -- reverse proxy + TLS
5. **cloudflare-tunnel** on proxy (conditional: `cloudflare_tunnel_enabled`)
6. **podman** + **ai-environment** on ai_playground hosts
7. **podman** (conditional) + **nvidia** (conditional, tagged) + **ollama** (conditional) on ollama_hosts
8. **static-page** on daftpunk (conditional: `tool_static_page_enabled`)
9. **portfolio-page** on rammstein
10. **podman** (conditional, tagged) + **nvidia** (tagged) + **frigate** (conditional, tagged) on frigate_hosts

**Usage:**
```bash
ansible-playbook playbooks/site.yml --vault-password-file .vault_pass
# Limit to cloud only:
ansible-playbook playbooks/site.yml --vault-password-file .vault_pass --limit cloud
# Skip NVIDIA (no GPU changes needed):
ansible-playbook playbooks/site.yml --vault-password-file .vault_pass --skip-tags nvidia
```

---

## base.yml

Base hardening + WireGuard only. For initial setup of new hosts or refreshing security config.

```bash
ansible-playbook playbooks/base.yml --vault-password-file .vault_pass
```

---

## wireguard.yml

WireGuard only. For re-keying or mesh topology changes.

**Critical ordering:** Hub (rammstein) configured and restarted FIRST, then spokes serially. Prevents spoke lockout when hub config changes.

```bash
ansible-playbook playbooks/wireguard.yml --vault-password-file .vault_pass
```

---

## proxy.yml

Caddy + Cloudflare Tunnel on proxy server (rammstein).

```bash
ansible-playbook playbooks/proxy.yml --vault-password-file .vault_pass
```

---

## ai_playground.yml

AI playground setup on greenday. Installs Podman, creates ai-agent user with SSH key, workspace, resource limits.

```bash
ansible-playbook playbooks/ai_playground.yml --vault-password-file .vault_pass
```

---

## ollama.yml

Ollama installation on ollama_hosts (daftpunk, sophon). Conditionally installs podman and nvidia drivers.

```bash
ansible-playbook playbooks/ollama.yml --vault-password-file .vault_pass
```

---

## cloudflare.yml

Cloudflare Tunnel only. For setting up or reconfiguring the fallback VPN.

```bash
ansible-playbook playbooks/cloudflare.yml --vault-password-file .vault_pass
```

---

## monitoring.yml

Monitoring stack deployment. Node exporters on all hosts, Prometheus + Grafana on daftpunk.

```bash
ansible-playbook playbooks/monitoring.yml --vault-password-file .vault_pass
```

---

## portfolio-page.yml

Deploys personal portfolio to rammstein. Caddy serves files from /var/www/randazzo.ar.

```bash
ansible-playbook playbooks/portfolio-page.yml --vault-password-file .vault_pass
```

---

## static-page.yml

Deploys i.ar landing page to daftpunk. Caddy serves files from /var/www/emacboros.

```bash
ansible-playbook playbooks/static-page.yml --vault-password-file .vault_pass
```

---

## Common Patterns

**All playbooks:**
- Use `--vault-password-file .vault_pass` (required, vault contains WG keys + secrets)
- Are idempotent -- re-running won't break anything, just syncs to desired state
- Target hosts via inventory groups, not individual hostnames
- Use `when` conditionals extensively so roles skip hosts that don't need them

**Tags available:**
- `nvidia` -- NVIDIA driver/toolkit tasks
- `frigate` -- Frigate NVR tasks

**Limit to specific hosts:**
```bash
--limit sophon        # one host
--limit cloud         # all cloud VPS
--limit local         # all local machines
--limit ollama_hosts  # all Ollama hosts
```