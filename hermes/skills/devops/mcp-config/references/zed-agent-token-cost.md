# Zed Agent Token Cost — Verified Breakdown (2026-08)

## Incident

User pinged the Zed agent in the erp-admin repo ("ping" → "pong"). Agent panel showed **Input: 75k / 224k**, Output: 19/32k, Rules: 1 global + 1 project.

## Root cause

Zed injects the FULL tool schema list of every enabled `context_servers` MCP server into the agent context on every turn. Rules (AGENTS.md) were only ~6k tokens — the rest was tool schemas.

## Machine state (khoahoc, ~/.config/zed/settings.json)

8 context_servers enabled: mcp-server-gitlab (115 tools, ~35-40k), chrome-devtools-mcp-zed (~30), mcp-server-notion (~14), mcp-server-figma (~10), mcp-server-sonarqube (~10), mcp-server-markitdown (5), agentmemory (~4), mcp-server-context7 (2). Total ~190 tools ≈ 55-60k tokens + system prompt + rules ≈ 75k.

## Evidence

- Zed docs — Agent Panel: "MCP tools are available in a Zed Agent thread" (https://zed.dev/docs/ai/agent-panel)
- Context servers from settings.json expose their tools in the Agent Panel (https://www.linkedin.com/pulse/give-zeds-ai-assistant-persistent-memory-vectorizeio-xgx6c)
- Agent panel header itself shows Input/Output tokens + Rules loaded — first place to look when a user reports token bloat.

## Fix recipes (applied on request)

1. Disable unused servers:
   ```json
   "context_servers": { "mcp-server-notion": { "enabled": false } }
   ```
2. Per-project scoping: declare only needed servers in `<repo>/.zed/settings.json`, disable in global.
3. Keeping only gitlab + context7 saves ~30-40k tokens per call.

## Reading Zed settings

`settings.json` is JSONC (starts with `// settings.json, generated at ...`) → `python json.load()` throws `JSONDecodeError: Expecting value: line 1 column 1`. Use grep/sed or strip `//` lines. File contains live API tokens (gitlab/figma/notion/sonarqube/context7) — mask when sharing notes.
