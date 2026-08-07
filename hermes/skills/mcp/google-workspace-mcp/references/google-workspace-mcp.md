# Google Workspace MCP — reference detail

Source: developers.google.com/workspace/guides/configure-mcp-servers (verified 2026-08).
Project used: gen-lang-client-0370996415 (auto-created project, account luatluukhoa@gmail.com).

## Full enable command (both API + MCP services in one call)

```bash
gcloud services enable gmail.googleapis.com drive.googleapis.com docs.googleapis.com \
  sheets.googleapis.com slides.googleapis.com calendar-json.googleapis.com \
  chat.googleapis.com people.googleapis.com gmailmcp.googleapis.com \
  drivemcp.googleapis.com docsmcp.googleapis.com sheetsmcp.googleapis.com \
  slidesmcp.googleapis.com calendarmcp.googleapis.com chatmcp.googleapis.com \
  --project=PROJECT_ID
```

Takes ~2-3 min as ONE operation (`Operation "operations/..." finished successfully`).
Verify: `gcloud services list --enabled --project=...` — use default table output;
`--format='value(serviceConfig.name)'` returned nothing on this machine even though
services were enabled.

## Server URLs (8)

| Server | URL |
|---|---|
| gmail | https://gmailmcp.googleapis.com/mcp/v1 |
| drive | https://drivemcp.googleapis.com/mcp/v1 |
| docs | https://docsmcp.googleapis.com/mcp/v1 |
| sheets | https://sheetsmcp.googleapis.com/mcp/v1 |
| slides | https://slidesmcp.googleapis.com/mcp/v1 |
| calendar | https://calendarmcp.googleapis.com/mcp/v1 |
| chat | https://chatmcp.googleapis.com/mcp/v1 |
| people | https://people.googleapis.com/mcp/v1 |

## Console links (GUI-only — internal APIs 404)

- Branding/consent: https://console.cloud.google.com/auth/branding
- Audience/test users: https://console.cloud.google.com/auth/audience
- Scopes: https://console.cloud.google.com/auth/scopes
- Create OAuth client: https://console.cloud.google.com/auth/clients/create
- Chat app config: https://console.cloud.google.com/apis/api/chat.googleapis.com/hangouts-chat
  → Manage → Configuration: name "Chat MCP", avatar
  https://developers.google.com/chat/images/quickstart-app-avatar.png, disable
  interactive features, enable "Log errors to Logging" → Save.

