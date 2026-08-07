# Google Workspace MCP → Hermes: full setup recipe

Verified working 2026-08 (project `gen-lang-client-0370996415`, 8/8 servers authenticated).

## 1. Enable APIs + MCP services (gcloud)

```bash
gcloud services enable gmail.googleapis.com drive.googleapis.com docs.googleapis.com \
  sheets.googleapis.com slides.googleapis.com calendar-json.googleapis.com \
  chat.googleapis.com people.googleapis.com \
  gmailmcp.googleapis.com drivemcp.googleapis.com docsmcp.googleapis.com \
  sheetsmcp.googleapis.com slidesmcp.googleapis.com calendarmcp.googleapis.com \
  chatmcp.googleapis.com --project=<PROJECT_ID>
```
- ~2-3 min; success = `Operation ".../" finished successfully.`
- People MCP reuses `people.googleapis.com` (no separate `peoplemcp` service).
- Get project: `gcloud config get-value project`; account: `gcloud auth list`.
- Verify: `gcloud services list --enabled --project=<ID>` (note: `--format='value(serviceConfig.name)'` returned nothing in one run — plain table format is reliable).

## 2. Server URLs (all `/mcp/v1`)

| Server | URL |
|---|---|
| gmail | `https://gmailmcp.googleapis.com/mcp/v1` |
| drive | `https://drivemcp.googleapis.com/mcp/v1` |
| docs | `https://docsmcp.googleapis.com/mcp/v1` |
| sheets | `https://sheetsmcp.googleapis.com/mcp/v1` |
| slides | `https://slidesmcp.googleapis.com/mcp/v1` |
| calendar | `https://calendarmcp.googleapis.com/mcp/v1` |
| chat | `https://chatmcp.googleapis.com/mcp/v1` |
| people | `https://people.googleapis.com/mcp/v1` |

## 3. Console steps (browser, user-only)

1. **Branding/consent** — `console.cloud.google.com/auth/branding` → Start → App name e.g. `Workspace MCP Servers`, support email → Next → audience: **External** (Internal unavailable for personal @gmail accounts) → Next → contact email → agree policy → Create. Then `console.cloud.google.com/auth/audience` → Add test user (their gmail).
2. **Scopes** — `console.cloud.google.com/auth/scopes` → Add manually (one scope per line, full `https://` URLs) → Add to table → Update → Save.
   - **OPTIONAL** for External + test-user apps: scopes are requested at runtime on the consent screen anyway. Skippable.
   - Pitfall: if the scopes page was opened BEFORE the APIs finished enabling, EVERY scope reports "not added because they are invalid" — refresh the page and retry. The scopes themselves are valid (verify via `https://<api>.googleapis.com/$discovery/rest?version=v1`).
   - `userinfo.profile` / `userinfo.email` are default scopes — Google always includes them and refuses manual addition.
3. **OAuth client** — `console.cloud.google.com/auth/clients/create` → **Web application** → name → Authorized redirect URI: `http://127.0.0.1:8765/callback` (must match `oauth.redirect_port` in Hermes config) → Create → copy Client ID + Secret.
4. **Chat app** (only if the `chat` server will be used) — `console.cloud.google.com/apis/api/chat.googleapis.com/hangouts-chat` → Manage → Configuration → name `Chat MCP`, avatar `https://developers.google.com/chat/images/quickstart-app-avatar.png`, description `Chat MCP server`, disable interactive features, enable error logging → Save.

## 4. Scopes per product (requested at runtime; from official docs)

- gmail: `gmail.readonly`, `gmail.compose`
- drive: `drive.readonly`, `drive.file`
- docs: `drive.readonly`, `drive.file`, `documents.readonly`, `documents`
- sheets: `drive.readonly`, `drive.file`, `spreadsheets.readonly`, `spreadsheets`
- slides: `drive.readonly`, `drive.file`, `presentations.readonly`, `presentations`
- calendar: `calendar.calendarlist.readonly`, `calendar.events.freebusy`, `calendar.events.readonly`
- chat: `chat.spaces.readonly`, `chat.memberships.readonly`, `chat.messages.readonly`, `chat.messages.create`, `chat.users.readstate.readonly`
- people: `userinfo.profile`, `contacts.readonly` (skip `directory.readonly` — Workspace-org only)

Full `https://www.googleapis.com/auth/` prefix required when pasting into the console.

## 5. Hermes config + auth

- `hermes config set mcp_servers.<name>.url <url>`, `.auth oauth`, `.oauth.client_id <id>`, `.oauth.client_secret <secret>`, `.oauth.redirect_port 8765` for each of the 8 servers.
- `hermes mcp login <name>` does NOT work for these servers (no 401 challenge — see SKILL.md) → use `scripts/force_oauth_flow.py` from the skill.
- Token files land in `<hermes_home>/mcp-tokens/<server>.json` (+ `.client.json` written by the failed login probe — the script depends on it).

## 6. Smoke-test queries (from official docs)

- "Ariel nói gì trong email gần nhất?" → `gmail.search_threads` + `gmail.get_thread`
- "Tóm tắt file Kế hoạch tiếp thị" → `drive.search_files` + `drive.read_file_content`
- "Cuộc họp tiếp theo với Ariel?" → `calendar.list_events`
- "Tên tôi là gì theo hồ sơ Google?" → `people.get_user_profile`

## 7. Google Cloud CLI install (Windows, official)

```powershell
(New-Object Net.WebClient).DownloadFile("https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe", "$env:Temp\GoogleCloudSDKInstaller.exe")
& $env:Temp\GoogleCloudSDKInstaller.exe
```
- Current installer is a ~260 KB bootstrapper (MZ header, Content-Length 267096) — downloads components during the wizard. Installs to `%LOCALAPPDATA%\Google\Cloud SDK\google-cloud-sdk\bin`, PATH added per-user.
- From git-bash: `"$LOCALAPPDATA/Google/Cloud SDK/google-cloud-sdk/bin/gcloud.cmd"` works directly; `cmd //c "$GCLOUD --version"` breaks on the space in `Cloud SDK` — quote the whole path when calling via cmd.
