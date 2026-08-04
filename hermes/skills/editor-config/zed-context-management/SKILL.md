---
name: zed-context-management
description: Use when Zed agent input is bloated by MCP tools.
triggers:
  - "zed agent input tokens high"
  - "zed ping 75k input"
  - "zed mcp tools in context"
  - "zed agent profiles"
  - "zed settings.json edit"
  - "zed context window"
category: editor-config
---

# Zed Context & Token Management

## MCP Token Bloat (root cause, verified 2026-08)

**Zed serializes tool schemas of ALL enabled `context_servers` into the agent's context — no lazy loading.** A bare "ping" with 8 MCP servers enabled cost **75k input tokens**. Hermes/Claude Code outside Zed don't suffer this (lazy tool loading), but any agent run inside Zed (built-in OR external via ACP) receives the forwarded MCP tools.

Cost scale: ~190 tools × ~300 tok/schema ≈ 55-60k. Biggest offenders: gitlab MCP (115 tools ≈ 35-40k), chrome-devtools (~30 ≈ 10k), notion (~14 ≈ 5k), figma/sonarqube (~10 ≈ 3.5k each).

## Fixes (apply both)

1. **Disable unused servers** in `context_servers`: `"<name>": {"enabled": false}`
2. **Agent profiles** — the proper whitelist, NATIVE Zed Agent only (external ACP agents + terminal threads ignore profiles):
```json
"agent": {
  "default_profile": "write-code",
  "profiles": {
    "write-code": {
      "name": "Write Code",
      "enable_all_context_servers": false,
      "context_servers": {
        "mcp-server-context7": { "tools": { "resolve-library-id": true, "query-docs": true } }
      }
    }
  }
}
```
- No wildcard — enumerate tools: `"tools": {"<tool_name>": true}`
- Tool names keep server-native casing: context7 = kebab-case (`resolve-library-id`), gitlab MCP = snake_case (`search_repositories`, `update_merge_request`)
- Profiles can also toggle built-in tools and set `default_model` per profile

## Token budgets (256k window config, 32k output)

- Baseline after cleanup ≈ 20k: system 3-5k + 17 built-in tools 5-7k + AGENTS.md 5-6k + workspace 2-4k
- Usable input = `max_tokens` − `max_output_tokens` (e.g. 256k − 32k = 224k shown in panel)
- Healthy 20-40k; warn >100k (history bloat); **reset thread >150k** (~2/3 window)
- `prompt_cache_key: true` (9router/DeepSeek-style) caches the baseline between turns — changing profile mid-thread busts the cache

## Editing Zed settings.json (JSONC traps)

settings.json is JSONC: `//` comments + **trailing commas everywhere** → strict `json.loads` fails at the FIRST trailing comma ("Expecting property name..."). Do NOT conclude the edit broke the file — check against a pre-edit backup first.

Validation recipe (strip comments → strip trailing commas → parse):
```python
def tolerant(s):
    s = '\n'.join(l for l in s.splitlines() if not l.lstrip().startswith('//'))
    s = re.sub(r',(\s*[}\]])', r'\1', s)
    return s
```
Regex-edit traps (both happened in practice):
- Replacement ending with `,` + original trailing `,` → double comma (`{},,`) — always check the join point
- Match pattern consuming a closing `},` line → unclosed parent object (silently valid-looking, breaks JSON)
- Python <3.12: no backslash inside f-string expressions
- Always `cp settings.json settings.json.bak.<ts>` before editing

## Global AGENTS.md rules (this user's machine, 2026-08)

`~/.config/zed/AGENTS.md` = generic rules for ALL projects; per-repo AGENTS.md adds on top. User preferences:
- **RTK CLI proxy** for commands (`rtk git/glab/pnpm/ls/read/diff/test/err/json/log`; rtk 0.43.0 at ~/.local/bin/rtk) — fallback raw command if rtk fails, report once
- **Caveman Lite** communication for the Zed agent only (Hermes stays normal/verbose)
- **Resolution Ladder** (YAGNI → reuse → stdlib → native → deps → minimal) with pattern-first override (never blocks SRP/composition refactors) + hotfix exception
- **NO project context (company or personal) in the global file** — user correction; project context belongs in each repo's AGENTS.md

## References

- `references/zed-token-optimization.md` — full 75k diagnosis breakdown, working profile JSON (write-code + gitlab-ops with all 115 tools), 9router findings
