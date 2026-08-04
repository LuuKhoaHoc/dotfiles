---
name: mcp-tooling
description: "Configure, migrate, and troubleshoot MCP servers across MCP hosts (OpenCode, Zed, VS Code, Claude Desktop)."
version: 1.0.0
author: Hermes Agent
platforms: [linux, macos]
metadata:
  hermes:
    tags: [MCP, Configuration, Integration, Migration, Testing]
    related_skills: [zed-agent-integration, opencode, claude-code, codex]
---

# MCP Tooling

Manage MCP (Model Context Protocol) server configurations across the ecosystem of MCP hosts. Covers the common CLI/JSON patterns, migration between tools, and troubleshooting.

## When to Use

- User asks to connect MCP servers from one tool to another (Zed→OpenCode, VS Code→Claude Desktop, etc.)
- User wants to configure MCP servers in a new tool
- An MCP server is failing to connect and needs debugging
- User wants to understand what env vars/commands an MCP server needs

## General MCP Config Pattern

Every MCP host needs three things per server:

1. **Command**: What executable to run (usually `npx -y <package>`)
2. **Arguments**: Array of CLI args to the command
3. **Environment variables**: Secrets and configuration the server reads

Most tools use a JSON config but vary the key names:

| Host | Config Key | Format |
|------|-----------|--------|
| OpenCode | `mcp` in `opencode.json` | `{type, command[], enabled, env{}}` |
| **OMP (oh-my-pi)** | `mcpServers` in `~/.omp/agent/mcp.json` | `{command (string), args[], env{}}` |
| Zed | `context_servers` in `settings.json` | `{command, args[], settings{}, env{}}` |
| Claude Desktop | `mcpServers` in `claude_desktop_config.json` | `{command, args[], env{}}` |
| VS Code | `mcp.servers` in settings | `{command, args[], env{}}` |
| Cline | `mcpServers` in `cline_mcp_settings.json` | `{command, args[], env{}}` |
| Gemini CLI / Antigravity IDE | `mcpServers` in `~/.gemini/config/mcp_config.json` | `{command, args[], env{}}` (VS Code schema) |

## OpenCode MCP Configuration

### JSON Config (`~/.config/opencode/opencode.json`)

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "server-name": {
      "type": "local",
      "command": ["npx", "-y", "@package/mcp-server"],
      "enabled": true,
      "env": {
        "API_KEY": "literal-secret-value"
      }
    }
  }
}
```

### CLI Add

```bash
# Local stdio MCP — command goes after `--`
opencode mcp add <name> -- npx -y @package/mcp-server

# With env vars
opencode mcp add <name> --env KEY=VALUE -- npx -y package

# Remote streamable HTTP
opencode mcp add <name> --url https://example.com/mcp

# Verify
opencode mcp list
```

### Key Differences From Other Tools

- **No interpolation**: OpenCode's `env` values are literal strings — resolve `$VAR` or `${VAR}` references before writing. Some other hosts (Zed, Antigravity) DO resolve `${VAR}` in their settings.
- **Command as array**: OpenCode expects `command: ["npx", "-y", "pkg"]` not `command: "npx"` with `args: ["-y", "pkg"]` like Zed, Claude Desktop, or VS Code.
- **`type` field**: Must be `"local"` (stdio) or `"remote"` (SSE/HTTP). Omitting it defaults to local.
- **Verify with** `opencode mcp list` which shows connected/failed/disabled per server.
- **Env var passthrough**: Some OpenCode versions fail to pass `env` to child processes. Workaround: use CLI args instead of env vars for packages that support both (e.g. `@zereight/mcp-gitlab` with `--token=...`).

## OMP (oh-my-pi) MCP Configuration

### JSON Config (`~/.omp/agent/mcp.json`)

```json
{
  "$schema": "https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/src/config/mcp-schema.json",
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@package/mcp-server"],
      "env": {
        "API_KEY": "literal-secret-value"
      }
    }
  },
  "disabledServers": ["optional-disabled-server"]
}
```

### Key Differences From OpenCode
- **Config path**: `~/.omp/agent/mcp.json` (not `~/.config/opencode/opencode.json`)
- **Top-level key**: `mcpServers` (not `mcp`)
- **Command format**: `command` is a **string** + `args` is a **separate array** (OpenCode uses `command` as an array with no separate `args`)
- **No `type` field** — OMP assumes stdio/local
- **No `enabled` field** — use `disabledServers` array at root to disable servers
- **Schema**: uses oh-my-pi's own JSON schema (`$schema` field)

### OpenCode → OMP Migration
1. `command: ["npx", "-y", "pkg"]` → `"command": "npx", "args": ["-y", "pkg"]`
2. Move `env` as-is (same string key-value format)
3. Drop `type` and `enabled` fields
4. Add `$schema` from oh-my-pi repo
5. Write to `~/.omp/agent/mcp.json`

## Zed → OpenCode Migration

### Extract From Zed

Zed stores MCP servers in `~/.config/zed/settings.json` under `context_servers`:

```json
"context_servers": {
  "server-name": {
    "enabled": true,
    "remote": false,
    "command": "npx",
    "args": ["-y", "@package/server"],
    "env": {
      "TOKEN": "actual-value-or-${VAR_REF}"
    },
    "settings": {
      "api_key": "also-a-common-pattern"
    }
  }
}
```

Zed extensions (`.extension.wasm` files under `~/.local/share/zed/extensions/installed/`) bundle the MCP adapter logic in Rust Wasm. The extension.toml declares which `context_servers` the extension provides, but the actual command/env/args are compiled into the `.wasm` binary and not directly inspectable.

To find the real npm package behind a Zed extension:
1. Look for npx cached packages at `~/.npm/_npx/<hash>/node_modules/<package>/package.json`
2. The Zed extension repo (often on GitHub) may reveal the package — search `akbxr/gitlab-mcp-zed` style repos
3. Extension.toml shows `repository` field with the source repo URL

**⚠️ Zed GitLab extension uses `@zereight/mcp-gitlab` (NOT `@modelcontextprotocol/server-gitlab`)** — discovered by reading the Rust source at `https://github.com/akbxr/gitlab-mcp-zed/blob/master/src/mcp_server_gitlab.rs`:
```rust
const PACKAGE_NAME: &str = "@zereight/mcp-gitlab";
const SERVER_PATH: &str = "node_modules/@zereight/mcp-gitlab/build/index.js";
```
Zed installs the package via `zed::npm_install_package()` then runs it directly with Node.js (not npx). The `@zereight/mcp-gitlab` package also supports CLI args (`--token=...`, `--api-url=...`, `--read-only=true`) which work where env var passthrough is broken.

