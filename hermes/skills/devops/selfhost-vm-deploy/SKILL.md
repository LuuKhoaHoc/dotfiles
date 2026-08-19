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
- **Update flow (verified 2026-08-15, 0.5.50 → 0.5.55):** `sudo systemctl stop 9router` → `sudo npm i -g 9router@latest --prefer-online` → **npm ≥11 blocks postinstall scripts by default** (`allow-scripts` warn) → re-run with `sudo npm i -g --allow-scripts=9router 9router@latest --prefer-online` so the package's postinstall hook runs → `sudo systemctl start 9router` → verify `9router --version` + `journalctl -u 9router -n 15` shows `🚀 9router v0.5.55` → health check through the tunnel: `curl -H "Authorization: Bearer $9ROUTER_API_KEY" https://router.<domain>/v1/models`. agentmemory (LLM backend `127.0.0.1:20128`) recovers on its own after the ~20s downtime. Service keeps `--skip-update` in ExecStart so it never self-upgrades behind your back.
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
- **MCP shim**: `agentmemory mcp` (= `npx @agentmemory/mcp`) is a **stdio-only** MCP server (7 tools: `memory_recall`, `memory_save`, `memory_sessions`, `memory_smart_search`, `memory_export`, `memory_audit`, `memory_governance_delete`). Stdio-only → unusable by remote harnesses; wire local harnesses via a local REST bridge instead (full harness migration playbook, per-harness configs, Zed JSONC editing, codex auth gotcha): `references/agentmemory-harness-mcp-wiring.md`. **Hermes provider = OFFICIAL plugin** (repo `integrations/hermes/` → `~/.hermes/plugins/agentmemory`; env `AGENTMEMORY_URL`/`AGENTMEMORY_SECRET`, preloads `~/.agentmemory/.env`) — the hand-rolled provider fork was retired 2026-08-15 (only one provider named `agentmemory` may register); re-patch its `_api()` User-Agent after every plugin update (CF 1010). **`/agentmemory/sessions` is GET** (POST → 405).

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
- VM lifecycle (midnight auto-shutdown → 09:00 cron start, NO az CLI): see `references/azure-vm-lifecycle.md` + `references/azure-device-auth.md`, script `scripts/azure-vm-start.py` (SERVICE-PRINCIPAL client_credentials version — device code does NOT work for GitHub-Edu-claimed accounts; role must be on the subscription that contains the VM).
- Write unit files locally then `scp` them — nested heredocs inside `ssh '...'` break (exit 255, empty output).

## Pitfalls

- SSH timeout after resize/stop ≠ VM dead — check portal for the new dynamic IP.
- Never store VM IPs/keys in this skill — they rotate.
- Guessing usernames is fine for a few tries; then ask the user (they chose it in the portal).
- Copying a large sqlite over home uplink: rsync in background, exclude logs/backups.

## 9router API key rotation — verified mechanics (2026-08-13, v0.5.50)

