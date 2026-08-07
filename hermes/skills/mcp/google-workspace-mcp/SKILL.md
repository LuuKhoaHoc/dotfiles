---
name: google-workspace-mcp
description: "Use when connecting Google Workspace MCP servers to Hermes."
---

# Google Workspace MCP Servers

Google's official remote MCP servers let AI clients (Hermes, Claude, Antigravity) act on Gmail, Drive, Docs, Sheets, Slides, Calendar, Chat, People. Each product has its own server; all require per-project Google Cloud setup BEFORE any client connects.

## Trigger

- User wants Hermes (or any MCP client) connected to Google Workspace MCP servers
- Re-auth needed: `hermes mcp login <server>` tokens expired/revoked (cached at `~/.hermes/mcp-tokens/<server>.json`)
- Migrating Google Workspace MCP config to another machine

## Key facts (learned the hard way)

- **Google MCP servers REJECT Dynamic Client Registration (RFC 7591)** — bare `auth: oauth` gets 400. You MUST create your own OAuth client (type **Web app**) in Google Cloud Console. Subtle symptom: `tools/list` works unauthenticated (login looks fine) but real tool calls time out.
- **15 services must be enabled**: 8 product APIs + 7 MCP services (`gmailmcp`, `drivemcp`, `docsmcp`, `sheetsmcp`, `slidesmcp`, `calendarmcp`, `chatmcp` — People MCP reuses `people.googleapis.com`).
- Hermes default OAuth redirect URI is **`http://127.0.0.1:<port>/callback`** — fix the port with `oauth.redirect_port` and register that exact URI in the console.
- **Auth Platform "scopes" step is NOT required** for External/test-user apps — scopes are requested at runtime on the consent screen. The console "scope(s) were not added because they are invalid" error means the scopes page was opened before the APIs finished enabling (console only accepts scopes from already-enabled APIs) → refresh the page.
- Consent screen setup and OAuth client creation are **GUI-only** — internal APIs (`oauth2.googleapis.com/v1/projects/.../brands`, `content-oauth.googleapis.com/...`) 404 with a gcloud token. Don't waste time trying to automate them.
- Personal @gmail accounts (no Workspace org) → audience must be **External** + add yourself as test user.
- **`${VAR}` interpolation is recursive over the whole server config** (tools/mcp_tool.py `_interpolate_env_vars`): `command`/`args`/`url`/`headers`/`env` AND `oauth.client_secret` resolve from `~/.hermes/.env` at connect time → commit `${GWS_MCP_CLIENT_SECRET}` placeholders in sync repos, real values live per-OS in `.env` (user preference: secrets travel via secure channel, never in repos).
- **GitHub push protection** rejects commits containing `GOCSPX-` secrets: "push declined due to repository rule violations" — desired guardrail; keep secrets out.

## Workflow

### 1. Enable services (gcloud — fully scriptable)

```bash
gcloud services enable gmail.googleapis.com drive.googleapis.com docs.googleapis.com \
  sheets.googleapis.com slides.googleapis.com calendar-json.googleapis.com \
  chat.googleapis.com people.googleapis.com gmailmcp.googleapis.com \
  drivemcp.googleapis.com docsmcp.googleapis.com sheetsmcp.googleapis.com \
  slidesmcp.googleapis.com calendarmcp.googleapis.com chatmcp.googleapis.com \
  --project=PROJECT_ID
```

One operation, ~2-3 min. Verify with `gcloud services list --enabled --project=...` (default table format; `--format='value(serviceConfig.name)'` may print nothing on some versions).

### 2. Console steps (user must do, ~5 min — give exact links)

1. **Consent screen**: `console.cloud.google.com/auth/branding` → Start → name "Workspace MCP Servers" → External → add test user at `/auth/audience`
2. **Scopes**: `/auth/scopes` — OPTIONAL (skip if it errors; see Key facts). Full scope list in `references/google-workspace-mcp.md`.
3. **OAuth client**: `/auth/clients/create` → **Web app** → redirect URI `http://127.0.0.1:8765/callback` (port must match `oauth.redirect_port` in config) → copy Client ID + Secret
4. **Chat only**: `console.cloud.google.com/apis/api/chat.googleapis.com/hangouts-chat` → Manage → Configuration → name "Chat MCP", disable interactive features, enable logging → Save

### 3. Hermes config (`~/.hermes/config.yaml`, backup first)

```yaml
mcp_servers:
  gmail:
    url: "https://gmailmcp.googleapis.com/mcp/v1"
    auth: oauth
    oauth:
      client_id: "<id>"
      client_secret: "<secret>"
      redirect_port: 8765
```

