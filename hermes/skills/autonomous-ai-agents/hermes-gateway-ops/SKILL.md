---
name: hermes-gateway-ops
description: "Use when running or debugging the Hermes Telegram gateway."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [hermes, gateway, telegram, systemd, remote-access, watchdog, networking]
---

# Hermes Gateway Operations (Telegram remote access)

Use when the user wants to reach Hermes from their phone via Telegram (e.g. while away from the machine), when the gateway won't connect, or when it must run unattended (laptop left at home). Verified on Hermes v0.20.0 / Linux (Arch) with a Vietnamese ISP network.

## Setup: run the gateway as an unattended service

1. **Configure the platform first** — `~/.hermes/.env` has commented template lines (`# TELEGRAM_BOT_TOKEN=`, `# TELEGRAM_ALLOWED_USERS=`, `# TELEGRAM_HOME_CHANNEL=`). Uncomment with `sed -i`; never hand-edit config.yaml.
2. **Validate token** before anything else: `curl -s https://api.telegram.org/bot<TOKEN>/getMe` → `{"ok":true,...}`.
3. **Install as USER service** (correct for laptops):
   `hermes gateway install --start-now --start-on-login` — the installer enables `loginctl enable-linger` itself, so the service starts at boot without login.
   - PITFALL: do NOT use `sudo hermes gateway install --system` — under sudo, `get_hermes_home()` resolves to `/root` and the unit bakes the wrong home. User service + linger is the robust path.
4. **Pairing / allowlist** (fail-closed: no allowlist = deny everyone):
   - User messages the bot → bot replies with a pairing code → `hermes pairing approve telegram <CODE>` (records the user ID).
   - Also set `TELEGRAM_ALLOWED_USERS=<numeric_user_id>` in .env as a backup (accepts numeric IDs only, not @handles; `*` = allow all).
5. **Home channel** (cron/notification delivery target): `TELEGRAM_HOME_CHANNEL=<chat_id>` in .env — for a private DM, chat_id == user_id. User can also type `/sethome` in the chat.
6. **Security for remote use**: `hermes config set security.redact_secrets true` (tokens can otherwise appear verbatim in session JSONs/logs). Restart to apply.
7. **Verify**: `hermes gateway status` → Active; then the 409 probe (below) until healthy. Restart after any env/config change.

## Connectivity on broken-IPv6 networks (VN ISPs etc.)

Symptom: log stuck at `[Telegram] Connecting to Telegram (attempt 1/8)…`; `ss -tpn` shows sockets to api.telegram.org **ESTAB with zero bytes** (TLS handshake never completes — the ISP half-blacks out IPv6 paths; TCP connects, data dies).

- Fix 1: `hermes config set network.force_ipv4 true` — monkey-patches `socket.getaddrinfo` to AF_INET. The Hermes codebase documents it as "fixes hangs on servers with broken IPv6" (`hermes_constants.apply_ipv4_preference`).
- Fix 2: `HERMES_TELEGRAM_DISABLE_FALLBACK_IPS=true` in .env — the adapter otherwise *always* discovers fallback IPs via DoH and forces a fallback transport even when plain DNS works.
- `api.telegram.org` being reachable via `curl` from a shell does NOT mean the gateway will connect — always verify with the 409 probe, not curl.
- Full debugging path and PTB internals: `references/telegram-connect-debugging.md`.

## The 409 liveness probe (key technique)

Telegram Bot API allows **only one getUpdates consumer per token**:
`curl -w '%{http_code}' "https://api.telegram.org/bot<TOKEN>/getUpdates?timeout=1"`
- **409 Conflict** → gateway is actively polling = healthy.
- **200** → nobody polling = gateway wedged or dead.
- **000/other** → network problem (skip; retry later).

This is the only reliable external health signal for a long-polling bot. Caveat: a 200 probe consumes pending updates (marks them read).

## Self-healing watchdog (must be independent of the gateway)

Hermes cron jobs run *inside* the gateway process — if the gateway wedges, cron dies with it. Use an independent systemd user timer instead:
- `scripts/hermes-tg-watchdog.sh` — probe; restarts only after **2 consecutive 200s** (1–3 min slow-connect means a single 200 is often just a gateway that hasn't finished connecting — never restart on the first strike).
- Units (10 lines each, `~/.config/systemd/user/`):
  - `hermes-tg-watchdog.service`: `Type=oneshot`, `ExecStart=~/.local/bin/hermes-tg-watchdog.sh`
  - `hermes-tg-watchdog.timer`: `OnBootSec=2min`, `OnUnitActiveSec=5min`, `Persistent=true`, `WantedBy=timers.target`
- `systemctl --user daemon-reload && systemctl --user enable --now hermes-tg-watchdog.timer`

## Keep the laptop awake

- `HandleLidSwitchExternalPower=ignore` in `/etc/systemd/logind.conf` (uncomment + set) → lid close on AC does not suspend. Leave `HandleLidSwitch` (battery) untouched unless asked.
- Reload without full restart: `sudo systemctl kill -s HUP systemd-logind`.

## Pitfalls

- **Connect is SLOW: 1–3 minutes.** The adapter's retry deadline (`_await_with_thread_deadline`) never fires in practice (no "attempt 2" log ever appears); connects succeed eventually at 40–113s. Do NOT kill/restart before ~5 minutes — repeated restarts can starve the connect.
- Graceful restarts hand off the bot-token platform lock; the old PID exits with code 75/TEMPFAIL — that is normal (`RestartForceExitStatus=75` in the unit).
- `sudo -S -p ''` prints usage and fails; use plain `echo "$PW" | sudo -S cmd`. Read `SUDO_PASSWORD` from `~/.hermes/.env` — it is NOT in the shell env.
- Gateway Telegram sessions get full core tools (`hermes-telegram` toolset = `_HERMES_CORE_TOOLS`) and inherit all configured MCP servers (gitlab, codegraph, GWS…) — code review / issue management work fine from the phone.
- Toolset changes take effect per-session; env/config changes need `hermes gateway restart`.

## Support files
- `scripts/hermes-tg-watchdog.sh` — canonical watchdog probe script (reads token from .env, 2-strike restart).
- `references/telegram-connect-debugging.md` — full debugging path: socket inspection, py-spy, PTB initialize internals, observed timing.
