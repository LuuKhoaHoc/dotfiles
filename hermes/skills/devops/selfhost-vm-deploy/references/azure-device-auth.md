# Azure device-code auth for VM lifecycle ops (no az CLI)

Verified 2026-08-14 against login.microsoftonline.com. Goal: a local cron can
start an Azure VM every morning (Azure auto-shutdown has no auto-start).

## The one working pattern

Device code OAuth with the **Azure CLI public client id**, tenant `/common/`,
**`offline_access` scope** — then plain REST calls to ARM. Zero dependencies
(urllib only). Full runnable script: `scripts/azure-vm-start.py`.

```
POST https://login.microsoftonline.com/common/oauth2/v2.0/devicecode
  client_id=04b07795-8ddb-461a-bbee-02f9e1bf7b46
  scope=https://management.core.windows.net/.default offline_access
→ user_code, device_code, interval, expires_in

poll POST .../common/oauth2/v2.0/token
  grant_type=urn:ietf:params:oauth:grant-type:device_code
  device_code=...
→ HTTP 400 {"error":"authorization_pending"} = NORMAL, keep polling
→ access_token (+refresh_token only if offline_access was requested)

refresh: POST .../common/oauth2/v2.0/token grant_type=refresh_token
list subs: GET https://management.azure.com/subscriptions?api-version=2020-01-01
start VM:  POST https://management.azure.com{vmId}/start?api-version=2023-03-01
           (409 = already running / transitional, not fatal)
state:     GET {vmId}/instanceView → statuses[].code "PowerState/running"
```

## Verified traps (each cost a round-trip)

- **`/consumers/` endpoint → AADSTS9002332**: "Application '797f4846-ba00-4fd7-ba43-dac1f8f63013' (Azure Resource Manager) is configured for use by Azure Active Directory users only. Please do not use the /consumers endpoint". ARM refuses the MSA-only tenant outright.
- **`/common/` + personal (gmail) MSA → "You can't sign in here with a personal account. Use your work or school account instead."** ARM device-code auth only serves work/school (AAD) accounts. A personal MSA cannot control Azure via this path even if it owns a subscription.
- **Missing `offline_access` scope → refresh_token is EMPTY** — token store saves a useless blank refresh token and every run re-prompts. Always include it.
- **"Pick an account" list ≠ allowed accounts** — it only shows accounts previously used in that browser/profile. "Use another account" still accepts any email; don't conclude personal accounts are blocked from the list alone.
- **`authorization_pending` (400) during poll is normal** — a naive `except HTTPError` that prints "Poll error" then keeps polling looks broken but is actually correct; handle the JSON body, only bail on errors other than `authorization_pending` / `slow_down`.
- **GitHub-Education-claimed Azure ("Azure for Students") lives under a WORK/SCHOOL account**, not the GitHub personal email. Even if the school email was revoked long ago, the account + subscription keep working (user just reset the Microsoft password via account.live.com/password/reset using the school email). Try every previously-signed-in account (browser list) before assuming the claim landed on the personal MSA.
- **Azure CLI via pip/uv is a trap on Arch**: `uv tool install azure-cli` shim broken (PYTHONPATH=bin/src), azure-cli depends on `pkg_resources` (removed in setuptools>=81), stale versions call `time.clock()` (gone since py3.8), then `argparse conflicting subparser: check-name`. Microsoft doesn't support PyPI installs anyway. For single operations (start/stop VM) the 100-line REST script above beats fighting azure-cli packaging.
- Device-code tokens for this flow persist in `~/.azure-vm-start.json` (0600) with auto-refresh (~90-day refresh token) — cron-safe after one manual login.

## Resolution (2026-08-14, same day)

The VM's real owner is **luatluukhoa@gmail.com** — a GitHub-federated guest
account ("sign in with GitHub OR email both work" on the portal). Neither the
UIT school account nor the Hilo work account has the subscription. Device-code
still rejects it at the login page (federated identity is not resolvable as a
plain AAD/MSA sign-in), so the durable path is a **Service Principal**:

1. Portal (login via GitHub/email) → Microsoft Entra ID → App registrations →
   create `cron-vm-start` → note Application (client) ID + Directory (tenant) ID.
2. Certificates & secrets → new client secret (24 mo) → copy Value once.
3. Subscription → Access control (IAM) → Add role assignment →
   **Virtual Machine Contributor** → assign to the app.
4. Script switches to `client_credentials`:
   `POST https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token`
   `{client_id, client_secret, grant_type=client_credentials, scope=https://management.core.windows.net/.default}`
   → access_token auto-renewable forever, no user login, cron-safe.

Other accounts checked and ruled out: `26730102@ms.uit.edu.vn` (zero/no matching
subscription), `hoclk@hilo.com.vn` (no match). The device-code flow remains the
fallback only for plain AAD/MSA accounts.
