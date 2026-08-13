#!/bin/bash
# Hermes Telegram gateway liveness watchdog.
# Probe via the Bot API single-consumer rule:
#   409 = gateway holds the long-poll -> healthy
#   200 = nobody polling -> gateway wedged/dead -> restart (2 strikes to avoid
#         killing a gateway that is still in its slow 1-3 min connect phase)
#   else = network problem -> skip, retry next tick
# Install: cp to ~/.local/bin/, chmod +x, then systemd user timer every 5 min
# (see SKILL.md "Self-healing watchdog" for the unit files).
STATE=/tmp/hermes-tg-watchdog.strike
LOG=/tmp/hermes-tg-watchdog.log
TOKEN=$(grep '^TELEGRAM_BOT_TOKEN=' "$HOME/.hermes/.env" | cut -d= -f2-)

CODE=$(timeout 10 curl -s -o /dev/null -w '%{http_code}' \
  "https://api.telegram.org/bot${TOKEN}/getUpdates?timeout=1" 2>/dev/null)

case "$CODE" in
  409)
    rm -f "$STATE"
    ;;
  200)
    if [ -f "$STATE" ]; then
      echo "$(date '+%F %T') 2nd strike (200) -> restarting hermes-gateway" >> "$LOG"
      systemctl --user restart hermes-gateway
      rm -f "$STATE"
    else
      touch "$STATE"
      echo "$(date '+%F %T') 1st strike (200) -> waiting one more tick" >> "$LOG"
    fi
    ;;
  *)
    echo "$(date '+%F %T') probe HTTP $CODE (network?) -> skip" >> "$LOG"
    ;;
esac
