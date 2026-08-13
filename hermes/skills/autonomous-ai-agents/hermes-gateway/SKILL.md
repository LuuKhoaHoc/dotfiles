---
name: hermes-gateway
description: "Set up or operate the Hermes messaging gateway (Telegram)."
version: 1.0.0
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [hermes, gateway, telegram, remote, systemd, messaging]
---

# Hermes Gateway & Remote Access

Class: connecting Hermes to messaging platforms (Telegram, Discord, Slack, ...) so the user can reach the agent from their phone while away from the machine (code review, task delegation, ops). Verified on v0.20.0 (2026.8.3), Arch Linux.

## Quick path

1. Check state: `hermes gateway status` (if "Gateway is not running", proceed).
2. Configure platform: `hermes gateway setup` (interactive — needs PTY). Telegram offers:
   - **[1] Automatic managed bot** — QR scan in Telegram, token saved automatically (Nous onboarding service, manager bot `HermesSetupBot`). Needs a visible screen for the QR.
   - **[2] Manual BotFather token** — user creates bot via @BotFather on phone, pastes token. Most reliable when the agent relays setup over chat.
   - Token saved to `~/.hermes/.env` as `TELEGRAM_BOT_TOKEN` (secrets live in .env, NEVER config.yaml).
3. Restrict who can chat with the bot: `TELEGRAM_ALLOWED_USERS` (comma-separated user IDs) in .env — see `references/telegram-setup.md`.
4. Install as service:
   - **Boot-time, unattended laptop:** `sudo hermes gateway install --system --run-as-user <user> --start-now --start-on-login`
   - **Login-time only (user service):** `hermes gateway install --start-now --start-on-login`
5. Machine left unattended with lid closed:
   - Keep on AC (`/sys/class/power_supply/*/status`).
   - Stop lid-close suspend on AC only: `/etc/systemd/logind.conf` → `HandleLidSwitchExternalPower=ignore` → `sudo systemctl restart systemd-logind`. Leave battery lid behavior default so normal mobile use still suspends.
   - Sanity-check other suspenders: `systemctl list-inhibitors`.
6. Verify: `hermes gateway status`; message the bot from the phone; logs in `~/.hermes/logs/`.

## Gateway subcommands

- `run` (foreground — WSL/Docker/Termux) · `start` · `stop` · `restart` · `status` · `list` (all profiles) · `uninstall` · `setup` · `enroll` (relay connector) · `migrate-legacy` (remove pre-rename hermes.service units)
- `install [--force] [--system] [--run-as-user U] [--start-now|--no-start-now] [--start-on-login|--no-start-on-login]`

## What gateway sessions get

- Toolset per `platform_toolsets.<platform>` in config.yaml; `hermes-telegram` = full `_HERMES_CORE_TOOLS` (terminal, file, web, skills, memory, ...).
- Profile MCP servers (gitlab, codegraph, GWS, ...) are available to gateway sessions — remote code review and task assignment work out of the box.
- Approvals (`approvals.mode: smart`, 60s timeout default) apply; for unattended remote use, confirm approval prompts are answerable from the platform chat.
- Gateway idle behavior is configurable (`gateway.scale_to_zero.idle_timeout_minutes`, default 5).

## Pitfalls

- `skill_view(name='hermes-agent')` fails with **ambiguity** on this machine (`~/.hermes/skills/autonomous-ai-agents/hermes-agent.bak` collides with the real one) — load as `autonomous-ai-agents/hermes-agent`.
- `hermes gateway setup` is fully interactive; it asks "Reconfigure?" when `TELEGRAM_BOT_TOKEN` already exists. Managed-bot QR needs a screen the user can see — otherwise use BotFather manual path.
- Docs URL `https://hermes-agent.nousresearch.com/docs/user-guide/gateway` 404s — use local source as ground truth: `~/.hermes/hermes-agent/gateway/`, `hermes_cli/gateway.py`, `hermes_cli/telegram_managed_bot.py`, `plugins/platforms/telegram/adapter.py`.
- Telegram adapter is a **plugin** now (moved out of core, #41112): `telegram:` YAML block in config.yaml is bridged to `TELEGRAM_*` env vars by the plugin.
- `channels` config key does not exist / is unset — platform enablement is token-presence based (env var present → platform enabled).
- Never hand-edit config.yaml (`hermes config set` only); never put tokens in config.yaml.
- Do NOT add custom getUpdates-based liveness watchdogs (e.g. a `hermes-tg-watchdog` timer probing `getUpdates` via curl). Telegram allows only ONE getUpdates long-poll per bot token, so the probe itself causes 409 conflicts on a healthy gateway, and HTTP 200 (no poll open) fires whenever the gateway is busy processing a message — false-positive restarts that kill active tasks mid-conversation. Use the official built-in instead: `hermes config set gateway.systemd_watchdog_seconds 120` → `hermes gateway install --force` (unit becomes Type=notify + WatchdogSec; Hermes heartbeats only while the event loop makes progress — no Telegram API involvement). `hermes config set` warns "not a recognized config key" for it, but the key IS read by gateway/config.py.

## References

- `references/telegram-setup.md` — Telegram env vars, managed-bot vs BotFather flow, allowlist, plugin internals.
