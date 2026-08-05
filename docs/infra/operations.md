# Infrastructure Operations

## Initial Deployment

### Prerequisites
- Ansible installed on local machine
- SSH key (`~/.ssh/id_ed25519`)
- AI agent SSH key (`~/.ssh/ai_agent_key`)
- Vault password (`.vault_pass`)
- Git clone of this infrastructure repo
- Access to domain registrar (DNS pointing)
- Access to Cloudflare dashboard (for tunnel token, if using fallback)

### One-Time Setup

1. Generate WireGuard keys:
   ```bash
   ./scripts/generate-wg-keys.sh
   # Creates wg-keys/ with keypairs + vault-snippet.yml
   ```

2. Create vault password file:
   ```bash
   echo 'your-vault-password' > .vault_pass
   chmod 600 .vault_pass
   ```

3. Fill in vault secrets (WG keys from step 1, CF tokens, RTSP creds):
   ```bash
   vim inventory/group_vars/all/vault.yml
   ```

4. Encrypt vault:
   ```bash
   ansible-vault encrypt inventory/group_vars/all/vault.yml --vault-password-file .vault_pass
   ```

5. Update inventory with real IPs:
   ```bash
   vim inventory/hosts.yml
   vim inventory/host_vars/<host>.yml
   ```

6. Copy SSH keys to servers:
   ```bash
   ssh-copy-id root@<server-ip>
   ```

7. Run full deployment:
   ```bash
   ansible-playbook playbooks/site.yml --vault-password-file .vault_pass
   ```

8. Clean up generated keys:
   ```bash
   rm -rf wg-keys/
   ```

### NVIDIA Two-Run Pattern

For GPU hosts (sophon), the nvidia role requires two playbook runs:

1. **First run:** Installs akmod-nvidia + CUDA. Builds kernel module. Prints "REBOOT REQUIRED".
2. **Reboot the host.**
3. **Second run:** nvidia-smi now works. Installs container toolkit, generates CDI spec, completes Ollama/Frigate setup.

## Routine Operations

### Update All Hosts
```bash
ansible-playbook playbooks/site.yml --vault-password-file .vault_pass
# Ansible is idempotent -- re-running syncs to desired state
```

### Add a New Host
1. Generate WG keys: `wg genkey | tee /tmp/new.key | wg pubkey > /tmp/new.pub`
2. Add keys to vault: `ansible-vault edit inventory/group_vars/all/vault.yml`
3. Add host to `inventory/hosts.yml` with WG IP and group membership
4. Create `inventory/host_vars/<newhost>.yml`
5. Copy SSH key: `ssh-copy-id root@<newhost-ip>`
6. Run: `ansible-playbook playbooks/base.yml --vault-password-file .vault_pass --limit <newhost>`
7. Run: `ansible-playbook playbooks/wireguard.yml --vault-password-file .vault_pass`

### Rotate WireGuard Keys (Compromised Host)
1. Generate new keypair: `wg genkey | tee /tmp/new.key | wg pubkey > /tmp/new.pub`
2. Update vault: `ansible-vault edit inventory/group_vars/all/vault.yml`
3. Re-run: `ansible-playbook playbooks/wireguard.yml --vault-password-file .vault_pass`

### Pull a New Ollama Model
1. Add model to host_vars:
   ```yaml
   # inventory/host_vars/daftpunk.yml
   ollama_models:
     - "llama3.3:70b"
     - "new-model-name"
   ```
2. Run: `ansible-playbook playbooks/ollama.yml --vault-password-file .vault_pass --limit <host>`

### Edit Vault Secrets
```bash
ansible-vault edit inventory/group_vars/all/vault.yml --vault-password-file .vault_pass
```

## Disaster Recovery

### Full Rebuild (all servers lost)
1. Provision new servers, note new IPs
2. Update `inventory/hosts.yml` with new IPs
3. Update DNS at registrar to point to new proxy IP
4. If WG keys lost: run `./scripts/generate-wg-keys.sh`, update vault
5. If keys safe: just update IPs in inventory
6. Run: `ansible-playbook playbooks/site.yml --vault-password-file .vault_pass`
7. Verify: WG mesh (ping peers), web services (curl domains), Ollama (curl API)

### Single Server Replacement
1. Provision new server, note IP
2. Update inventory/host_vars with new IP
3. If replacing hub (rammstein): regenerate WG keys for it, update vault, re-run wireguard on all hosts
4. Run relevant playbook: `ansible-playbook playbooks/<service>.yml --vault-password-file .vault_pass --limit <host>`

### Cloudflare Tunnel Token Compromise
1. Rotate token in Cloudflare dashboard
2. Update vault: `ansible-vault edit inventory/group_vars/all/vault.yml`
3. Re-run: `ansible-playbook playbooks/cloudflare.yml --vault-password-file .vault_pass`

### AI Agent SSH Key Compromise
1. Generate new keypair: `ssh-keygen -t ed25519 -f ~/.ssh/ai_agent_key`
2. Update vault or host_vars with new public key
3. Re-run: `ansible-playbook playbooks/ai_playground.yml --vault-password-file .vault_pass`
4. Manually remove old key from authorized_keys on greenday

## Health Check

```bash
# Check all hosts reachable
ansible all -i inventory/hosts.yml -m ping --vault-password-file .vault_pass

# Check WireGuard mesh
ssh root@<rammstein-ip> 'wg show wg0'

# Check web services
curl -I https://randazzo.ar
curl -I https://i.ar
curl -I https://0b.ar

# Check Ollama
curl http://10.66.0.3:11434/api/tags  # daftpunk (via WG)
curl http://10.66.0.5:11434/api/tags  # sophon (via WG)

# Check Grafana
curl -I https://grafana.i.ar

# Check Frigate
curl -I https://camaras.randazzo.ar
```

## Backup Checklist

Store in secure location (password manager, encrypted USB):

- [ ] `~/.ssh/id_ed25519` (Ansible SSH key)
- [ ] `.vault_pass` (vault password)
- [ ] `inventory/group_vars/all/vault.yml` (encrypted secrets)
- [ ] Cloudflare account credentials + API token
- [ ] Domain registrar credentials
- [ ] VPS provider credentials
- [ ] Git remote URL for infrastructure repo
- [ ] `~/.ssh/ai_agent_key` (AI agent private key)

## Useful Ansible Commands

```bash
# Ping all hosts
ansible all -m ping --vault-password-file .vault_pass

# Run with verbose output
ansible-playbook playbooks/site.yml --vault-password-file .vault_pass -vvv

# Check what would change (dry run)
ansible-playbook playbooks/site.yml --vault-password-file .vault_pass --check --diff

# Run with tags
ansible-playbook playbooks/site.yml --vault-password-file .vault_pass --tags nvidia

# Skip tags
ansible-playbook playbooks/site.yml --vault-password-file .vault_pass --skip-tags nvidia,frigate

# Limit to specific hosts
ansible-playbook playbooks/site.yml --vault-password-file .vault_pass --limit sophon
```