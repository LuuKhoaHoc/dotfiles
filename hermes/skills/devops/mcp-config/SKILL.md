---
name: mcp-config
title: MCP Configuration and Cross-Editor Mapping
description: "Configure, diagnose, and migrate MCP servers between editors/agents (Zed, OpenCode, VS Code, Claude). Map extension-wrapped servers to their underlying npm packages."
---

# MCP Configuration and Cross-Editor Mapping

Configure MCP servers across different editors and AI coding agents. Map settings, extract env vars, and debug connection issues.

## Trigger

- User asks to "connect MCP from X to Y" (Zed → OpenCode, VS Code → Claude Code, etc.)
- User reports an MCP server failing to connect in a new client
- User asks for the OpenCode/Claude Code JSON format for an MCP server

## Overview

Most MCP servers are npm packages run via `npx`. Different editors/agents use different config schemas but the underlying packages are the same. The key task is finding the CORRECT npm package and passing the right env vars.

## Finding the Real MCP Server Package

When an editor bundles an MCP server as an extension:

### Zed Extensions
1. Find the extension source repo (from `extension.toml` or README)
2. Read `src/lib.rs` or `src/<server_name>.rs` for the Rust `context_server_command` implementation
3. Look for `const PACKAGE_NAME` and `const SERVER_PATH` constants
4. The env vars are constructed in the `command` handler

**Example** (GitLab in Zed):
```rust
const PACKAGE_NAME: &str = "@zereight/mcp-gitlab";
const SERVER_PATH: &str = "node_modules/@zereight/mcp-gitlab/build/index.js";
```

### VS Code Extensions
- Check `package.json` → `contributes.configuration` for settings
- The `mcp` block or `contributes.mcpServers` section lists the actual command

## OpenCode MCP Config Format

`~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "server-name": {
      "type": "local",
      "command": ["npx", "-y", "@package/name"],
      "enabled": true,
      "env": {
        "API_KEY": "secret"
      }
    }
  }
}
```

### CLI Alternative
```bash
opencode mcp add <name> -- <command> [args...]
opencode mcp add <name> --url <remote-url>
opencode mcp list
```

### Key Format Rules
- `type: "local"` for stdio MCP servers
- `command` is an **array** of `[executable, arg1, arg2, ...]`
- `env` is a flat object of string key-value pairs
- Tokens can be passed as CLI args (`--token=...`) instead of env vars when env vars don't work

## Common MCP Server Mappings

| Editor Setting Key | npm Package | Typical Env Vars |
|---|---|---|
| `mcp-server-gitlab` | `@zereight/mcp-gitlab` | `GITLAB_PERSONAL_ACCESS_TOKEN`, `GITLAB_API_URL` |
| `mcp-server-sonarqube` | `sonarqube-mcp-server` | `SONARQUBE_TOKEN`, `SONARQUBE_URL` |
| `mcp-server-notion` | `@notionhq/notion-mcp-server` | `NOTION_TOKEN` |
| `mcp-server-figma` | `figma-developer-mcp` | `FIGMA_API_KEY` |
| `mcp-server-context7` | `@upstash/context7-mcp` | `CONTEXT7_API_KEY` |
| `chrome-devtools-mcp` | `chrome-devtools-mcp` | (none required, or `CHROME_*`) |
| `agentmemory` | `@agentmemory/mcp` | `AGENTMEMORY_URL`, `AGENTMEMORY_SECRET` |
| `mcp-server-markitdown` | `markitdown-mcp-npx` | (varies) |
| `mcp-server-sequential-thinking` | `@modelcontextprotocol/server-sequential-thinking` | (none) |

## Debugging MCP Connections

### Test Server Individually
```bash
npm install -g @zereight/mcp-gitlab

node -e "
const { spawn } = require('child_process');
const t = spawn('zereight-mcp-gitlab', ['--read-only=true'], {
  env: { ...process.env, TOKEN: '...', API_URL: '...' }
});
let stdout = '';
t.stdout.on('data', d => { stdout += d.toString(); });
setTimeout(() => {
  t.stdin.write(JSON.stringify({
    jsonrpc: '2.0', id: 1, method: 'initialize',
    params: { protocolVersion: '2024-11-05', capabilities: { tools: {} },
      clientInfo: { name: 'test', version: '1.0' } }
  }) + '\n');
}, 2000);
setTimeout(() => { t.kill(); console.log(stdout); }, 5000);
"
```

