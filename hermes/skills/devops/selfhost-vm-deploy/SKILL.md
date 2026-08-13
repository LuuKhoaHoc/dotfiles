---
name: selfhost-vm-deploy
description: "Deploy AI services (9router, agentmemory) on a cloud VM."
version: 1.0.0
author: hermes-curator
license: MIT
metadata:
  hermes:
    tags: [devops, selfhost, azure, vm, 9router, agentmemory]
    related_skills: [agent-memory]
---

# Self-host services on a cloud VM

## When to Use

- User creates/owns a cloud VM (Azure or other) to run always-on AI services and wants help connecting, sizing, securing, or deploying to it.
- Moving a locally-running AI gateway (9router) or memory backend (agentmemory, supermemory self-host, mem0) onto a server so agents on multiple machines can share it 24/7.
- SSH to a newly created VM fails or the username/key is unknown.

Deploy always-on AI infra (LLM gateway, memory backend) on a cloud VM. Origin: user's GitHub-Education $100/12mo Azure credit, VM `9router-vm` hosting 9router (AI gateway) + agentmemory (memory). Verified 2026-08-13.

## 1. SSH access discovery (Azure portal-created VM)

- Portal "Generate new key pair" downloads a `.pem` into `~/Downloads/` (e.g. `9router-key.pem`). `chmod 600` before use.
- Username is NOT always `azureuser` — batch-test `azureuser`, `ubuntu`, then user's handle (this user's VM: `khoahoc`). Azure Ubuntu: password auth off, publickey only.
- `ssh -v -o IdentitiesOnly=yes -i <key> user@host` shows whether the key is offered/rejected — use it instead of guessing blindly.
- **Dynamic public IP trap (verified):** stopping/deallocating the VM (resize, or credit exhaustion) RELEASES a dynamic public IP → SSH times out on the old IP. Before any resize: pin **Static** IP (Portal → Networking → Public IP → Configuration → Assignment: Static; free). After a surprise SSH timeout, get the new IP from the portal Overview — the VM is usually fine.

## 2. Cost sizing (Azure B-series, ballpark 2026, varies by region)

| Size | RAM | ~$/mo | $100 credit lasts |
|---|---|---|---|
| B1s | 1GB | ~$7 | ~12 mo (RAM tight) |
| B1ms | 2GB | ~$13 | ~8 mo (sweet spot) |
| B2s | 4GB | ~$30 | ~3 mo (overkill for Node services) |

- $100/12mo credit → budget ≈ $8.3/mo. Resize (not recreate) is free: Stop (deallocate) → Size → Start — data kept, dynamic IP changes (see trap above).
- RAM math: Ubuntu ~250MB + each Node service ~300–500MB → 1GB needs swap and risks OOM; 2GB is comfortable for 2 Node services.

## 3. Base setup on the VM

- Node LTS via NodeSource: `curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash - && sudo apt-get install -y nodejs`
- `rsync` may be missing on Ubuntu minimal — `sudo apt-get install -y rsync`.

## 4. 9router (AI gateway, port 20128)

- Install: `npm install -g 9router`.
- Data lives in `~/.9router/`: `db/data.sqlite` (provider pool + logged-in sessions — can be 800MB+), `auth/`, `jwt-secret`, `machine-id`, `models.json`, bundled `bin/cloudflared`.
- Cloning the gateway to a new machine = rsync `~/.9router/`, **excluding `logs/` and `db/backups/`** (bandwidth). `machine-id` + `jwt-secret` must come along or sessions break.
- `data.sqlite-wal` at 0B ⇒ DB consistent, safe to copy.
- Locally the daemon ran `node .../cli.js --tray --skip-update -p 20128`; on a server run headless under systemd.
- 9router bundles cloudflared → built-in Cloudflare Tunnel ("cloud sync + tunnel") for remote access.

## 5. agentmemory (memory backend, port 3111)

- **Package identity (verified via npm 2026-08-13):** server/CLI = `@agentmemory/agentmemory` (bin `agentmemory`, engines node ≥20). Bare npm name `agentmemory` is 404. `@agentmemory/mcp` is a thin shim re-exposing its MCP entrypoint.
- Local single-file data: `~/.agentmemory/standalone.json`.
- Client env: `AGENTMEMORY_URL` (+ `AGENTMEMORY_SECRET` when set). Viewer on 3113.
- **iii-engine required (verified):** first boot shows "install iii console" hint and the engine stays down until the native binary exists. Install: `curl -fsSL https://install.iii.dev/iii/main/install.sh | VERSION=0.11.2 sh` → lands in `~/.local/bin/iii`; agentmemory pins 0.11.2. PATH must include `~/.local/bin` (systemd: `Environment=PATH=...`).
- First run auto-starts the engine (subsequent runs log "iii-engine is running"); zero-LLM mode by default (BM25 + on-device embeddings, no API key).
- **REST path is `/agentmemory/*`, not root** — health at `http://localhost:3111/agentmemory/health`.
- Auth: uncomment/set `AGENTMEMORY_SECRET=<random>` in `~/.agentmemory/.env` → Bearer required on all REST calls. Generate: `openssl rand -hex 24`.
- `--tools core` = 8 essentials (vs default 53) for lighter MCP footprint.

