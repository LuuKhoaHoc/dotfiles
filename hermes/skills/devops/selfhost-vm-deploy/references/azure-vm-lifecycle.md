# Azure VM lifecycle automation (9router-vm)

Verified 2026-08-13. The user's Azure VM auto-shuts down at midnight (portal
Auto-shutdown); a daily 09:00 Hermes cron starts it. **Do NOT install az CLI via
pip/uv for this** — see pitfalls below; the REST device-code script is the working path.

## az CLI via pip/uv — verified pitfalls (do not repeat)

- `uv tool install azure-cli` generates a broken shim: `bin/az` sets
  `PYTHONPATH=bin/src` (path does not exist) and calls bare `python` from PATH —
  inside a Hermes session that resolves to the Hermes venv → `ModuleNotFoundError`.
- The azure-cli build pip/uv resolves still requires `pkg_resources` (removed in
  setuptools ≥81) AND its `_session.py` calls `time.clock()` (removed in Python 3.8)
  → `AttributeError: module 'time' has no attribute 'clock'` on py3.11; monkey-patching
  `time.clock` then hits `argparse: conflicting subparser: check-name` on py3.13.
- Conclusion: skip az CLI entirely for VM lifecycle on this machine.

## Working approach — REST API + device-code script

Script: `~/.local/bin/azure-vm-start` (python3 stdlib only, chmod +x).

- **Auth**: OAuth device-code against `login.microsoftonline.com/common` using the
  Azure CLI **public client id** `04b07795-8ddb-461a-bbee-02f9e1bf7b46`, scope
  `https://management.core.windows.net/.default`. First run prints
  `https://microsoft.com/devicelogin` + code for the user (use the Azure Education
  account). Refresh token cached at `~/.azure-vm-start.json` (chmod 600), auto-renewed
  on every run; if it expires (~90 days) the script re-prompts via device code.
- **Start flow**: list subscriptions → list VMs per sub → `POST {vmId}/start?api-version=2023-03-01`
  (HTTP 409 = already running / transitional) → poll `GET {vmId}/instanceView` for
  `PowerState/running` (6 × 20s).
- **Exit codes**: 0 = started/running, 2 = needs auth (re-run device code), 3 = other.
- Cron job `azure-vm-start-9h` (09:00 daily, deliver=telegram) runs it and reports in
  Vietnamese; auth expiry surfaces as "Cần chạy lại az login" style message to the user.

## Related

- VM stays on only while credit/auto-shutdown permits; gateway/memory endpoints
  (router/mem.luukhoahoc.me) are unreachable while the VM is off — local agents fall
  back to the previous provider during that window.