Internal API attempts that 404 with gcloud token (don't retry):
`https://oauth2.googleapis.com/v1/projects/{p}/brands`,
`https://content-oauth.googleapis.com/v1/projects/{p}/brands`, `/oauthClients`.

## Scope list (all verified valid via Google Discovery API)

```
https://www.googleapis.com/auth/gmail.readonly
https://www.googleapis.com/auth/gmail.compose
https://www.googleapis.com/auth/drive.readonly
https://www.googleapis.com/auth/drive.file
https://www.googleapis.com/auth/documents.readonly
https://www.googleapis.com/auth/documents
https://www.googleapis.com/auth/spreadsheets.readonly
https://www.googleapis.com/auth/spreadsheets
https://www.googleapis.com/auth/presentations.readonly
https://www.googleapis.com/auth/presentations
https://www.googleapis.com/auth/calendar.calendarlist.readonly
https://www.googleapis.com/auth/calendar.events.freebusy
https://www.googleapis.com/auth/calendar.events.readonly
https://www.googleapis.com/auth/chat.spaces.readonly
https://www.googleapis.com/auth/chat.memberships.readonly
https://www.googleapis.com/auth/chat.messages.readonly
https://www.googleapis.com/auth/chat.messages.create
https://www.googleapis.com/auth/chat.users.readstate.readonly
https://www.googleapis.com/auth/userinfo.profile
https://www.googleapis.com/auth/contacts.readonly
```

"Invalid scope" error = page opened before APIs finished enabling. Fix: refresh
page, retry. Skip step entirely is fine for External + test-user apps.

## Hermes OAuth details

- `auth: oauth` uses the MCP Python SDK: DCR attempt first, then browser flow with
  PKCE, token refresh, tokens cached at `HERMES_HOME/mcp-tokens/<server>.json`
  (0o600). On this Windows machine: `%LOCALAPPDATA%\hermes\mcp-tokens\`.
- Default redirect URI: `http://127.0.0.1:<random-port>/callback`. Fix port via
  `oauth.redirect_port` (e.g. 8765) and register `http://127.0.0.1:8765/callback`
  in the Google console. `oauth.redirect_host: localhost` switches to
  `http://localhost:<port>/callback` (for WAFs that 403 on literal 127.0.0.1).
- **`hermes mcp login` DOES NOT WORK for Google MCP** (verified 2026-08): servers
  answer `initialize`/`tools/list` with HTTP 200 and no `WWW-Authenticate`, so
  the SDK's `OAuthClientProvider` never starts a flow; login exits with a
  misleading "no OAuth token was obtained" hint. Use the manual PKCE script.
- Tools are prefixed `mcp_<server>_<tool>` e.g. `mcp_gmail_search_threads`,
  `mcp_people_get_user_profile`.

## Manual PKCE flow (the working auth path)

`~/gws_mcp_oauth.py` (mirrored in dotfiles repo `hermes/gws_mcp_oauth.py`).
For each server: load client info → PKCE (S256, 48-byte verifier) → open browser
to `https://accounts.google.com/o/oauth2/v2/auth` with
`client_id, redirect_uri=http://127.0.0.1:8765/callback, response_type=code,
scope=<product scopes>, access_type=offline, prompt=consent` → local HTTP server
on 8765 captures `?code=` → exchange at `https://oauth2.googleapis.com/token`
(grant_type=authorization_code + code_verifier + client_secret) → write token file.

Token JSON shape (HermesTokenStorage): `access_token, token_type, expires_in,
refresh_token, scope` PLUS Hermes' absolute `expires_at = now + expires_in`
(required — on read Hermes rewrites `expires_in` from it; without it a restart
can treat an expired token as valid). Client info lives in
`<server>.client.json` (written by any probe via `_maybe_preregister_client`;
contains the client_secret). Credential sources tried in order: client.json →
config oauth block (resolving `${VAR}` from `.env`) → env
`GWS_MCP_CLIENT_ID`/`GWS_MCP_CLIENT_SECRET`.

Sanity check a token against the real API:
`curl -H "Authorization: Bearer <tok>" https://gmail.googleapis.com/gmail/v1/users/me/profile` → 200.

## Multi-OS / re-auth

- Tokens auto-refresh; copy `mcp-tokens/` (all `*.json`) to the other OS and the
  same tokens + OAuth client work — loopback redirect URIs are host-agnostic.
  Never via a public repo.
- Re-auth one server: `python ~/gws_mcp_oauth.py <server>`.
- Secrets in repos: `${VAR}` placeholders (`${GWS_MCP_CLIENT_SECRET}`) resolve
  from per-OS `~/.hermes/.env`; GitHub push protection blocks `GOCSPX-` commits
  ("push declined due to repository rule violations").

## Windows / gcloud notes

- Installer `GoogleCloudSDKInstaller.exe` is now a ~267 KB BOOTSTRAPPER (was
  hundreds of MB) — downloads components during install. Verify download:
  `curl -sI <url> | grep -i content-length` matches, file starts `MZ`.
- Install dir: `%LOCALAPPDATA%\Google\Cloud SDK\google-cloud-sdk\bin` — PATH is
  updated at USER level (check:
  `[Environment]::GetEnvironmentVariable("Path","User")`); new terminals see `gcloud`.
- **Path contains a space** ("Cloud SDK"): `cmd //c "$GCLOUD --version"` breaks
  (cmd splits on space → "'loud' is not recognized"). From git-bash invoke the
  .cmd directly: `"$LOCALAPPDATA/.../gcloud.cmd" --version` works. Same for any
  quoted cmd //c call: use `cmd //c "\"$PATH\" args"`.
- gcloud token for ad-hoc API calls: `TOKEN=$("$GCLOUD" auth print-access-token)`.
- `tasklist` truncates process names to 15 chars (`GoogleCloudSDKInstaller.e`) —
  grep the output instead of exact-name filtering.
- **HERMES_HOME pollution in persistent terminal sessions**: a plain
  `HERMES_HOME=$(cmd ...)` assignment (no export) persists across terminal-tool
  calls. If it captures command output (e.g. `--help` text), every later `hermes`
  invocation crashes with `WinError 3 ... 'usage: hermes [-h] ...'` (it tries to
  mkdir the help text as a path). Fix: `unset HERMES_HOME`. On this machine the
  CLI resolves the correct AppData config only when HERMES_HOME is unset.
- Hermes CLI on this machine: `%LOCALAPPDATA%\hermes\hermes-agent\venv\Scripts\hermes`.
- Auth loop pattern: run `python ~/gws_mcp_oauth.py gmail drive docs sheets slides calendar chat people` as ONE background process — browser opens one tab per server; user approves each (unverified-app warning → Advanced → Continue).