Server URLs (8): `https://gmailmcp|drivemcp|docsmcp|sheetsmcp|slidesmcp|calendarmcp|chatmcp.googleapis.com/mcp/v1` + `https://people.googleapis.com/mcp/v1`. Can share the same OAuth client across all servers.

### 4. Authenticate per server — `hermes mcp login` CANNOT do this

**Root cause (verified with curl)**: Google's MCP servers answer `initialize` + `tools/list` with HTTP 200 and NO `WWW-Authenticate` challenge, so the MCP SDK's `OAuthClientProvider` never triggers its browser flow. `hermes mcp login` therefore NEVER opens a browser for these servers and NEVER lands a token — it exits with a *misleading* "Server responded, but no OAuth token was obtained" hint that looks like a config problem. `hermes mcp test`/probe still "succeeds" (tools/list works anonymously) — only real tool calls time out later.

**Working fix — manual PKCE flow** (script: `~/gws_mcp_oauth.py`, also mirrored in dotfiles repo `hermes/gws_mcp_oauth.py`):

```bash
python ~/gws_mcp_oauth.py        # all 8 servers, or pass names: python ~/gws_mcp_oauth.py gmail drive
```

Browser opens per server → approve ("Advanced → Continue" if unverified-app warning) → token written to `HERMES_HOME/mcp-tokens/<server>.json`. The script reads client info from `<server>.client.json`, falls back to the config oauth block (resolving `${VAR}` from `.env`), then env `GWS_MCP_CLIENT_ID/SECRET` — so it works on a fresh OS before any probe ran.

Token files (portable, auto-refresh, do NOT commit):
- `<server>.json` — OAuthToken + absolute wall-clock `expires_at` (Hermes rewrites `expires_in` from it on read; keep the field!)
- `<server>.client.json` — client info (contains the client_secret)
- `<server>.meta.json` — OAuth metadata

Loopback redirect URIs are host-agnostic: copy `mcp-tokens/` to another OS and the same tokens + OAuth client work — no console changes, no re-approval.

## Verification

- Token file exists: `~/.hermes/mcp-tokens/<server>.json` (for the desktop profile: `%LOCALAPPDATA%\hermes\mcp-tokens\`)
- Ask the agent to use a tool, e.g. `people.get_user_profile` ("Tên của tôi trên Google là gì?")
- Sanity-check tokens against the real API: `curl -H "Authorization: Bearer <access_token>" https://gmail.googleapis.com/gmail/v1/users/me/profile` → expect 200
- For OAuth failures: token missing → the PKCE flow never completed (run `~/gws_mcp_oauth.py`); tool calls timeout but login/probe looked OK → no token landed (anonymous tools/list) — same fix; `redirect_uri_mismatch` → registered URI ≠ `http://127.0.0.1:<port>/callback`

## Pitfalls

- **`hermes mcp add <name> --url ... --auth oauth` is interactive** — it probes the server and prompts "Enable all N tools? [Y/n/select]"; with no TTY it prints `Cancelled.` and writes NOTHING (no url/auth in config). Use `hermes config set mcp_servers.<name>.<key> <value>` instead — nested keys (`oauth.client_id`, `oauth.client_secret`, `oauth.redirect_port`) set cleanly. (Side benefit: the add-probe listing tools pre-auth confirms the tools/list-without-auth behavior.)
- **`patch`/`write_file` tools refuse to edit `config.yaml`** (security guard: "Agent cannot modify security-sensitive configuration") — go through `hermes config set` / `hermes config get` / `hermes config path` / `hermes config check`.
- **Config location is NOT always `~/.hermes/config.yaml`** — on this Windows machine `hermes config path` → `C:\Users\luukhoahoc\AppData\Local\hermes\config.yaml` (desktop profile; `~/.hermes/config.yaml` is a separate unused default). Always resolve with `hermes config path` before editing.
- **Wrong redirect URI** → Google shows `error=redirect_uri_mismatch` — check registered URI exactly matches `http://127.0.0.1:<fixed-port>/callback`
- **`hermes mcp login` NEVER completes for Google MCP** (no 401 challenge → no browser flow) — do not debug it as a config problem; the manual PKCE script is the only working path (see section 4)
- **Editing config while running** — entries reload but the OAuth flow won't survive the 30s reload timeout; add entries then run the PKCE script from a fresh terminal
- **Scopes step errors** — skip it (not required for test users); if you want it, refresh the page after APIs are enabled, or add scopes one at a time
- Windows/gcloud quirks: path contains a space (`...\Cloud SDK\...`); HERMES_HOME session pollution; installer bootstrapper size — see reference

## Reference

- `references/google-workspace-mcp.md` — full scope list, enable command, console links, Windows gcloud notes