### Check Connection
```bash
opencode mcp list
```

### Common Failure Patterns

| Error | Likely Cause | Fix |
|---|---|---|
| `Connection closed` | Wrong package or env vars not being passed | Try CLI args instead of env vars (`--token=...`) |
| `Operation timed out` | API unreachable (VPN/firewall) or invalid API key | Check network and token validity |
| `MCP error -32603` | Internal server error or initialization failure | Test server standalone |
| Missing `command` | Package not found in PATH | Install globally or use absolute path |
| **MCP server silently skipped** (no MCP init log at all) | Server name conflicts with internal keyword, or agent silently ignores certain server keys | Try renaming the server key; check agent logs for MCP init sequence |

### Agent-Specific MCP Quirks

| Agent | MCP Config Location | Quirks |
|---|---|---|
| **OMP (oh-my-pi)** | `~/.omp/agent/mcp.json` | May silently skip servers named with bare keywords (e.g. `"codegraph"`). Prefix with `mcp-server-` or use a more descriptive name. Also supports Pi-style `.js` extensions at `~/.omp/agent/extensions/` for some features. Logs at `~/.omp/logs/`. |
| **Claude Code** | `~/.claude/mcp.json` | Permissions in `~/.claude/settings.json` under `permissions.allow`. Supports `mcp__<server>__*` wildcards. |
| **Cursor** | `.cursor/mcp.json` (project root or user config) | — |
| **OpenCode** | `~/.config/opencode/opencode.json` under `mcp` key | Uses array-format `command`. Npx delays may cause timeout — prefer direct binary paths. |
| **Zed** | `~/.config/zed/settings.json` (`context_servers`) — file is JSONC (`//` comments); `python json.load()` fails, use grep/sed | ALL enabled context servers' tools are injected into the agent context on EVERY turn; no per-tool opt-out. |

## Token Cost: Enabled MCP Servers Inflate Every Agent Turn

Every enabled MCP server's FULL tool list (name + description + params JSON schema, ~200–400 tokens per tool) is injected into the agent context on every turn — even a trivial prompt like "ping". This dominates input token usage far more than AGENTS.md files.

Verified (2026-08, Zed agent panel, khoahoc machine): 8 context_servers enabled → ~190 tools ≈ 55–60k input tokens; one "ping" consumed 75k/224k.

| Server | ~tools | ~tokens/turn |
|---|---|---|
| gitlab (`@zereight/mcp-gitlab`) | 115 | 35–40k |
| chrome-devtools-mcp | ~30 | ~10k |
| notion | ~14 | ~5k |
| figma | ~10 | ~3.5k |
| sonarqube | ~10 | ~3.5k |
| markitdown | 5 | ~1.5k |
| agentmemory | ~4 | ~1.2k |
| context7 | 2 | ~0.6k |

Mitigations:
1. `"enabled": false` on unused servers.
2. Move servers to per-project config (e.g. `<repo>/.zed/settings.json`) so only repos that need them load them.
3. No per-server/per-tool opt-out exists in Zed — enabled means injected.

Full verified breakdown (machine state, evidence, fix recipes): `references/zed-agent-token-cost.md`.

## Pitfalls

- **Zed extensions use Wasm-compiled adapters** — extension.toml only declares capabilities. The actual npm package and command are hardcoded in Rust source. Read the source repo.
- **`@modelcontextprotocol/server-gitlab` is NOT what Zed uses** — Zed uses `@zereight/mcp-gitlab`.
- **OpenCode env vars are passed literally** — unlike Zed's `${VAR}` interpolation. OpenCode passes the string value as-is. Use actual values or CLI args.
- **Some MCP servers fail with env vars in OpenCode** but work with CLI args (`--token=`, `--api-url=`, `--read-only=true`). Prefer CLI args for tokens.
- **`npx` adds startup latency** — for OpenCode, `npm install -g` the package and use the binary path directly to avoid timeout.
- **Token scopes matter** — a token that works for REST API (`curl -H "PRIVATE-TOKEN: $tok"` returning 200) may fail in the MCP server if lacking required GitLab scopes.
- **Node-path MCP servers** — if the server uses `npx`, pre-cache by running once manually. Failure on first run is often just npx download delay.

## Verification

```bash
opencode mcp list
# Expected: ✓ connected for each properly configured server
```
