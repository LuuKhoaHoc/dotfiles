#!/usr/bin/env bash
# Post-start: enable + start services on the VM so tunnels come up immediately.
# Runs over SSH from the GitHub Action after the VM is powered on.
set -euo pipefail

SERVICES=("cloudflared" "cloudflared.service" "9router" "9router.service")
STARTED=0

for svc in "${SERVICES[@]}"; do
  if systemctl list-unit-files "${svc}" &>/dev/null 2>&1; then
    echo "==> enabling + starting ${svc}"
    sudo systemctl enable --now "${svc}" || systemctl enable --now "${svc}" || true
    STARTED=1
  fi
done

if [ "$STARTED" -eq 0 ]; then
  echo "!! No known cloudflared/9router systemd unit found. Trying common launch paths..."
  # Fallback: if installed as a user-mode cloudflared tunnel
  command -v cloudflared >/dev/null 2>&1 && (cloudflared tunnel --config ~/.cloudflared/config.yml run &) || true
fi

echo "==> waiting for tunnel to register with Cloudflare edge..."
for i in $(seq 1 12); do
  if curl -fsS -m 8 https://router.luukhoahoc.me/ >/dev/null 2>&1; then
    echo "router.luukhoahoc.me is UP (attempt $i)"
    exit 0
  fi
  echo "  tunnel not ready yet ($i/12), sleeping 10s..."
  sleep 10
done

echo "!! router.luukhoahoc.me still not reachable after post-start"
exit 1
