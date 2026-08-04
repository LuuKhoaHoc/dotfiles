# Zed Settings — khoahoc machine

## Agent Servers Config

```json
"agent_servers": {
    "hermes-agent": {
        "type": "custom",
        "command": "hermes",
        "args": ["acp"]
    },
    "gemini": {
        "type": "registry",
        "default_model": "auto-gemini-3"
    },
    "codex-acp": {
        "type": "registry"
    },
    "claude-acp": {
        "type": "registry"
    },
    "opencode": {
        "favorite_models": ["9router/opencode-premium", "9router/opencode-fast"],
        "type": "registry"
    }
}
```

## MCP Servers Config

> **Trạng thái 2026-08**: chỉ ENABLE `mcp-server-gitlab`, `mcp-server-notion`, `mcp-server-context7`.
> Đã DISABLE (giảm token — mỗi MCP server expose toàn bộ tool schemas vào agent system prompt, gitlab ~115 tools ≈ 35-40k tokens): `agentmemory`, `mcp-server-sonarqube`, `mcp-server-figma`, `mcp-server-markitdown`, `chrome-devtools-mcp-zed`.
> Lưu ý: `settings.json` là JSONC — Python `json.loads` fail (pre-existing), Zed vẫn đọc được; sửa bằng regex có kiểm soát + backup trước.

```json
"context_servers": {
    "mcp-server-gitlab": {
        "enabled": true,
        "remote": false,
        "settings": {
            "gitlab_personal_access_token": "glpat-...",
            "gitlab_api_url": "https://gitlab.vppos.vn/api/v4"
        }
    },
    "mcp-server-figma": {
        "enabled": true,
        "remote": false,
        "settings": {
            "figma_api_key": "figd-..."
        }
    },
    "mcp-server-context7": {
        "enabled": true,
        "settings": {
            "context7_api_key": "ctx7sk-..."
        }
    }
}
```

## Default Agent

```json
"agent": {
    "default_model": {
        "provider": "zed.dev",
        "model": "claude-haiku-4-5"
    }
}
```

## Key Finding

User wants to use multiple CLI tools. Current `gemini` uses registry type → limited commands in Zed.

Solution options:
1. Use `hermes-agent` in Zed (custom type) for full capabilities
2. Use multiple Zed windows, each with different agent
3. Run Gemini CLI externally in terminal for full skills

## Tool Permissions

```json
"tool_permissions": {
    "tools": {
        "mcp:mcp-server-figma:get_figma_data": {
            "default": "allow"
        },
        "terminal": {
            "always_allow": [
                {"pattern": "^git\\b"},
                {"pattern": "^pnpm\\b"}
            ]
        },
        "fetch": {
            "always_allow": [
                {"pattern": "^https?://www\\.figma\\.com"}
            ]
        }
    }
}
```
