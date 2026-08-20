# 9router on VM: harness swap + OpenHuman keychain auth

## Endpoint + key facts
- Local 9router used to run at `http://localhost:20128/v1` (old key `sk-b9f...9c51`).
- VM 9router gateway: `https://router.luukhoahoc.me/v1` (Cloudflare Tunnel → Azure VM `9router-vm`).
- Current VM key is handed over by the user per-session; NEVER commit it (dotfiles are PUBLIC).

## Files to edit when switching all harnesses to the VM gateway
Change `endpoint`/`base_url`/`baseURL`/`ANTHROPIC_BASE_URL` → `https://router.luukhoahoc.me/v1`
and the API key → the current VM key.

| Harness | File | Field(s) |
|---|---|---|
| OpenHuman | `~/.openhuman/users/<id>/config.toml` | `[[cloud_providers]]` slug=9router `endpoint`; keychain token (see below) |
| Hermes | `~/.hermes/config.yaml` | default provider block + `custom_providers` 9router block (TWO places) |
| OpenCode | `~/.config/opencode/opencode.json` | `provider.9router.options.baseURL` / `apiKey` |
| Codex | `~/.codex/config.toml` | `[model_providers.9router] base_url` |
| Claude | `~/.claude/settings.json` | `ANTHROPIC_BASE_URL` / `ANTHROPIC_AUTH_TOKEN` |
| Oh My Pi | `~/.omp/agent/models.yml` | `providers.9router.baseUrl` / `apiKey` |

Windows gotcha: edit OpenCode JSON with `write_file` (not PowerShell string-replace — it mangles tabs / adds UTF-8 BOM and breaks `json.load`). Verify with PowerShell `python3 -c "import json; json.load(open(r'...', encoding='utf-8-sig'))"`.

## OpenHuman model change = 4 edits, all required
1. Routes (9 lines): `chat_provider` / `reasoning_provider` / `agentic_provider` / `coding_provider` /
   `vision_provider` / `memory_provider` / `heartbeat_provider` / `learning_provider` /
   `subconscious_provider` → `"9router:ocg/<model>"` (e.g. `ocg/muse-spark-1.2`).
2. Add `[[model_registry]]` entry:
   ```toml
   [[model_registry]]
   id = "ocg/muse-spark-1.2"
   provider = "9router"
   cost_per_1m_input = 0.0
   cost_per_1m_cached_input = 0.0
   cost_per_1m_output = 0.0
   context_window = 1000000   # 9router under-reports; trust user-stated window
   vision = false
   ```
   Verify the model exists: `curl -s https://router.luukhoahoc.me/v1/models -H "Authorization: Bearer <KEY>"`.
3. `[[cloud_providers]]` slug=9router `endpoint` → `https://router.luukhoahoc.me/v1`.
4. API key in keychain (below).

## OpenHuman keychain auth — the silent 401 trap
Keys live in `~/.openhuman/dev-keychain.json`, NOT in config.toml. Structure:
```json
"6a85...:auth:provider:9router:default": {"access_token":null,"id_token":null,"refresh_token":null,"token":"<KEY>"}
```
Symptom of a wrong/missing key: UI says *"There's an authentication issue with the AI provider.
Please check your API key in settings."* and the log shows
`9router returned HTTP 401: {"error":"API key required for remote API access"}`.
That means the key sent was EMPTY → keychain `token` is null.

**PITFALL — do NOT edit the keychain with PowerShell `ConvertTo-Json -Compress`.** Re-serializing
writes a STRING into the value, which OpenHuman parses back as null → token=null → 401. Edit with
python instead:

```python
import json, os
f = os.path.expanduser('~/.openhuman/dev-keychain.json')
d = json.load(open(f, encoding='utf-8-sig'))
k = [x for x in d if '9router' in x][0]
v = d[k]
if isinstance(v, str):           # recover if already corrupted
    v = json.loads(v)
v = {'access_token': None, 'id_token': None, 'refresh_token': None, 'token': '<KEY>'}
d[k] = v
json.dump(d, open(f, 'w', encoding='utf-8'), indent=2, ensure_ascii=False)
```
Verify (must print `dict sk-...`, NOT `BROKEN`/`None`):
```python
python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.openhuman/dev-keychain.json'),encoding='utf-8-sig')); k=[x for x in d if '9router' in x][0]; print(type(d[k]).__name__, d[k].get('token') if isinstance(d[k],dict) else 'BROKEN')"
```
Then kill + relaunch OpenHuman (PowerShell `Stop-Process -Name OpenHuman -Force` then `Start-Process`).

## Cloudflare 1033 on router.luukhoahoc.me
`router.luukhoahoc.me` → 1033 = Cloudflare Tunnel down (cloudflared on VM not running). Root cause:
cloudflared + 9router are systemd units but NOT `enable`d, so after the VM boots (via the GitHub
Action `azure-vm-start.yml` in `Dev-Work/dotfiles`, cron `0 2 * * *` = 9am ICT) they start late or
not at all. `mem.luukhoahoc.me` (separate tunnel) usually comes up BEFORE `router.`, so seeing 1033
on `router.` while `mem.` is fine is normal during the boot window — just F5 later. Fix committed to
dotfiles: `azure-vm-start.yml` now SSHes in after boot and runs `systemctl enable --now cloudflared 9router`
so the tunnel is live immediately (needs `VM_SSH_KEY` + `VM_HOST` + `VM_SSH_USER` GitHub secrets).
