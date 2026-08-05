# Infrastructure Roles

Every Ansible role in the infrastructure repo, what it does, and where it runs.

## Role Summary

| Role | Runs On | Purpose |
|------|---------|---------|
| base | all hosts | System hardening, updates, packages, SSH, firewall, sysctl |
| wireguard | all hosts | WireGuard mesh VPN (hub-and-spoke topology) |
| caddy | cloud hosts | Caddy reverse proxy with automatic TLS |
| cloudflare-tunnel | proxy (rammstein) | Cloudflare Tunnel fallback VPN |
| podman | greenday, sophon | Podman + podman-compose installation |
| nvidia | sophon (GPU hosts) | NVIDIA proprietary drivers + container toolkit |
| ollama | daftpunk, sophon | Ollama installation + model pulling |
| ai-environment | greenday | AI agent user, SSH key, workspace, resource limits |
| frigate | sophon | Frigate NVR with NVIDIA TensorRT detection |
| monitoring | daftpunk | Prometheus + Grafana monitoring stack |
| node-exporter | all hosts | Prometheus node_exporter (host metrics) |
| portfolio-page | rammstein | Personal portfolio static site deployment |
| static-page | daftpunk | i.ar landing page static site deployment |

---

## base

**Runs on:** all hosts (yoga excluded from package updates/firewalld)

**What it does:**
- `dnf update` all packages to latest
- Install essential packages: vim, git, curl, wget, tmux, jq, python3, rsync, unzip, zstd, tar, net-tools, bind-utils
- Set timezone (America/Argentina/Buenos_Aires)
- Deploy hardened sshd_config (key-only auth, no X11 forwarding, no agent forwarding, max 3 auth tries, 30s login grace)
- Configure firewalld: allow SSH (22/tcp) and WireGuard (51820/udp)
- Install + enable dnf-automatic for security updates
- Apply sysctl hardening: IP forwarding (for WG), SYN cookies, no redirects, kptr/dmesg restrictions
- On cloud hosts: create `admin` user with wheel group, SSH key, passwordless sudo

**Templates:** `sshd_config.j2` -- hardened SSH configuration with configurable port, auth settings

**Handlers:** restart sshd

**Key variables:**
- `base_packages` -- list of essential packages (defined in group_vars/all)
- `base_sysctl_settings` -- list of sysctl key-value pairs (in defaults)
- `ssh_port` (default: 22), `ssh_password_auth` (default: "no"), `ssh_permit_root_login` (default: "prohibit-password")

---

## wireguard

**Runs on:** all hosts

**What it does:**
- Install wireguard-tools
- Create wg-quick@.service systemd unit if missing (AlmaLinux fallback)
- Generate `/etc/wireguard/wg0.conf` from template (hub gets all peers, spokes get hub only)
- Enable + start wg-quick@wg0
- Flush handlers on hub immediately (restarts hub before spokes connect -- prevents lockout)
- Enable IP forwarding on hub
- Configure firewalld: allow WG port, masquerade on hub, trusted WG interface

**Templates:** `wg0.conf.j2` -- generates per-host WireGuard config

**Topology:** Hub-and-spoke. rammstein is the hub (`wg_hub: rammstein`). All spoke traffic routes through hub. Spokes set `AllowedIPs = 10.66.0.0/16` (entire WG network via hub). Hub lists each peer individually with `/32` AllowedIPs.

**Handlers:** reload systemd, restart wireguard

**Key variables:**
- `wg_interface` (wg0), `wg_port` (51820), `wg_network` (10.66.0.0/16)
- `wg_keepalive` (25), `wg_mtu` (1420), `wg_dns` (10.66.0.1)
- `wg_private_keys`, `wg_public_keys` -- dicts keyed by hostname, from vault
- `wg_ip` -- per-host WG IP (in host_vars)
- `wg_endpoint` -- public endpoint for cloud hosts (in host_vars), absent for local hosts

**Critical ordering:** Hub must be configured and restarted BEFORE spokes. Enforced by playbook serial ordering + `meta: flush_handlers` on hub.

---

## caddy

**Runs on:** cloud hosts (rammstein, greenday, daftpunk)

**What it does:**
- Add Caddy COPR repo, install Caddy
- Create web roots: /var/www/randazzo.ar (rammstein), /var/www/emacboros (daftpunk)
- Deploy per-host Caddyfile from template (each host only defines domains it serves)
- Open HTTP/HTTPS in firewalld
- Enable + start Caddy

**Templates:** `Caddyfile.j2` -- per-host site config with TLS, security headers, reverse proxies

**Caddyfile per host:**
- rammstein: randazzo.ar (static portfolio), randazzo.com.ar (redirect), camaras.randazzo.ar (reverse proxy to Frigate on 10.66.0.5:8971)
- daftpunk: i.ar (static landing page), grafana.i.ar (reverse proxy to Grafana on 10.66.0.3:3000)
- greenday: 0b.ar (reverse proxy to 127.0.0.1:80, AI playground)

