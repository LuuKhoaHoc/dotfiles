# Telegram gateway connect debugging — full path (2026-08-11, VN ISP)

Session context: Hermes v0.20.0, Arch Linux, user service `hermes-gateway.service`,
bot @picoclaw_leo_bot. Symptom: `[Telegram] Connecting to Telegram (attempt 1/8)…`
stuck forever; gateway never reaches polling.

## What was ruled out (don't redo)

- **api.telegram.org reachable from shell**: `curl` returns 302 in ~0.7s over both
  IPv4 and IPv6. 8/8 repeated Python `ssl` handshakes to `149.154.166.110:443`
  (SNI api.telegram.org, ALPN http/1.1) completed in 0.2-0.4s. So NOT a network
  blackhole, NOT DPI on Python's TLS fingerprint.
- **force_ipv4 patch is innocent**: `apply_ipv4_preference` only rewrites
  `socket.getaddrinfo` AF_UNSPEC→AF_INET with A-record fallback.
- **PTB `Application.initialize()` does NO network I/O** (verified in
  `telegram/ext/_application.py` + `request/_httpxrequest.py`: just builds the
  httpx client). So a standalone replication of the adapter's exact
  HTTPXRequest kwargs + `app.initialize()` completes in 0.7s — the wedge is
  gateway-context-specific, not adapter-config-specific.
- **Retry deadline never fires**: `_await_with_thread_deadline` (adapter.py)
  uses a `threading.Timer` + `loop.call_soon_threadsafe` + `asyncio.wait`. In
  practice NO "attempt 2/8" or "timed out" log ever appears, even when
  initialize() takes 113s. The 8-attempt ladder is effectively decorative in
  this environment. Consequence: don't rely on retries; the gateway either
  connects on attempt 1 or hangs.

## Observed timing (the important operational fact)

| Start | Config | Result |
|---|---|---|
| 08:39 | fallback IPs ON + IPv6 | stuck >3 min (killed) |
| 08:42 | fallback OFF + IPv6 | connected after ~113s on attempt 1 |
| 08:44 | fallback OFF + IPv4 (force_ipv4) | connected in ~40-90s |
| 08:47/08:51 | fallback OFF + IPv4 | stuck >4 min / >2 min (killed prematurely) |
| 08:53 | same | connected after ~3 min |

**Lesson: connects take 1-3+ minutes and look identical to a permanent wedge.
Never kill before ~5 minutes.** The 409 probe (see SKILL.md) distinguishes
"still connecting" (200) from "healthy" (409) without guessing.

## Diagnostic commands that worked

```bash
# where is the process stuck? (socket level)
ss -tpn | grep "pid=<gateway_pid>"
#   IPv6 to 2001:67c:4e8:f004::9:443 with 0 bytes = broken-IPv6 half-blackhole
#   IPv4 ESTAB 0 0 to 149.154.166.110:443 with no progress = connect-phase wedge
getent ahosts api.telegram.org        # A + AAAA records
curl -4/-6 -s -o /dev/null -w '%{http_code}' https://api.telegram.org
timeout 6 python3 - <<'EOF'          # replicate gateway TLS exactly
import socket, ssl, time
ctx = ssl.create_default_context(); ctx.set_alpn_protocols(['http/1.1'])
s = socket.create_connection(('149.154.166.110', 443), timeout=5)
ss = ctx.wrap_socket(s, server_hostname='api.telegram.org'); print('TLS OK'); ss.close()
EOF

# thread-level truth (needs sudo for ptrace):
sudo env "PATH=$PATH:/home/<user>/.hermes/hermes-agent/venv/bin" \
  /home/<user>/.hermes/hermes-agent/venv/bin/py-spy dump --pid <pid>
#   Wedged process: main loop idle in select(), NO thread doing the connect —
#   task waiting on I/O that never resolves; timers/deadlines not firing.
#   Install py-spy into the venv: ~/.hermes/hermes-agent/venv/bin/pip install py-spy
```

## Environment quirks hit on this machine

- `sudo -S -p '' cmd` → sudo prints usage and fails. Use `echo "$PW" | sudo -S cmd`
  (default prompt). `SUDO_PASSWORD` lives in `~/.hermes/.env`, not the shell env.
- The systemd unit has `Restart=always` + `RestartForceExitStatus=75`; a graceful
  restart handoff exits the old PID with 75/TEMPFAIL — normal, not a crash.
- `loginctl enable-linger` was enabled by `hermes gateway install` itself.
- Telegram logs land in `journalctl --user -u hermes-gateway`; the adapter
  logger is `hermes_plugins.telegram_platform.adapter`.
