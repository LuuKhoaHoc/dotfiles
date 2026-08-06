# Zed → OpenCode MCP Migration (2026-07-01)

## Source: Zed context_servers

Found in `~/.config/zed/settings.json` (not the dotfiles symlink — dotfiles has `__REDACTED__` secrets, the real config has literal values).

```json
"context_servers": {
  "mcp-server-markitdown": { "enabled": true, "remote": false, "settings": {} },
  "mcp-server-sonarqube": { "enabled": true, "remote": false, "settings": { "sonarqube_token": "...", "sonarqube_url": "https://sonar.vppos.vn", ... } },
  "chrome-devtools-mcp-zed": { "enabled": true, "remote": false, "settings": { ... } },
  "agentmemory": { "enabled": true, "remote": false, "command": "npx", "args": ["-y", "@agentmemory/mcp"], "env": { ... } },
  "mcp-server-notion": { "enabled": true, "remote": false, "settings": { "notion_token": "${NOTION_TOKEN}" } },
  "mcp-server-figma": { "enabled": true, "remote": false, "settings": { "figma_api_key": "..." } },
  "mcp-server-gitlab": { "enabled": true, "remote": false, "settings": { "gitlab_personal_access_token": "...", "gitlab_api_url": "https://gitlab.vppos.vn/api/v4" } },
  "mcp-server-context7": { "enabled": true, "remote": false, "settings": { "context7_api_key": "..." } }
}
```

Also installed but not in context_servers: `mcp-server-sequential-thinking`.

## Discovery Process

1. OpenCode docs at opencode.ai returned empty pages — unusable as source of truth
2. `opencode --help` revealed `opencode mcp add/list/auth/logout/debug` subcommands
3. `opencode mcp add --help` showed options: `--url`, `--env`, `--header` — **no `--command` flag**
4. Running `opencode mcp add test --env FOO=bar` errored with: *"Provide either --url or a command after --"* → the `-- ` separator passes the command
5. `opencode mcp add name -- npx -y @agentmemory/mcp` successfully added the server
6. The dotfiles opencode.json at `~/.dotfiles/opencode/opencode.json` had an `mcp` section with `type: "local"`, `command: [...]`, `enabled`, `env` — confirmed the JSON format
7. `opencode mcp list` showed connected/failed status per server

## Zed Extension → npx Mapping

Zed extensions are Wasm-compiled (`.extension.wasm` + `extension.toml`), not inspectable. The actual npx packages were found in:

```
~/.npm/_npx/<hash>/node_modules/<package>/
```

| Zed Extension | npx Package |
|--------------|-------------|
| mcp-server-sonarqube | `sonarqube-mcp-server` |
| chrome-devtools-mcp-zed | `chrome-devtools-mcp` |
| mcp-server-notion | `@notionhq/notion-mcp-server` |
| mcp-server-figma | `figma-developer-mcp` |
| mcp-server-gitlab | `@modelcontextprotocol/server-gitlab` |
| mcp-server-context7 | `@upstash/context7-mcp` |
| mcp-server-markitdown | `markitdown-mcp-npx` |

## Results

5 of 8 MCP servers connected successfully initially. 2 failed (GitLab — "Connection closed", Figma — timeout).

## GitLab Fix: @zereight/mcp-gitlab (2026-07-01)

**Root cause**: Zed actually uses `@zereight/mcp-gitlab` for GitLab, NOT `@modelcontextprotocol/server-gitlab`. The Zed extension at `akbxr/gitlab-mcp-zed` is a Rust Wasm adapter that:
1. Installs npm package `@zereight/mcp-gitlab` via `zed::npm_install_package()`
2. Runs it with Node.js: `node node_modules/@zereight/mcp-gitlab/build/index.js`
3. Passes env vars `GITLAB_PERSONAL_ACCESS_TOKEN` + `GITLAB_API_URL`

**OpenCode env var issue**: Even with the correct package, OpenCode wouldn't connect using env vars ("Connection closed"). **Fix**: install globally and use CLI args instead:
```
npm install -g @zereight/mcp-gitlab
→ command: ["/path/to/zereight-mcp-gitlab", "--token=...", "--api-url=...", "--read-only=true"]
```
This connected immediately.

**Final count**: 6/8 connected (GitLab fixed with correct package + CLI args).

## Antigravity IDE / Gemini Config (2026-07-01)

The correct config file for antigravity IDE MCP servers is NOT `~/.gemini/antigravity-ide/mcp_config.json` but:
```
~/.gemini/config/mcp_config.json
```
This file uses the VS Code `mcpServers` format (command + args strings, not arrays). The gitlab entry was also using the wrong package and env vars — same fix applied.

## Notion Token Discovery

Zed's config had `"notion_token": "${NOTION_TOKEN}"` — an env var reference. The actual value was:
```
NOTION_TOKEN=ntn_<redacted>
```
OpenCode's `env` takes literal values only, so `${NOTION_TOKEN}` in the config passes the literal string `${NOTION_TOKEN}` to the subprocess. It must be resolved before writing.
