# Zed Token Optimization — Session Detail (2026-08-03)

## The 75k-input "ping" diagnosis

Symptom: bare "ping" → "pong" in Zed Agent panel showed `Input: 75k / 224k`, `Rules: 1 global + 1 project`.

Root cause: Zed serializes tool schemas of EVERY enabled `context_servers` entry into the agent request. 8 servers were enabled:

| Server | Tools | ≈ Tokens |
|---|---|---|
| mcp-server-gitlab | 115 | 35–40k |
| chrome-devtools-mcp-zed | ~30 | ~10k |
| mcp-server-notion | ~14 | ~5k |
| mcp-server-figma | ~10 | ~3.5k |
| mcp-server-sonarqube | ~10 | ~3.5k |
| mcp-server-markitdown | 5 | ~1.5k |
| agentmemory | ~4 | ~1.2k |
| mcp-server-context7 | 2 | ~0.6k |

Plus system prompt (~6k) + AGENTS.md (global 3KB + repo root 16KB ≈ 6k) + workspace context → 75k.

Action taken: disabled 5 servers (`enabled: false`) → ~20k saved. Then agent profiles (below) cut the gitlab/notion cost for the coding profile → baseline ~20k.

## Working agent profiles (native Zed Agent)

Two-profile setup the user chose:
- **write-code** ("Write Code"): `enable_all_context_servers: false`, only `mcp-server-context7` (resolve-library-id, query-docs). Default profile.
- **gitlab-ops** ("GitLab Ops"): `enable_all_context_servers: false`, only `mcp-server-gitlab` with ALL 115 tools whitelisted (review MR, create tickets), built-in tools read/terminal/search/fetch enabled, `default_model` opencode/free/minimax-m2.5-free.

Notes:
- Profile tool maps are per-tool; no wildcard. 115 gitlab tool names were transcribed from the MCP catalog (snake_case).
- `agent.profiles` do NOT apply to external ACP agents (docs: "Zed Agent profiles — Do not apply unless the integration says otherwise") nor terminal threads.
- Built-in profile ids: `write`, `ask`, `minimal`; `agent.default_profile` picks the default.
- Per-tool permission keys use `mcp:<server>:<tool>` format.

## Editing Zed settings.json — JSONC

File characteristics: `//` header comments + trailing commas on nearly every object (`"enabled": true,` then `}`). Strict `json.loads` fails at the FIRST trailing comma — the "invalid" result is pre-existing, not caused by the edit. Always diff-validate against a pre-edit backup (`settings.json.bak.<ts>`).

Validation recipe:
```python
def tolerant(s):
    s = '\n'.join(l for l in s.splitlines() if not l.lstrip().startswith('//'))
    s = re.sub(r',(\s*[}\]])', r'\1', s)
    return json.loads(s)
```

Regex traps hit in practice:
1. Replacement ending in `,` while the matched text's trailing `,` stayed → `"context_servers": {},,` (double comma).
2. Match pattern included the closing `},` of the previous object → parent object left unclosed (debug profile lost its `}`), JSON silently broken until the next object.
3. Python 3.11 f-strings: backslash forbidden inside `{...}` expressions — hoist the regex out of the f-string.

## 9router local proxy (openai_compatible provider)

- `api_url: http://localhost:20128/v1`; `GET /v1/models` lists combo models (zed-custom, opencode-premium, hermes-agent-combo...) WITHOUT capabilities — metadata lives in Zed `available_models`.
- Model `zed-custom`: `max_tokens: 256000`, `max_output_tokens: 32000`, `max_completion_tokens: 200000`, reasoning_effort max, capabilities: tools/images/parallel_tool_calls/prompt_cache_key.
- Panel "224k" = 256k − 32k output reserve. Prompt cache keyed on prefix → keep baseline stable (don't switch profiles mid-thread) to preserve cache hits.

## Zed agent vs other agents on token injection

| Tool | Behavior |
|---|---|
| Zed Agent (native) | Injects ALL enabled context server tools (no lazy loading) |
| External agent via ACP in Zed | Zed MAY forward MCP servers over ACP → same cost |
| Hermes / Claude Code standalone | Lazy/deferred tool loading — only name+short desc in catalog, full schema on use |
| Terminal threads | CLI reads its own MCP config; no Zed injection |