- Key format: `sk-<machineId16hex>-<keyId6 [a-z0-9]>-<hmac8>` where hmac = HMAC-SHA256(`API_KEY_SECRET` env || `"endpoint-proxy-api-key-secret"`, machineId+keyId), hex, first 8.
- `validateApiKey` = **exact full-string match** (`SELECT isActive FROM apiKeys WHERE key = ?`) — machineId prefix alone does NOT authenticate `/v1/chat/completions` (a fabricated `sk-<machineId>-...` gets 401). `/v1/models` is public (no check).
- CLI admin token: header `x-9r-cli-token` = sha256(`machineId-file` + `"9r-cli-auth"` + `auth/cli-secret`).hex.substring(0,16). Endpoints: `GET/POST /api/keys`, `DELETE /api/keys/{id}`.
- **The full key is only in the server's in-memory sql.js DB**; disk persist and API responses are display-masked (`sk-xxx...yyyy`) — and the harness redacts key-like strings in terminal output too. To recover a created key: read it from the DB with a script (`SELECT key FROM apiKeys WHERE machineId='...'`) piped straight into config files, never printed.
- Rotation flow: `POST /api/keys {name}` → fetch full key from DB → update client configs (Hermes `~/.hermes/.env` `9ROUTER_API_KEY`, omp `models.yml` apiKey) → `DELETE /api/keys/{oldId}` → verify old key 401 on completions, new key 200. After deletion the old key dies immediately (exact-match against table).
- Dashboard login is bcrypt password in `settings.data.password` (default `123456` only if unset). Resetting it = write a bcryptjs hash into the settings JSON.
- **Syncing OAuth re-logins local → VM (verified 2026-08-13):** after re-OAuth'ing accounts on the LOCAL 9router, do NOT rsync the whole `data.sqlite` over the VM file — the VM DB has its own newer rows (apiKeys — the rotated gateway key — usage, sweep-updated `updatedAt`). Instead: rsync local `db/data.sqlite` to `/tmp/data_local.sqlite`, stop the VM service, back up the VM DB, then merge ONLY `providerConnections` by id (UPDATE all columns incl. `data` token — never touch apiKeys/settings/kv/usage), restart. Sweep pattern to recognize VM-side noise: several rows with identical `updatedAt` to the second = health-check sweep, not a real OAuth.

## Azure VM auto-start automation (verified 2026-08-14)

