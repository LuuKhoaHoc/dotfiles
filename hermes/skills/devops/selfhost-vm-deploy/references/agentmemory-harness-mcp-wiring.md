# agentmemory ↔ harness MCP wiring (supermemory→agentmemory migration, verified 2026-08-15)

## Why a local stdio bridge instead of the official shim

- `agentmemory mcp` (= `npx @agentmemory/mcp`) is a **stdio-only** MCP server. Stdio MCP clients spawn the process locally, so a shim running on the VM is unreachable from local harnesses. Exposing it remotely would need mcp-proxy + a new cloudflared route + auth — extra attack surface for no gain.
- `agentmemory connect <agent>` only wires agents **installed on the VM itself** (claude-code, codex, gemini-cli, ... on the VM). The user's harnesses run on the local machine → does not apply.
- Local bridge = the exact supermemory-mcp pattern already proven across 5+ harnesses: one small Node script, secret stays local (never exposed via tunnel), tool names mirror the official shim so docs/prompts stay accurate. Config change per harness is just `command` + `env`.

## The bridge (`~/.local/bin/agentmemory-mcp`)

- Lives at `~/.local/share/agentmemory-mcp/` (package.json + index.js), symlinked into `~/.local/bin/`. Deps: `@modelcontextprotocol/sdk` + `zod`.
- **`npm init -y` leaves `"type"` unset (CJS)** → `SyntaxError: Cannot use import statement outside a module`. Set `"type": "module"` in package.json.
- Env: `AGENTMEMORY_SECRET` (required) + `AGENTMEMORY_BASE_URL` (default `https://mem.luukhoahoc.me`). Keep a local copy of the secret in `~/.agentmemory-bridge.env` (chmod 600).
- Tools (mirror official shim v0.9.28 exactly): `memory_recall`, `memory_save`, `memory_sessions`, `memory_smart_search`, `memory_export`, `memory_audit`, `memory_governance_delete`.
- REST mapping: recall→`POST /search {query, limit, format:"full"}`; save→`POST /remember`; sessions→`/sessions`; smart→`/smart-search`; export→`/export`; audit→`/audit`; governance_delete→**`POST /forget`** (`/governance-delete` does not exist; `/forget` wants `memoryId` SINGULAR — else `{"error":"sessionId or memoryId is required"}`).
- `remember` gotcha: `concepts` / `files` must be **arrays** — a comma string returns HTTP 201 but `{"error":"concepts must be an array"}` and no memory. Bridge splits comma-separated strings client-side.
- `search` full format: `results[].observation.{id, narrative, title, facts[], type, timestamp}` → surface `narrative || title || join(facts,"\n")`, similarity = `score`.
- `profile` endpoint returns nothing usable (no profile entity in agentmemory) → bridge `get_profile` falls back to `/search`.

## Per-harness config (all point at the local bridge)

| Harness | File | Change |
|---|---|---|
| omp | `~/.omp/agent/mcp.json` | `"agentmemory": {"command": "<bridge>", "env": {AGENTMEMORY_SECRET}}` (no `type` key needed) |
| gemini/antigravity | `~/.gemini/config/mcp_config.json` | `{"type":"stdio","command":"<bridge>","env":{...}}` — antigravity (agy) reads the same file |
| codex | `~/.codex/config.toml` | `[mcp_servers.agentmemory] command = "<bridge>", env = { AGENTMEMORY_SECRET = "..." }` |
| opencode | `~/.config/opencode/opencode.json` | remove plugin `opencode-supermemory@latest`; add `"mcp": {"agentmemory": {"type":"local","command":["<bridge>"],"environment":{...},"enabled":true}}` |
| Zed | `~/.config/zed/settings.json` | top-level `context_servers` (NOT `mcp`!) + per-profile allowlists at `agent.profiles.<name>.context_servers.<server>.tools` |
| Hermes | plugin fork + `config.yaml` | see below |
| global-context | `dotfiles/agents/global-context.md` | rename Memory section + `agents-sync apply` (6 harness files) |

### Zed settings.json is JSONC with TRAILING COMMAS

`python json.load()` fails twice over: `//` comments AND trailing commas (`"enabled": true,` before `}`). Both must be stripped:

