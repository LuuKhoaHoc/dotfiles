---
name: hermes-mcp-oauth
title: Hermes OAuth MCP servers (Google Workspace etc.)
description: "Use when connecting OAuth MCP servers to Hermes."
---

# Hermes OAuth MCP Servers

## Trigger

- User wants Hermes to use OAuth-protected remote MCP servers: Google Workspace (`gmailmcp` / `drivemcp` / `docsmcp` / `sheetsmcp` / `slidesmcp` / `calendarmcp` / `chatmcp` / `people` MCP), Atlassian, Slack, Linear, etc.
- `hermes mcp login <server>` prints *"Server responded, but no OAuth token was obtained"* or mentions *"automatic client registration"* — even after client_id/client_secret were configured correctly.
- Setting up an OAuth client in a provider console for an MCP endpoint.

## Standard config shape

`config.yaml` under `mcp_servers` (Windows: `C:\Users\<user>\AppData\Local\hermes\config.yaml`):

```yaml
mcp_servers:
  gmail:
    url: https://gmailmcp.googleapis.com/mcp/v1
    auth: oauth
    oauth:
      client_id: "..."
      client_secret: "..."
      redirect_port: 8765   # fixes the loopback port; MUST match the redirect URI registered with the provider
```

- Redirect URI used = `http://127.0.0.1:<redirect_port>/callback` (host tweakable via `oauth.redirect_host: localhost`).
- Tokens cached at `<hermes_home>/mcp-tokens/<server>.json`; client info at `<server>.client.json`; OAuth metadata at `<server>.meta.json`.
- Happy path: `hermes mcp login <server>` → browser opens → user approves → token lands on disk (0o600).

## THE key pitfall: servers that don't 401-challenge

Some OAuth MCP servers — **Google Workspace's official servers are the known case** — serve `initialize` and `tools/list` WITHOUT auth (HTTP 200, no `WWW-Authenticate` header). The MCP Python SDK only triggers its OAuth flow on a 401 challenge, so:

- `hermes mcp login` probes → lists tools fine → **no token is ever obtained** → prints the misleading *"Server responded, but no OAuth token was obtained — authentication did not complete"* warning with a "create your own client" hint, **even when client_id/client_secret are correctly configured**.
- Bare `auth: oauth` (no client_id) fails too: Google's servers reject DCR (RFC 7591) with 400 — you must create your own OAuth client in the provider console.

Probe before assuming:
```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST <url> -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}'
```
HTTP 200 with no auth header = affected → use the manual fallback.

## Workaround: force the PKCE flow manually

Use `scripts/force_oauth_flow.py` (proven against Google Workspace, 2026-08 — 8/8 servers authenticated):

1. Run `hermes mcp login <server>` **once first** — even though it "fails", it writes `<server>.client.json` (pre-registered client info incl. redirect_uri) that the script reads. Verify: `ls <hermes_home>/mcp-tokens/`.
2. Run the script for each server: `python force_oauth_flow.py gmail drive ...` (use the hermes venv python on Windows: `AppData/Local/hermes/hermes-agent/venv/Scripts/python.exe`).
   - Browser opens per server → user clicks Allow (unverified-app warning → **Advanced → Continue**) → callback captured on `127.0.0.1:8765` → code exchanged → token JSON written.
3. Tokens are written in HermesTokenStorage format including absolute `expires_at` — Hermes picks them up on next MCP discovery (restart Hermes or wait for reconnect).

Token JSON format (must match):
```json
{"access_token": "...", "token_type": "Bearer", "expires_in": 3599,
 "refresh_token": "...", "scope": "...", "expires_at": 1750000000.0}
```
`expires_at` (unix wall-clock) is REQUIRED — without it the SDK can't reconstruct TTL across restarts (`is_token_valid()` lies). Refresh tokens arrive only with `access_type=offline&prompt=consent` in the authorize URL.

## Pitfalls (Windows / Hermes specifics)

- **`hermes config set` works for nested keys** (`hermes config set mcp_servers.<name>.oauth.client_id <value>`). Prefer it over `hermes mcp add`, which is INTERACTIVE (probes the server, asks "Enable all N tools? [Y/n/select]") and silently CANCELS in a non-TTY → writes nothing.
- **patch/write_file tools refuse to edit Hermes config.yaml** ("security-sensitive configuration") — use the `hermes config` CLI (backup the file first: `cp config.yaml config.yaml.bak-<ts>`).
- **HERMES_HOME pollution**: a standalone `VAR=$(command)` assignment in the persistent terminal session persists (the terminal tool keeps env between calls) and corrupts later `hermes` runs (it tries to mkdir a path containing the command's output). Always `unset HERMES_HOME` before diagnosing CLI-vs-config behavior, or run `env -u HERMES_HOME hermes ...`.
- **MSYS path mangling**: passing `"$HOME/foo.py"` to a native Windows `python.exe` converts to `C:\c\Users\...` and fails. Use `C:/Users/<user>/...` form when invoking native exes from git-bash.
- **Windows: native Python subprocess resolves `bash` to WSL bash** (which can't see `/c/...` paths — "No such file or directory" on valid paths). Pin git-bash explicitly: `C:\Program Files\Git\bin\bash.exe`. Same for any path you hand to it: convert with `cygpath -w` when going bash→native-Python, or use `/c/...` form when going native-Python→git-bash.
- One OAuth client can serve ALL servers of a provider (per-project client_id/secret reused).
- Scopes are requested at runtime; declaring them in the provider console is only for app verification — **skippable** for External + test-user setups.

## Full Google Workspace recipe

Provider console steps, gcloud enable commands, per-product scopes, and server URLs: `references/google-workspace-mcp.md`.

## Verification

- `ls <hermes_home>/mcp-tokens/` shows `<server>.json` for every configured server.
- In-session: call an MCP tool (`mcp_gmail_*`, `mcp_drive_*`, ...) — tools list without auth, so `hermes mcp test` CANNOT prove auth; only a real tool call (or a non-200 on anonymous request) does.
- Before restarting Hermes, prove tokens work by hitting the provider API directly, e.g. `GET https://gmail.googleapis.com/gmail/v1/users/me/profile` with `Authorization: Bearer <token>` → 200.

## Cross-OS migration (Windows ↔ Linux)

Tokens are **portable across OSes**: `mcp-tokens/*.json` (refresh_token) + `*.client.json` work on any machine — the OAuth client lives in the provider's cloud and the redirect URI is loopback (`127.0.0.1:<port>/callback`), so nothing needs re-registering. No re-auth needed.

BUT the client_secret **cannot travel through git**:

- **GitHub push protection blocks `GOCSPX-` Google client secrets** — a commit containing one is rejected with `push declined due to repository rule violations` (the push fails; the local commit stays). Never commit OAuth secrets to a repo, even a private one; transport the secret + tokens via bundle/USB/scp instead.
- Recommended bundle: `mcp-tokens/` dir + a YAML fragment of the `mcp_servers` entries (extracted from the source config) + the `force_oauth_flow.py` script + gcloud config (`~/.config/gcloud/`). On the target, merge the fragment into the OS-specific config (paths differ per OS — keep config per-OS, don't blind-sync).
- Add `mcp-tokens/` to `.gitignore` in any sync repo so a future sync can't leak tokens.