### Conversion Steps

1. Combine `command + args` into OpenCode's `command` array: `["npx", "-y", "@package/server"]`
2. Resolve `${VAR}` references from shell environment: `echo $VAR`
3. Merge `settings` into `env` — most MCP servers convert settings keys to uppercase env vars (e.g. `notion_token` → `NOTION_TOKEN`)
4. Set `type: "local"` and `enabled: true`
5. Write under `mcp` key in OpenCode config

## Common MCP Servers (npx-ready)

| Service | npx Package | Required Env Vars | CLI Args Alternative |
|---------|------------|-------------------|----------------------|
| GitLab (official) | `@modelcontextprotocol/server-gitlab` | `GITLAB_PERSONAL_ACCESS_TOKEN`, `GITLAB_API_URL` | — |
| GitLab (Zed variant) | `@zereight/mcp-gitlab` | `GITLAB_PERSONAL_ACCESS_TOKEN`, `GITLAB_API_URL` | `--token=... --api-url=... --read-only=true` |
| SonarQube | `sonarqube-mcp-server` | `SONARQUBE_TOKEN`, `SONARQUBE_URL` | — |
| Notion | `@notionhq/notion-mcp-server` | `NOTION_TOKEN` | — |
| Figma | `figma-developer-mcp` | `FIGMA_API_KEY` | — |
| Context7 | `@upstash/context7-mcp` | `CONTEXT7_API_KEY` | — |
| Chrome DevTools | `chrome-devtools-mcp` | (all settings optional) | — |
| Sequential Thinking | `@modelcontextprotocol/server-sequential-thinking` | (none) | — |
| AgentMemory | `@agentmemory/mcp` | `AGENTMEMORY_URL`, `AGENTMEMORY_SECRET` | — |
| MarkItDown | `markitdown-mcp-npx` | (none) | — |

## Troubleshooting

### MCP Server Fails to Connect

1. **Test the raw command**: Missing env vars print clear errors like "X environment variable is not set"
   ```bash
   echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' | GITLAB_TOKEN=x npx -y @modelcontextprotocol/server-gitlab
   ```

2. **"Connection closed"** → The server started but couldn't initialize (usually missing or invalid env var)

3. **"Operation timed out"** → Server can't reach its upstream API (network/firewall/proxy issue)

4. **Check npm cache**: `~/.npm/_npx/` stores cached versions — inspect `package.json` for bin paths

5. **Find the real config**: Zed extension Wasm files bundle the MCP command internally. The npx packages are cached at `~/.npm/_npx/*/node_modules/`

### Pitfalls

- OpenCode's `env` is literal — no interpolation. Don't use `${VAR}` unless the host resolves it. Zed and Antigravity DO resolve `${VAR}` in their settings context.
- `opencode mcp add` without `-- <command>` errors: "Provide either --url or a command after --"
- Bundled Zed MCP extensions (`.wasm`) can't be directly extracted — use the corresponding npx package or check the extension's GitHub repo
- Figma MCP (`figma-developer-mcp`) requires outbound HTTPS to `api.figma.com` — fails behind restrictive proxies
- **Env var passthrough broken in OpenCode**: Some OpenCode versions don't pass `env` to child processes. If a server shows "Connection closed", try using CLI args (`--token=...`, `--api-url=...`) instead of `env` for packages that support both (e.g. `@zereight/mcp-gitlab`, `sonarqube-mcp-server`)
- **Zed uses `@zereight/mcp-gitlab` for GitLab**, not the official `@modelcontextprotocol/server-gitlab`. The official package does NOT work with Zed-style config. Use `@zereight/mcp-gitlab` when mirroring Zed's exact GitLab setup.
- **SonarQube env var naming**: The package `sonarqube-mcp-server` expects `SONARQUBE_TOKEN`, `SONARQUBE_URL`, not `SONARQUBE_ORG` (actual key is `SONARQUBE_ORGANIZATION_KEY`). Check the package README for exact env var names.
- Configs in dotfiles often have `__REDACTED__` tokens — use `~/.config/zed/settings.json` (the real non-symlinked config) for actual values.

## Verification

```bash
# OpenCode
opencode mcp list

# Check that MCP tool calls work (e.g. through agent's tool use)
# Or for GitLab, test raw API access:
curl -s -H "PRIVATE-TOKEN: $TOKEN" "$GITLAB_API_URL/user" | head -1
```