```python
import json, re
def strip_jsonc(t):  # removes // and /* */ outside strings
    out, i, n, s = [], 0, len(t), False
    while i < n:
        c = t[i]
        if s:
            out.append(c)
            if c == '\\' and i+1 < n: out.append(t[i+1]); i += 2; continue
            if c == '"': s = False
            i += 1; continue
        if c == '"': s = True; out.append(c); i += 1; continue
        if c == '/' and i+1 < n and t[i+1] == '/':
            while i < n and t[i] != '\n': i += 1
            continue
        out.append(c); i += 1
    return ''.join(out)
d = json.loads(re.sub(r',(\s*[}\]])', r'\1', strip_jsonc(open(p).read())))
```

Also: `agent` may contain boolean values (not only profile dicts) — guard with `isinstance(prof, dict)` before descending into `profiles`. Tool allowlist rename: `search_memory/add_memory/listMemories/whoAmI` → `memory_recall/memory_save/memory_smart_search/memory_sessions`.

### Hermes provider plugin fork

- Copy `plugins/memory/supermemory/` → `plugins/memory/agentmemory/` in the hermes-agent tree; strip `__pycache__` (stale bytecode).
- Replace the SDK-based `_SupermemoryClient` with a urllib REST client (same endpoints as the bridge; `add_memory`→`/remember` with `type`/`concepts`(array)/`files`(array) pulled from metadata; `search_memories`→`/search`; `get_profile`→search fallback returning `{"static":[], "dynamic":[], "search_results":[...]}`; `forget_memory`→`/forget {memoryId}`; `ingest_conversation`→`/observe {hookType:"session_end", sessionId, project, cwd, timestamp, messages}`).
- Rename everywhere: provider class → `AgentmemoryMemoryProvider`, `name` → `"agentmemory"`, secret env `SUPERMEMORY_API_KEY` → `AGENTMEMORY_SECRET`, base URL default → `https://mem.luukhoahoc.me`, tool names → `agentmemory_store/search/forget/profile` (+ kebab aliases). `system_prompt_block` → "# Agentmemory / Active. Server: <base_url>".
- Enable: `memory.provider: agentmemory` in `~/.hermes/config.yaml`, `AGENTMEMORY_SECRET=...` appended to `~/.hermes/.env`. Local `~/.hermes/memories/MEMORY.md|USER.md` keep working — provider is only the semantic layer.
- Verify by importing the plugin directly (PYTHONPATH=hermes-agent dir, set env, `initialize` → `prefetch` → `handle_tool_call`).

## Cloudflare blocks Python urllib on tunnel hostnames (error 1010)

- Symptom: urllib REST calls to `https://mem.luukhoahoc.me/agentmemory/*` → HTTP 403 body `error code: 1010` (Cloudflare bans the `Python-urllib/3.x` UA signature). curl works; Node fetch works.
- **Fix: set a custom `User-Agent` header on the Request** (e.g. `agentmemory-hermes-plugin/1.0`) — local Python then works through the tunnel; no need to hop to VM localhost.

## Codex provider auth gotcha (found while testing)

- `[model_providers.9router] api_key = "..."` does NOT send auth (requests still 401). Correct wiring: `requires_openai_auth = true` + put the key as `OPENAI_API_KEY` in `~/.codex/auth.json` (chmod 600).
- Stale `base_url = "http://127.0.0.1:20128/v1"` (from when 9router ran locally) breaks codex after the gateway moved to the VM → use `https://router.luukhoahoc.me/v1`. 9router requires Bearer for remote access and supports `/v1/responses` (SSE).
- `codex mcp list` shows registered servers (useful sanity check). On first `codex exec` ask, the agent may claim the tools are missing — re-ask specifically "list tools of server agentmemory" before concluding the server is broken.
- opencode provider: `apiKey: "{env:9ROUTER_API_KEY}"` interpolation works in provider options.

## Headless MCP bridge test

Pipe JSON-RPC lines into the bridge and parse stdout:

```bash
printf '%s\n' \
'{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}' \
'{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
'{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"memory_recall","arguments":{"query":"9router","limit":2}}}' \
| timeout 60 ~/.local/bin/agentmemory-mcp 2>&1 | python3 -c 'import sys,json
for l in sys.stdin:
    try: d=json.loads(l)
    except: continue
    if d.get("id")==3: print(d["result"]["content"][0]["text"])'
```

Keep `2>&1` on the first run — a process killed by `timeout` can lose buffered stdout, and the first failure looked like "empty output" until stderr was shown.
