# Zed → OpenCode MCP Mapping (VPPOS Environment)

## Zed Extensions Installed

| Extension | id | Package | Env Vars / CLI Args |
|---|---|---|---|
| SonarQube MCP | `mcp-server-sonarqube` | `sonarqube-mcp-server` | `SONARQUBE_TOKEN=squ_<redacted>`, `SONARQUBE_URL=https://sonar.vppos.vn` |
| Chrome DevTools MCP | `chrome-devtools-mcp-zed` | `chrome-devtools-mcp` | (none required) |
| AgentMemory | `agentmemory` | `@agentmemory/mcp` | `AGENTMEMORY_URL=http://localhost:3111` |
| Notion MCP | `mcp-server-notion` | `@notionhq/notion-mcp-server` | `NOTION_TOKEN=ntn_<redacted>` |
| Figma MCP | `mcp-server-figma` | `figma-developer-mcp` | `FIGMA_API_KEY=figd_<redacted>` |
| GitLab MCP | `mcp-server-gitlab` | `@zereight/mcp-gitlab` | CLI: `--token=glpat-<redacted> --api-url=https://gitlab.vppos.vn/api/v4 --read-only=true` |
| Context7 MCP | `mcp-server-context7` | `@upstash/context7-mcp` | `CONTEXT7_API_KEY=ctx7sk-<redacted>` |
| MarkItDown | `mcp-server-markitdown` | `markitdown-mcp-npx` | — |
| Sequential Thinking | `mcp-server-sequential-thinking` | `@modelcontextprotocol/server-sequential-thinking` | (none) |

## Zed Extension Source Repos

| Extension | Repository | PACKAGE_NAME constant |
|---|---|---|
| GitLab | https://github.com/akbxr/gitlab-mcp-zed | `@zereight/mcp-gitlab` |
| Context7 | https://github.com/akbxr/zed-mcp-server-context7 | (Check `src/lib.rs`) |
| Figma | https://github.com/LoamStudios/zed-mcp-server-figma | (Check `src/lib.rs`) |
| Notion | https://github.com/f1729/zed-notion-mcp | (Check `src/lib.rs`) |
| Sequential Thinking | https://github.com/LoamStudios/zed-mcp-server-sequential-thinking | (Check `src/lib.rs`) |
| SonarQube | https://github.com/SonarSource/sonarqube-mcp-server | (Check `src/lib.rs`) |

## Zed Extension Connection Pattern

All Zed MCP extensions follow the same Rust pattern (from `src/mcp_server_*.rs`):

```rust
fn context_server_command(&mut self, _context_server_id: &ContextServerId, project: &Project) -> Result<Command> {
    // 1. Resolve npm package version
    let latest_version = zed::npm_package_latest_version(PACKAGE_NAME)?;
    let version = zed::npm_package_installed_version(PACKAGE_NAME)?;
    if version != latest_version {
        zed::npm_install_package(PACKAGE_NAME, &latest_version)?;
    }

    // 2. Read user settings from settings.json (context_servers.<id>.settings)
    let settings = ContextServerSettings::for_project("mcp-server-xxx", project)?;

    // 3. Return Command with Node.js binary + path to built JS
    Ok(Command {
        command: zed::node_binary_path()?,
        args: vec![env::current_dir().unwrap().join(SERVER_PATH).to_string_lossy().to_string()],
        env: vec![("ENV_VAR".into(), settings.value), ...],
    })
}
```

## OpenCode JSON Format

File: `~/.config/opencode/opencode.json`

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "server-name": {
      "type": "local",
      "command": ["npx", "-y", "@package/name"],
      "enabled": true,
      "env": {
        "ENV_VAR": "value"
      }
    }
  }
}
```

OpenCode also supports an `opencode mcp add` CLI:
- Local stdio: `opencode mcp add <name> -- <command>`
- Remote URL: `opencode mcp add <name> --url <url>`

## Key Discoveries

1. **Zed's GitLab MCP uses `@zereight/mcp-gitlab` NOT `@modelcontextprotocol/server-gitlab`** — the latter is the official MCP org version, but Zed extension wraps a different package.

2. **Env vars fail for `@zereight/mcp-gitlab` in OpenCode** — "Connection closed" error when using `env:` block. Fix: pass `--token=`, `--api-url=`, `--read-only=true` as CLI args in the `command` array.

3. **npx startup latency** — OpenCode may timeout if npx needs to download. Pre-install globally: `npm install -g @package`.

4. **OpenCode env block passes literal strings** — unlike Zed's `${VAR}` interpolation which reads shell env vars. For secrets stored in env, resolve manually before writing the config.