**Handlers:** reload caddy, restart caddy

**Key variables:**
- `caddy_email` (ignacio@randazzo.ar), `caddy_config_path` (/etc/caddy/Caddyfile)
- `domains` dict: proxy, proxy_alt, ollama, ai (in group_vars/all)
- `static_page_root`, `portfolio_page_root` (in role defaults)

---

## cloudflare-tunnel

**Runs on:** proxy hosts (rammstein), conditional on `cloudflare_tunnel_enabled`

**What it does:**
- Add Cloudflare COPR repo, install cloudflared
- Create tunnel named `randazzo-fallback` if it doesn't exist
- Install tunnel as systemd service
- Enable + start cloudflared
- Create DNS route for fallback domain (randazzo.net.ar)

**Key variables:**
- `cloudflare_tunnel_enabled` (default: false, set in host_vars/rammstein.yml)
- `cloudflare_domain` (randazzo.net.ar)
- `cloudflare_tunnel_token` (from vault)

**Note:** Currently disabled (`cloudflare_tunnel_enabled: false` in rammstein host_vars).

---

## podman

**Runs on:** greenday, sophon (conditional on podman_enabled)

**What it does:**
- Install EPEL on cloud hosts (AlmaLinux needs it, Fedora doesn't)
- Install podman + podman-compose
- Enable + start podman service

**Key variables:**
- `podman_enabled` (default: false, set true in host_vars where needed)

---

## nvidia

**Runs on:** sophon (GPU hosts), conditional on `ollama_gpu` or `frigate_enabled`

**What it does:**
- Check if nvidia-smi is available (driver already loaded?)
- If not loaded: enable RPM Fusion nonfree repo, install akmod-nvidia + xorg-x11-drv-nvidia-cuda
- Wait for akmod kernel module build to complete (2-5 minutes)
- Notify operator that reboot is required
- If driver IS loaded: add NVIDIA container toolkit repo, install toolkit, generate CDI spec for Podman, enable nvidia-cdi-refresh service

**Two-run pattern:** First run installs drivers (needs reboot). Second run (after reboot) installs container toolkit. The role detects which phase it's in via nvidia-smi availability.

**Handlers:** rebuild initramfs (dracut --force)

**Key variables:**
- `nvidia_driver_packages` (akmod-nvidia, xorg-x11-drv-nvidia-cuda)
- `nvidia_container_packages` (nvidia-container-toolkit)

---

## ollama

**Runs on:** daftpunk, sophon (conditional on `ollama_enabled`)

**What it does:**
- Create ollama system user (no login shell)
- Create models directory (/usr/share/ollama)
- On GPU hosts: check nvidia-smi before proceeding (skip if driver not loaded yet -- needs reboot)
- Download + install Ollama via official install.sh
- Create systemd service from template
- Create environment override (OLLAMA_HOST, OLLAMA_MODELS)
- Enable + start Ollama
- Pull specified models (async, 600s timeout per model)

**Templates:** `ollama.service.j2` -- systemd unit for Ollama

**Handlers:** restart ollama

**Key variables:**
- `ollama_version` ("" = latest, do NOT use "latest" string -- causes 404)
- `ollama_port` (11434), `ollama_install_dir` (/usr/local/bin), `ollama_models_dir` (/usr/share/ollama)
- `ollama_user` (ollama), `ollama_listen` (0.0.0.0 default, overridden to WG IP in host_vars)
- `ollama_gpu` (false default, true for sophon)
- `ollama_models` (list, per-host in host_vars)

**Fedora 44 gotcha:** Ollama's install.sh tries to install CUDA drivers itself via `dnf config-manager --add-repo` which was removed in dnf5/Fedora 44. The nvidia role handles driver installation via RPM Fusion instead. The ollama role skips install until nvidia-smi is available to avoid the broken path.

---

## ai-environment

**Runs on:** greenday (ai_playground group)

**What it does:**
- Create `ai-agent` user with bash shell
- Deploy SSH public key for ai-agent (from host_vars, originally from vault)
- Create workspace directories: workspace/{projects,containers,scripts,data}
- Set resource limits: 500 soft/1000 hard nproc, 10MB/50GB fsize
- Deploy tmux config (mouse, 50k history, vi keys, status bar)
- Deploy bash profile (custom PS1, PATH with workspace/scripts, vim editor)
- Ensure podman is running

**Key variables:**
- `ai_agent_ssh_public_key` (in host_vars/greenday.yml, should be in vault)

---

## frigate

**Runs on:** sophon (frigate_hosts group), conditional on `frigate_enabled`

**What it does:**
- Verify NVIDIA GPU present (fail if missing and using tensorrt image)
- Create directories: base, config, storage, external media mount
- Deploy config.yaml from template (cameras, ffmpeg hwaccel, record retention, go2rtc streams)
- Deploy docker-compose.yml from template (Podman Compose with GPU device, shm, tmpfs cache)
- Create + enable systemd service for Frigate (runs podman-compose up/down)
- Start Frigate

**Templates:**
- `config.yaml.j2` -- Frigate config with cameras, NVIDIA hwaccel, retention policies, go2rtc restream
- `docker-compose.yml.j2` -- Podman Compose with privileged container, GPU device, shm_size 2GB, tmpfs cache 1GB
- `frigate.service.j2` -- systemd unit running podman-compose

**Handlers:** restart frigate, restart podman

**Key variables:**
- `frigate_image` (ghcr.io/blakeblackshear/frigate:stable-tensorrt)
- `frigate_base_dir` (/home/nacho/containers/frigate)
- `frigate_media_mount` (/run/media/nacho/DATA) -- external storage for recordings
- `frigate_shm_size` (2048mb), `frigate_tmpfs_cache_size` (1GB)
- `frigate_web_port` (8971), `frigate_rtsp_port` (8554), `frigate_webrtc_tcp_port` (8555)
- `frigate_cameras` -- dict of cameras (in host_vars/sophon.yml), each with rtsp_host, rtsp_path, roles
- `frigate_camera_rtsp_user`, `frigate_camera_rtsp_password` -- from vault
- Retention: continuous 3d, motion 7d, alerts/detections 30d

**Cameras (8 total):**
- interior_1/2/3 (192.168.2.201-203, detect+record)
- exterior_1/2/3/4/5 (192.168.2.101-105, detect+record+audio)

---

## monitoring

**Runs on:** daftpunk (after podman role)

**What it does:**
- Create directories: /opt/monitoring (compose), /var/lib/monitoring/{prometheus,grafana}
- Deploy compose.yml (Prometheus + Grafana containers, WG-IP-only binds)
- Deploy prometheus.yml (scrape configs for all 5 hosts + cAdvisor on 3 hosts)
- Deploy alert_rules.yml (host down, high CPU/mem/disk, container down, WG interface down)
- Start stack with podman-compose
- Create + enable systemd service for boot persistence

**Templates:**
- `compose.yml.j2` -- Prometheus + Grafana in Podman Compose, bound to 10.66.0.3
- `prometheus.yml.j2` -- scrape configs: self, node_exporters (all 5 WG IPs:9100), cadvisor (3 hosts:8081)
- `alert_rules.yml.j2` -- alert rules (wrapped in {% raw %} to protect Prometheus $labels syntax from Jinja2)

**Handlers:** restart monitoring, reload systemd

**Key variables:**
- `prometheus_version` (v2.52.0), `prometheus_retention` (30d), `prometheus_port` (9090)
- `grafana_version` (11.0.0), `grafana_port` (3000)
- `grafana_admin_user` (admin), `grafana_admin_password` (changeme -- should be in vault)
- `monitoring_compose_dir` (/opt/monitoring)
- `monitoring_data_dir` (/var/lib/monitoring)

**Alert rules:**
- HostDown (critical, 2m) -- node_exporter unreachable
- HighCpuUsage (warning, 5m) -- CPU > 80%
- HighMemoryUsage (warning, 5m) -- memory > 90%
- LowDiskSpace (warning, 10m) -- disk > 90%
- ContainerDown (warning, 2m) -- container unseen for 5m
- ContainerHighCpu (warning, 5m) -- container CPU > 90%
- WireGuardInterfaceDown (critical, 2m) -- wg0 carrier down
- HighScrapeLatency (info, 5m) -- scrape > 2s

---

## node-exporter

**Runs on:** all hosts

**What it does:**
- Create node-exporter system user
- Download node_exporter binary from GitHub releases
- Install to /usr/local/bin/node_exporter
- Deploy systemd service (listens on WG IP only, hardened: NoNewPrivileges, ProtectHome, PrivateTmp, ProtectKernelModules/Tunables)
- Enable + start

**Templates:** `node_exporter.service.j2` -- systemd unit binding to WG IP

**Handlers:** restart node_exporter

**Key variables:**
- `node_exporter_version` (1.8.1)
- `node_exporter_port` (9100)
- `node_exporter_user` (node-exporter)
- `node_exporter_bin` (/usr/local/bin/node_exporter)
- `wg_ip` -- per-host WG IP (used for listen address)

---

## portfolio-page

**Runs on:** rammstein

**What it does:**
- Deploy index.html, style.css, script.js to /var/www/randazzo.ar (owned by caddy user)
- Caddy serves these via file_server -- no separate HTTP server process

**Files:** `files/index.html`, `files/style.css`, `files/script.js`

**Key variables:**
- `portfolio_page_root` (/var/www/randazzo.ar)

---

## static-page

**Runs on:** daftpunk, conditional on `tool_static_page_enabled`

**What it does:**
- Deploy index.html, style.css, script.js to /var/www/emacboros (owned by caddy user)
- Caddy serves these via file_server

**Files:** `files/index.html`, `files/style.css`, `files/script.js`

**Templates:** `static-page.service.j2` -- Python HTTP server fallback (not used when Caddy file_server is active)

**Key variables:**
- `static_page_root` (/var/www/emacboros)