- **Don't fight `az` CLI via pip/uv on a Hermes host**: uv tool shim is broken (`PYTHONPATH=bin/src`), modern azure-cli hits `time.clock` (py<3.8 API) and `conflicting subparser: check-name`. Instead: plain Python script + REST API + **service principal client_credentials** — token fetched fresh each run, no login, never expires.
- **GitHub-Edu-claimed Azure accounts CANNOT device-code login**: the account is a GitHub-federated guest in a special tenant — `login.microsoftonline.com/common` returns "You can't sign in here with a personal account", `/consumers` returns AADSTS9002332 (ARM is AAD-only). `az login` device flow fails the same way. The ONLY cron-safe path is an Entra App Registration + client secret + RBAC role (user does this once in portal, ~5 min).
- **Create SP in portal**: Microsoft Entra ID → App registrations → New (name `cron-vm-start`) → record Application(client) ID + Directory(tenant) ID → Certificates & secrets → New client secret (copy Value once!) → Subscriptions → the RIGHT subscription → Access control (IAM) → Add role assignment.
- **Pitfall — two similar roles**: `Classic Virtual Machine Contributor` (d73bb868-…) has NO ARM `Microsoft.Compute/virtualMachines/read` → every VM API call 403 (`AuthorizationFailed`). Pick plain **`Virtual Machine Contributor`** (9980e02c…). Verify role via `GET .../providers/Microsoft.Authorization/roleAssignments?api-version=2022-04-01&$filter=assignedTo('<objectId>')`.
- **Pitfall — wrong subscription**: portal VM-create defaults to the FIRST subscription in the list; the SP only sees subscriptions it has a role on (SP's `GET /subscriptions` lists only those). Check the VM's Overview → Subscription ID, assign the role there, and make the script scan ALL visible subscriptions (VM may sit in a sub named like "Azure subscription 1" while "Azure for Students" is empty). This user's VM: sub `a3dd571b-8e6d-4a97-8c40-f5cb35640612` ("Azure subscription 1"), RG `9router-rg` — the "Azure for Students" sub `9de1e9e3-e8c7-47f9-b29b-aa0e70966d6e` is empty.
- **Script pattern**: `~/.local/bin/azure-vm-start` — reads creds from `~/.azure-vm-start.json` (chmod 600: client_id/tenant_id/client_secret), POSTs `https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token` with `grant_type=client_credentials`, `scope=https://management.core.windows.net/.default`; then `GET /subscriptions` → per sub `.../providers/Microsoft.Compute/virtualMachines` → find VM → POST `{vmId}/start?api-version=2023-03-01` → poll `{vmId}/instanceView` for `PowerState/running` (6×20s). Exit codes: 0 running/started, 1 not yet running, 2 auth, 3 not found. Run it from GitHub Actions schedule (see "Cron scheduling" below — a Hermes-local cron misses the 9am slot when the laptop is off).
- If Azure ever returns 403 on a resource that the portal shows exists: that's Azure hiding 404s for unauthorized principals — fix the role, don't assume the resource vanished.
- **Pitfall — `/start` POST: BOTH `method="POST"` AND a body are required (verified 2026-08-15 + 2026-08-17):** layer 1 — `urllib.request.urlopen` issues GET unless `method="POST"` is set on the Request; Azure answers GET on `{vmId}/start` with `405 Method Not Allowed`. Layer 2 (found later) — urllib sends **NO `Content-Length` header on a bodyless POST**, and Azure then intermittently returns 405 **or 411** depending on hop → the failure is FLAKY: 2026-08-15 GH schedule failed `Start HTTP 405`, manual dispatches an hour later passed with identical code. Verified with curl: `-X POST` + no CL → `411 Length Required`; `-X POST -H "Content-Length: 0"` → `202 Accepted`. Fix: `post_action()` passes `data=b""` (urllib then emits `Content-Length: 0`) AND the start call retries 3× for transient HTTP errors. Same fix in the local script and the GH Actions copy (`dotfiles .github/workflows/azure_vm_start.py`, commit 4c9147c); `scripts/azure-vm-start.py` here is the verified version. See `references/azure-arm-urllib-405.md` for the full repro recipe.

### Cron scheduling: local machine is OFF before 9am (verified 2026-08-14)

- Hermes cron jobs run on the LOCAL machine — laptop closed at schedule time = job silently never runs (no catch-up). Morning jobs (8:00-9:00) during commute are guaranteed misses.
- Rules that worked: (1) shift Hermes cron jobs to after the user's typical machine-on time (digest 9:30, gitlab reminder 10:00); (2) infrastructure jobs that must run regardless of the laptop (VM start) move OUT of Hermes cron into **GitHub Actions schedule** — runners always on, run weekends too; (3) remove the VM-start cron job from Hermes after GH Actions takes over (avoid double-start confusion).
- **GitHub Actions VM-start pattern** (lives in the user's dotfiles repo — public OK: creds are repo Secrets, never in files):
  - `.github/workflows/azure-vm-start.yml`: `on: { schedule: [{ cron: "0 2 * * *" }], workflow_dispatch: }` — 9:00 ICT = UTC+7. Single job: `actions/checkout@v5` (v4 emits Node-20 deprecation warning + spurious `git exit 128` annotation) then `python .github/workflows/azure_vm_start.py` with env from `${{ secrets.AZURE_CLIENT_ID / AZURE_TENANT_ID / AZURE_CLIENT_SECRET }}` (same service principal as the local script).
  - Script variant reads creds from env instead of the local json file; same REST flow; prints "VM already running — nothing to do" (exit 0, ~7s). GH Actions emails on scheduled-run failure — no Telegram notify needed.
  - Debugging a failed GH Actions run (unauthenticated annotations trick, `gh run view --log-failed`, `gh auth login` PTY failure mode, false-positive-success trap): see `references/github-actions-debug.md`.
- **Restart the Hermes gateway after adding MCP server config** (`hermes gateway restart` from a terminal OUTSIDE the gateway — the agent's own shell is blocked from restarting it, SIGTERM propagates): MCP servers connect once at gateway start; a gateway running before config changes never sees new servers, and cron sessions inherit the stale connections.

## agentmemory engine pitfalls (verified)

- Restarting the WORKER (`systemctl restart agentmemory`) while the old `iii` engine daemon survives leaves the engine serving stale worker routes → **every REST path 404s** (incl. `/agentmemory/health`) even though `is-active` is fine. Fix: `systemctl stop agentmemory && pkill -x iii && systemctl start agentmemory` — the worker spawns a fresh engine and routes come back (health 200).
- CF managed challenges ("Just a moment…") on tunnel hostnames are transient — retry after a minute; if persistent, check zone Bot Fight Mode / Security Level (free-plan dashboard toggles) or add a Configuration Rule for the two hostnames.

## agentmemory REST API + migration playbook (verified 2026-08-13, v0.9.28)

- Create memory: `POST /agentmemory/remember` `{content (required), type (pattern|preference|architecture|bug|workflow|fact), concepts (ARRAY — a string silently fails while still returning HTTP 201 with no memory), files, project}` → 201 `{memory: {...}}`. ALWAYS verify the response contains `memory.id` — 201 does NOT guarantee creation.
- List: `GET /agentmemory/memories?agentId=*` (agentId=* to bypass agent-scope isolation); `?latest=true` for isLatest only. Health: `GET /agentmemory/health` (auth'd).
- Search: `POST /agentmemory/search {query, limit}` — BM25; works with zero-LLM mode.
- Snapshot: `POST /agentmemory/snapshot/create` (needs `SNAPSHOT_ENABLED=true` in `~/.agentmemory/.env` + restart; `SNAPSHOT_INTERVAL=60`; writes git repo at `~/.agentmemory/snapshots/`); restore via `POST /agentmemory/snapshot/restore {commitHash}`.
- **Merge behavior**: `mem::remember` supersedes an existing memory when `jaccardSimilarity(content, existing) > 0.7` — the new content REPLACES the old (data loss, no concat). Short similar notes merge aggressively; distinct content is safe. Setting a distinct `project` prevents merging BUT **project-scoped memories got lost on restart in v0.9.28** (file store kept only recent keys) — avoid `project` for durable writes until verified.
- **Persistence**: engine state lives in the `file_based` KV at `./data/state_store.db` resolved against the engine's CWD. The systemd unit MUST set `WorkingDirectory=/home/<user>` or the store lands in an unwritable `/data` and nothing persists. Writes flush ~10s after the last mutation (debounced); after bulk writes, wait ~15s before restarting, then verify with a restart + count.
- **Migration recipe (supermemory cloud → agentmemory, verified)**: supermemory cloud API `POST /v3/documents/list {containerTags:["hermes"]}` → per doc `GET /v3/documents/{fullId}` (prefix IDs 404!) → classify clean notes (<2000 chars, not starting with `[USER]`) vs raw auto-captured transcripts (up to 350KB — SKIP, they poison BM25 recall) → consolidate related notes into a few distinct memories (no project, no concepts, verify memory.id) → wait 15s → restart → verify count.
- CF blocks Python urllib POSTs to tunnel hostnames (HTTP 403 error 1010, UA-signature ban on `Python-urllib/3.x`) — **fix: set a custom `User-Agent` header** (e.g. `agentmemory-hermes-plugin/1.0`) and local Python works through the tunnel (verified 2026-08-15). Node fetch is NOT blocked. Only as fallback: run from the VM against `http://127.0.0.1:3111`.
- **CF ALSO blocks the openai-python SDK UA (verified 2026-08-17):** HTTP 403 `Your request was blocked.` (body `text/plain`, `server: cloudflare`, `cf-ray` present) fires on the header `OpenAI/Python <ver>` / `OpenAI/Python X.Y.Z httpx/...` — the UA the OpenAI SDK sends on EVERY call. So Hermes (openai SDK based) hitting 9router through the tunnel gets intermittent 403s (per-session, e.g. reviewer model `cx/gpt-5.6-luna-review`, implementer `oc/deepseek-v4-flash-free`) even though curl with any other UA is 200. Retry loops never recover (WAF is deterministic per UA), and the 403s start on the day CF updates its bot-UA list — no local change needed to trigger it. Diagnosis: `curl -i` with `-A "OpenAI/Python 2.24.0"` reproduces instantly; `-A "curl/8.x"` or `Mozilla/5.0` passes. **Fix at the source:** Cloudflare dashboard → zone → Security → Configuration Rules → add rule for `router.luukhoahoc.me` (and `mem.…`) → **Skip** → toggle **Bot Fight Mode** (keeps BFM protecting the rest of the zone), or Security → Bots → turn Bot Fight Mode off entirely (simplest, whole-zone). Fast local workaround without touching CF: Hermes `custom_providers[].extra_headers: {User-Agent: Mozilla/5.0 …}` (feature exists for exactly this, PR #40033 — "gateway/WAF that rejects the OpenAI SDK's identifying headers"). Do NOT wait for retries; fix the WAF rule or the UA.
- Supermemory key for scripts: pass via a 0600 file on the VM (ssh stdin), never in argv.

## agentmemory LLM provider wiring (verified 2026-08-13, v0.9.28)

- **Detection order** (config detectProvider): OPENAI_API_KEY → MINIMAX → ANTHROPIC → GEMINI → OPENROUTER → noop. `OPENAI_API_KEY_FOR_LLM=false` opts out. Default model `gpt-4o-mini` — a gateway without that model id must set `OPENAI_MODEL`.
- **getMergedEnv() = {...loadEnvFile(), ...process.env} — process.env OVERRIDES ~/.agentmemory/.env.** An empty `OPENAI_API_KEY=` in the service env silently nullifies the real key from the .env file → provider becomes Noop (graph/extract answers in ~6ms, summarize returns `empty_provider_response`, no error logs).
- **ssh argv trap (cost us the key twice):** `ssh host 'script' _ "$KEY"` does NOT give the remote shell `$1=$KEY` — OpenSSH concatenates every post-hostname arg into one command string, so `$1` is empty and the file silently gets `KEY=`. Always pipe secrets over stdin: `printf 'KEY=%s\n' "$KEY" | ssh host 'cat > ~/.x/llm.env && chmod 600 ~/.x/llm.env'`. Verify by length: `awk -F= '{print length($2)}'`.
- **Engine (iii) inherits the worker's process env** (it spawns the engine), so LLM env must ALSO be in the systemd unit: `EnvironmentFile=-/home/<user>/.agentmemory/llm.env` (0600) with OPENAI_API_KEY/BASE_URL/MODEL. The .env file alone only reaches worker-side config, not the engine.
- **LLM features need an actual LLM call per batch**: consolidation, auto-compress, graph extraction. 9router (OpenAI-compatible) works: `OPENAI_BASE_URL=http://127.0.0.1:20128`, `OPENAI_API_KEY` = gateway key, `OPENAI_MODEL=openrouter/google/gemma-4-26b-a4b-it:free` (free, returns real `content`). Avoid `openrouter/openrouter/free` alias — it randomly routes to reasoning models that return `content: null` → graph extraction parses 0 nodes. `kc/*` models are paid (HTTP 402 without credits).
- 9router has NO embeddings (`400 No credentials for provider: openai`) → keep `EMBEDDING_PROVIDER=local`.
- **Xenova local embeddings cache is HARDCODED** to `<pkg>/node_modules/@xenova/transformers/.cache` (no env override) → `sudo mkdir -p` + `sudo chown -R <user>` that dir or embedding fails with EACCES and search silently runs BM25-only.
- **Graph extraction** (`GRAPH_EXTRACTION_ENABLED=true`): triggers async `mem::graph-extract` after observations land in a session (facts via /remember don't trigger it). Test directly: `POST /agentmemory/graph/extract {observations:[{id,title,narrative,concepts,files,type}]}` → real call takes 30-90s (free models), response `{nodesAdded, edgesAdded}`; ~6ms + zeros = Noop provider, fix env and restart worker+engine (`pkill -x iii`).
- Observe hook format: `POST /agentmemory/observe {hookType, sessionId, project, cwd, timestamp, data}` where data carries `userPrompt` / `assistantResponse` / `toolName`/`toolInput`/`toolOutput` (NOT `data.content` — that yields empty narratives).
- **LLM compression** (`AGENTMEMORY_AUTO_COMPRESS=true`): runs async; log shows `compress:"llm"` (vs `synthetic`); narrative/concepts get real LLM content (e.g. title "User Prompt Submission", concepts ["user input"]) while synthetic leaves them empty. Verify: observe → journalctl grep `compress:`.
- No memory DELETE API (405) — test memories persist; keep test content harmless/accurate.
- Viewer + REST on loopback only; SSH port-forward (`ssh -L 3113:localhost:3113 vm`) instead of exposing.

