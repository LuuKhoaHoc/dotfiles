---
name: zed-agent-integration
description: Configure external CLI agents (Hermes Agent, Gemini CLI, Claude Code) in Zed editor via ACP
triggers:
  - "zed agent not working"
  - "zed gemini skills"
  - "zed external agent"
  - "zed acp"
  - "zed hermes"
category: editor-config
---

# Zed Agent Integration — ACP Configuration

## ACP Protocol Overview

Zed connects external CLI agents via **Agent Client Protocol (ACP)** — JSON-RPC over stdio.

Two integration types in `settings.json`:

```json
"agent_servers": {
    "my-agent": {
        "type": "custom",    // Runs CLI directly, FULL capabilities
        "command": "hermes",
        "args": ["acp"]
    },
    "gemini": {
        "type": "registry",  // Zed's wrapper, SUBSET of commands only
        "default_model": "auto-gemini-3"
    }
}
```

### Registry vs Custom type

| Type | Capabilities | Commands visible |
|------|-------------|------------------|
| `registry` | Subset only (memory, extension, about, help) | Limited to what Zed implements |
| `custom` | Full CLI capabilities | Everything the CLI supports |

**Key insight:** Registry agents (gemini, claude-acp, codex-acp) are wrapped by Zed — only Zed-implemented commands appear in slash menu. Custom agents (`type: "custom"`) run the CLI directly via ACP, exposing full toolset.

## Supported Agents

### Registry agents (Zed wrapper)
- `gemini` — Gemini CLI wrapped by Zed
- `claude-acp` — Claude Code via ACP
- `codex-acp` — OpenAI Codex

### Custom agents (full capabilities)
- `hermes-agent` — Hermes Agent via `hermes acp`
- Any CLI with ACP support

## Hermes Agent in Zed

```json
"agent_servers": {
    "hermes-agent": {
        "type": "custom",
        "command": "hermes",
        "args": ["acp"]
    }
}
```

MCP servers configured in `context_servers` are forwarded to custom agents.

## Multiple Agents

Cannot run multiple agents in single Zed session. Workaround:

1. **Multiple Zed windows** — each window uses different agent
2. **External terminal** — run agents outside Zed, use Zed only for editing

## Quick Reference

```bash
# Check available agents in Zed
# Open Command Palette → "agent:"

# View ACP logs for debugging
# Command Palette → "dev: open acp logs"

# Zed settings location
~/.config/zed/settings.json
```

## Known Limitations

- Registry agents: hooks not forwarded
- Registry agents: profiles/tool permissions not forwarded  
- Remote MCP with OAuth may have issues
- Cannot edit past messages/resume threads for external agents (as of 2025)
