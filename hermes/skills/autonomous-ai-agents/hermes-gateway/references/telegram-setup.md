# Telegram platform (Hermes gateway) — internals

Verified against installed source v0.20.0 (2026.8.3): `~/.hermes/hermes-agent/`.

## Env vars (live in ~/.hermes/.env, secrets only)

- `TELEGRAM_BOT_TOKEN` — bot token; **presence enables the platform** (gateway/config.py: `Platform.TELEGRAM: "TELEGRAM_BOT_TOKEN"`).
- `TELEGRAM_ALLOWED_USERS` — comma-separated Telegram user-ID allowlist; only listed users may chat with the bot (plugins/platforms/telegram/adapter.py, `_scoped_gate_env("TELEGRAM_ALLOWED_USERS")`). Set this when configuring a new bot.
- `TELEGRAM_REPLY_TO_MODE` — reply-mode behavior (lowercased in gateway/config.py).
- `TELEGRAM_ONBOARDING_URL` — override for managed-bot pairing API (default `https://setup.hermes-agent.nousresearch.com`).
- Auth-gate vars are read per-profile (`_scoped_gate_env`; first-writer-wins under `gateway.multiplex_profiles`).

## Setup flow (`hermes gateway setup`)

Interactive wizard; Telegram/Discord/Slack share `_setup_standard_platform` in `hermes_cli/gateway.py`.

- **[1] Automatic managed bot** (`hermes_cli/telegram_managed_bot.py`): Telegram Managed Bots via Nous onboarding service (manager bot `HermesSetupBot`). QR → user confirms in Telegram → token + `owner_user_id` returned → `save_env_value("TELEGRAM_BOT_TOKEN", ...)`. Falls back to manual on invalid token.
- **[2] Manual BotFather**: user runs @BotFather → /newbot → pastes token → saved to .env.
- Re-run asks "Reconfigure?" if token already set.
- Hidden setup knobs (home channel, reply mode, proxy, mention behavior) are self-configuring — `/sethome` sets the home channel on first chat.

## Toolset

- `hermes-telegram` = `_HERMES_CORE_TOOLS` (full access, "personal use") — toolsets.py.
- `platform_toolsets:` in config.yaml overrides per-platform toolset lists.

## Plugin internals

- Adapter: `plugins/platforms/telegram/adapter.py` (moved out of core, #41112).
- `telegram:` YAML block (require_mention etc.) is bridged to env vars by the plugin's `apply_yaml_config_fn` hook; require_mention default handling in gateway/config.py (~line 1685-1705).

## Remote-use checklist (user away from machine)

- Bot allowlist set (`TELEGRAM_ALLOWED_USERS`) so only the owner's ID can trigger sessions.
- Service survives reboot: `--system` install (boot-time) beats user service (login-time) for unattended operation.
- Laptop awake with lid closed on AC: `HandleLidSwitchExternalPower=ignore` in /etc/systemd/logind.conf + `systemctl restart systemd-logind`.
- Test end-to-end: message bot from phone → expect reply; watch `~/.hermes/logs/` on failure.
