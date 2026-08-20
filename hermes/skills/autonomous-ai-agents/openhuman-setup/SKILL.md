---
name: openhuman-setup
description: Use when setting up or troubleshooting OpenHuman on Windows.
---

# OpenHuman Setup & Ops (Windows)

OpenHuman = desktop AI agent (Rust + Tauri, React 19) by TinyHumans AI. On this user's Windows machine it is the ADE counterpart to Orca (Linux). Install at `C:\Users\luukhoahoc\AppData\Local\OpenHuman\OpenHuman.exe`; workspace `~/.openhuman`.

## Key paths
- Config (per user): `~/.openhuman/users/<user_id>/config.toml`
- Active profile pointer: `~/.openhuman/active_user.toml` → `user_id = "<id>"`
- Logs: `~/.openhuman/logs/openhuman.YYYY-MM-DD.log`
- agentmemory remote (user VM, often off): `https://mem.luukhoahoc.me` → Cloudflare 530 when VM down.

## CRITICAL: the profile-shadowing trap
First launch may create a separate empty `users/local/` profile and load `users/local/config.toml` instead of your configured profile (`users/6a85.../`). Symptom: app boots but 9router/model config ignored; `active_user.toml` empty/reset.
Fix (operator-side, see references/windows-ops.md):
1. Kill ALL OpenHuman.exe via PowerShell `Stop-Process -Name OpenHuman -Force` (MSYS `taskkill //F` unreliable).
2. Confirm down: `tasklist | grep -i openhuman` → none.
3. `rm -rf ~/.openhuman/users/local`
4. Write `active_user.toml` with real profile id via PowerShell `Set-Content` (NOT bash — MSYS path translation breaks this file).
5. Relaunch via PowerShell `Start-Process`.

## Setup reality: patch config.toml directly
OpenHuman's own agent CANNOT self-configure — sandbox-limited + prompt-injection guardrail blocks "auto-edit config / don't ask" prompts (red warning, halts). Operator edits `config.toml` instead. Safe toggles needing no OAuth: references/safe-config.md.

## agentmemory bridge (user opted OUT → local sqlite)
Docs: `[memory] backend = "agentmemory"` + `agentmemory_url`/`agentmemory_secret`. PITFALL: backend=agentmemory with daemon down = no sqlite fallback, every memory op errors. Only bridge when VM up. User keeps `backend = "sqlite"`.

## Verification
- TOML valid: PowerShell `python3 -c "import tomllib; tomllib.load(open(r'C:\...\config.toml','rb'))"` (bash tomllib fails on MSYS `/c/...`).
- Boot clean: log shows `[medulla] advertising N agents`, no panic.
- Features: `grep -nE '^enabled = true|^super_context_enabled = true|^level = "autonomous"' config.toml`.
- **Model + key after a change**: see `references/9router-vm-harness-swap.md` for the full recipe
  (all 6 harness files, the 4 OpenHuman edits, and the keychain 401 trap).

## CRITICAL: OpenHuman keychain 401 trap
UI error "authentication issue… check your API key" + log `9router returned HTTP 401: API key required`
= keychain `token` is null. Keys are in `~/.openhuman/dev-keychain.json`
(`<profile>:auth:provider:9router:default` → `{"token": "..."}`), NOT in config.toml.
**Never edit that JSON with PowerShell `ConvertTo-Json -Compress`** — it stringifies the value and
OpenHuman reads token=null → 401. Always edit via python (recipe in the reference). After fixing,
kill + relaunch OpenHuman for it to reload the keychain.

## Pitfalls
- Windows: use PowerShell for process/file ops on OpenHuman paths (MSYS bash cat/printf/rm misbehave on `~/.openhuman/active_user.toml`).
- OpenHuman cannot read Hermes memory; agentmemory is separate (VM often off to save $).
- "GitHub Actions" confusion: user CI is GitLab (`gitlab.vppos.vn`) for erp-admin; the GitHub Action booting Azure VM is in `Dev-Work/dotfiles` (cron 0 2 * * * = 9am ICT), unrelated to GitLab CI.
