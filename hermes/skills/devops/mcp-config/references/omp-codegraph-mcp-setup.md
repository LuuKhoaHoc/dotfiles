# OMP (Oh My Pi) — CodeGraph MCP Integration

## Background

OMP (oh-my-pi) is a TypeScript/Rust AI coding agent (fork of Pi by Mario Zechner). It has its own MCP config format and extension system inherited from Pi.

## Symptoms

- OMP agent calls `codegraph_explore` → "Tool codegraph_explore not found"
- No codegraph-related entries in `~/.omp/logs/` at all (server silently skipped)
- `codegraph serve --mcp` works perfectly when tested directly

## Root Cause

Two possible issues:

### 1. MCP server silently skipped

The server key `"codegraph"` in `~/.omp/agent/mcp.json` may conflict with an internal OMP keyword, or OMP silently ignores certain server names. The server never appears in OMP's MCP init logs (no success, no error).

**Fix:** Rename the server key from `"codegraph"` to `"mcp-server-codegraph"` or another distinct name.

### 2. Missing Pi-style extension

The old Pi extension at `~/.pi/agent/extensions/codegraph.js` hooks into `before_agent_start` and runs `codegraph explore "<prompt>"` via shell command, injecting output into the system prompt. This is different from MCP tool calling — it provides context, not a tool.

If the extension is missing from `~/.omp/agent/extensions/`, symlink it:

```bash
ln -sf ~/.pi/agent/extensions/codegraph.js ~/.omp/agent/extensions/codegraph.js
```

## Verification

```bash
# Test codegraph MCP server standalone
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}\n{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}\n' | timeout 5 codegraph serve --mcp 2>/dev/null | python3 -m json.tool --no-ensure-ascii 2>/dev/null || echo "Direct test"
```

Check for `codegraph_explore` in the tools list response.

## Configuration File

Location: `~/.omp/agent/mcp.json`

```json
{
  "mcpServers": {
    "codegraph": {
      "command": "codegraph",
      "args": ["serve", "--mcp"]
    }
  }
}
```

## Related Files

- `~/.omp/agent/config.yml` — model roles, theme, provider config
- `~/.omp/agent/extensions/` — Pi-style `.js` extensions (different from MCP)
- `~/.omp/logs/omp.YYYY-MM-DD.*.log` — MCP init logs (search for "MCP" and "mcp:")