## 6. Security — never raw-expose gateway/memory ports

- An AI gateway on a public IP routes to the user's PAID subscriptions: anyone holding the gateway key burns the user's money. Memory backends hold personal data.
- Treat the gateway API key as compromised if it ever touched a public repo (this user's 9router key appeared in public dotfiles history) — key rotation or strong access control required.
- Options best → last resort:
  1. **Cloudflare Tunnel** — 0 public ports, stable hostname, Cloudflare Access. Recommended; 9router has it built-in; other services via `cloudflared tunnel`.
  2. **Tailscale** mesh (VM + user machines, no open ports).
  3. **NSG allowlist** of home IPs — breaks when the IP is dynamic/changes.
  4. Public + API key alone — last resort.
- Azure default NSG: only SSH (22) inbound.

## 6b. Cloudflare Tunnel — verified flow (2026-08-13)

- Install: `curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared && chmod +x`.
- **Login quirk (cost us 2 retries):** `cloudflared tunnel login` prints a URL and polls. If the process dies (killed, ssh timeout), the cert NEVER lands — the user may still see the CF "Success" page from an earlier URL whose process is dead. Rule: start login, keep it alive, hand the EXACT fresh URL to the user, and wait for `~/.cloudflared/cert.pem` (watch with a background poll loop).
- Kill login safely: `pkill -x cloudflared` — NEVER `pkill -f "cloudflared tunnel login"` (pattern matches the shell running the script → self-kill, exit 255).
- Inside an `ssh '...'` single-quoted script, `setsid bash -c "cmd >log 2>&1" &` keeps the process alive after ssh returns; the ssh session itself will hang until timeout — fine, the URL is in the log file.
- Then: `cloudflared tunnel create <name>` → UUID; write `~/.cloudflared/config.yml`:
  ```yaml
  tunnel: <UUID>
  credentials-file: /home/<user>/.cloudflared/<UUID>.json
  ingress:
    - hostname: router.example.com
      service: http://localhost:20128
    - hostname: mem.example.com
      service: http://localhost:3111
    - service: http_status:404
  ```
- DNS: `cloudflared tunnel route dns <name> router.example.com` (+ one per hostname) — adds proxied CNAMEs.
- Run as systemd user unit (cert/creds live under the user's home):
  `ExecStart=/usr/local/bin/cloudflared tunnel --config /home/<user>/.cloudflared/config.yml run`
- **Local DNS negative-cache trap (verified):** minutes after adding CNAMEs, the local stub resolver (systemd-resolved; Tailscale MagicDNS on the machine makes it worse) may serve cached NXDOMAIN → `curl` fails instantly (HTTP 000) even though `dig @8.8.8.8` resolves. Fix: `resolvectl flush-caches`. Public resolvers work, stub doesn't → flush, don't rebuild anything.
- First requests may hit a CF "Just a moment…" managed challenge — usually transient; retry after DNS flush / a minute before touching Bot Fight Mode settings.

## 7. Point local agents at the VM

- Hermes: `custom_providers.9router.base_url`; opencode `models.yml` baseUrl; omp config; `AGENTMEMORY_URL` in MCP envs.
- **Hermes config guard (verified):** the agent patch tool REFUSES `~/.hermes/config.yaml` ("security-sensitive"). Sanctioned path: `hermes config set custom_providers.0.base_url https://router.example.com/v1` (list index supported: `custom_providers.0.base_url`), verify with `hermes config get custom_providers`.
- **Never blind-copy the dotfiles config onto the live config** — diff first (`diff ~/.hermes/config.yaml dotfiles/hermes/config.linux.yaml`); the live file is often newer (`_config_version` higher, extra keys). Patch the live file via `hermes config set`, and let the sync script's push direction refresh the repo copy later.
- Keep the local fallback: reverting = edit one line per config.

## 8. systemd units + firewall (B1ms VM, verified)

- 9router headless: `ExecStart=/usr/bin/9router -n --skip-update -H 127.0.0.1` (bind loopback; tunnel is the only ingress). `User=<vm-user>` so it reads `~/.9router`. `Restart=always`, `RestartSec=5`.
- agentmemory: `Environment=PATH=/home/<user>/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`, `ExecStart=/usr/bin/agentmemory --tools core`.
- cloudflared unit as above (section 6b). Enable all three: `sudo systemctl enable --now`.
- Firewall: `sudo ufw default deny incoming && sudo ufw default allow outgoing && sudo ufw allow OpenSSH && sudo ufw --force enable` — only 22 public; tunnel is outbound so unaffected. Verify: `sudo ufw status verbose`.
- Write unit files locally then `scp` them — nested heredocs inside `ssh '...'` break (exit 255, empty output).

## Pitfalls

- SSH timeout after resize/stop ≠ VM dead — check portal for the new dynamic IP.
- Never store VM IPs/keys in this skill — they rotate.
- Guessing usernames is fine for a few tries; then ask the user (they chose it in the portal).
- Copying a large sqlite over home uplink: rsync in background, exclude logs/backups.
