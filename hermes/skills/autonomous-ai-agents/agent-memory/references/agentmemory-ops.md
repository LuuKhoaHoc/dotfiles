# Agentmemory (self-hosted) — operational playbook

Verified 2026-08-15 on khoahoc's setup: agentmemory server on Azure VM 9router-vm,
exposed via cloudflared tunnel as `mem.luukhoahoc.me`, Bearer `AGENTMEMORY_SECRET`.

## Architecture (multi-machine cross-agent setup)

```
harness (local)  --MCP stdio-->  agentmemory-mcp bridge  --HTTPS REST-->  mem.luukhoahoc.me/agentmemory/*
                                      ^ reads AGENTMEMORY_SECRET from env,
                                      | fallback: ~/.agentmemory-bridge.env
```

- Official MCP shim `agentmemory mcp` / `npx @agentmemory/mcp` is **stdio-only and talks
  to a LOCAL engine (127.0.0.1:3111)** — useless for remote engines. For remote use,
  write a tiny stdio bridge calling REST (pattern proven by supermemory-mcp and
  agentmemory-mcp: McpServer + StdioServerTransport + fetch/urllib).
- Bridge at `~/.local/bin/agentmemory-mcp` (source `~/.local/share/agentmemory-mcp/`,
  needs `"type": "module"` in package.json or ESM import fails with SyntaxError).
- Tool names mirror official shim: `memory_recall`, `memory_save`, `memory_sessions`,
  `memory_smart_search`, `memory_export`, `memory_audit`, `memory_governance_delete`.
- Server identity: package `@agentmemory/agentmemory` (npm bare name `agentmemory` is 404);
  ports 3111 REST / 3113 viewer; `AGENTMEMORY_TOOLS=core|all` (8 vs 54 tools);
  config in `~/.agentmemory/.env`; data via `--data-dir` / `AGENTMEMORY_DATA_DIR`.

## REST contract (verified against server 0.9.28, worker 0.11.2)

Base `https://mem.luukhoahoc.me/agentmemory` (or `http://127.0.0.1:3111/agentmemory`).
Auth: `Authorization: Bearer AGENTMEMORY_SECRET` (env var name in `~/.agentmemory/.env`).

| Method | Path | Payload / notes |
|---|---|---|
| GET | `/health` | always public; status/workers/version |
| POST | `/search` | `{query, limit, format}` — format `full` → `results[].observation{facts[],narrative,title,type,id,timestamp}`; `compact` → `results[]{obsId,title,score}` |
| POST | `/remember` | `{content, type?, concepts?, files?, project?}` — **concepts/files MUST be arrays** (string → `{"error":"concepts must be an array"}`) → `{memory:{id,...}}` |
| GET | `/sessions` | **GET, not POST** — POST → 405. → `{sessions:[{id,project,cwd,status,...}]}` |
| POST | `/smart-search` | `{query, expandIds?, limit?}` |
| GET | `/profile` | GET (POST also worked but official docs say GET) → `{profile, search_results}` — no persistent profile entity; use search results |
| POST | `/forget` | `{memoryId, reason?}` (singular memoryId; plural memoryIds → error "sessionId or memoryId is required") → `{deleted:1}` |
| POST | `/observe` | requires `hookType, sessionId, project, cwd, timestamp` (all strings) + `messages` → `{observationId}` |
| POST | `/session/start`, `/session/end` | `{sessionId, project?, cwd?}` — used by official Hermes plugin |
| POST | `/context` | `{sessionId, project}` → `{context}` (session-start injection) |
| GET | `/export` | full JSON dump |
| POST | `/import` | JSON restore |
| GET | `/audit` | `{operation?, limit?}` |
| GET | `/health` | also `{circuitBreaker, functionMetrics}` |

130 endpoints total; full list in repo `src/triggers/api.ts`. Mesh-sync endpoints require
AGENTMEMORY_SECRET on both peers (mesh is for internal coordination, NOT cross-machine
replication of two independent instances — do not rely on it for 2-way sync).

## Cloudflare UA trap (error 1010) — hit TWICE, always check first

`mem.luukhoahoc.me` sits behind Cloudflare (cloudflared tunnel). Cloudflare rejects the
default `Python-urllib/3.x` User-Agent with HTTP 403 + body `error code: 1010`.
Symptom: REST calls fail ONLY from Python stdlib clients; curl and Node fetch work.
**Fix: always send an explicit `User-Agent` header** (e.g. `agentmemory-hermes-plugin/1.0`).
This bit both the Hermes provider fork AND the official plugin (`integrations/hermes`
uses urllib without UA — patch `_api()` in `~/.hermes/plugins/agentmemory/__init__.py`
after every plugin update).

## Hermes integration

- Official plugin: copy repo `integrations/hermes/` → `~/.hermes/plugins/agentmemory`
  (NOT into hermes-agent source tree — that gets wiped on update).
- Env: `AGENTMEMORY_URL` (default http://localhost:3111), `AGENTMEMORY_SECRET`,
  `AGENTMEMORY_REQUIRE_HTTPS=1` refuses plaintext bearer to non-loopback hosts.
- Plugin preloads `~/.agentmemory/.env` at import (fills missing env only) — create that
  file locally (chmod 600) even when server is remote.
- 6 hooks: prefetch (smart-search), sync_turn (observe), on_session_end (session/end),
  on_pre_compress (context re-inject), on_memory_write (remember), system_prompt_block (context).
- `config.yaml` → `memory.provider: agentmemory`. Only ONE provider with that name may be
  registered — delete any hand-rolled fork before installing the official plugin.
- Do NOT also wire the 54-tool MCP server (`npx @agentmemory/mcp`) for Hermes — it needs a
  local engine; the provider plugin is the right surface.

## 17 official skills (best practices shipped by the author)

Repo `plugin/skills/<name>/SKILL.md` → `~/.hermes/skills/agentmemory/<name>/SKILL.md`
(also `_shared/TROUBLESHOOTING.md`). Install: `npx skills add rohitg00/agentmemory -y`
or copy the dirs. Key skill: **`memory-discipline`** — the core loop:
1. Task start → `memory_smart_search` (topic + project) BEFORE reading code.
2. Decision settles → `memory_save` immediately WITH reason + 2–5 concepts + real file paths
   (batch-save at session end loses the reasons).
3. User correction → save a `lesson`, not a memory (lessons carry confidence).
4. Before repeating a corrected task type → `memory_lesson_recall`.
5. Session end → stop; hooks own summarization (manual recap duplicates).
Anti-pattern: finish work, then search to double-check + batch-save summary.

## Harness MCP config formats (each client differs — verified working)

- **Zed** (`settings.json` → `context_servers`): current format is
  `{"command": "/path/to/bridge", "args": [], "env": {"AGENTMEMORY_SECRET": "..."}}`.
  `command` is a STRING, env key is `env` (NOT `environment`), no `type` field.
  Wrong format (type/environment/array-command) → server **silently ignored**: no spawn,
  NO log line, tools simply absent. Debug via `~/.local/share/zed/logs/Zed.log`.
  Per-profile tool allowlist: `agent.profiles.<name>.context_servers.<server>.tools.{memory_recall:true,...}`.
  CAUTION: the Zed agent can rewrite settings.json itself (it "helped" and wrote an
  invalid `{"settings": {...}}` entry) — re-verify the entry after any agent session.
- **OpenCode** (`opencode.json`): `"mcp": {"agentmemory": {"type": "local",
  "command": ["/path/bridge"], "environment": {"AGENTMEMORY_SECRET": "..."}, "enabled": true}}`.
  Drop the `opencode-supermemory` plugin when migrating.
- **Codex** (`config.toml`): `[mcp_servers.agentmemory] command = "/path/bridge"`
  `env = { AGENTMEMORY_SECRET = "..." }`. Also: provider keys go in `~/.codex/auth.json`
  (`{"OPENAI_API_KEY": "..."}`) with `requires_openai_auth = true` — `api_key` field in
  config.toml is NOT sent. Codex config may still point at `127.0.0.1:20128` from the era
  when 9router ran locally — check `base_url` when 9router moved to a VM.
- **omp / gemini / antigravity** (mcpServers JSON): `{"type": "stdio", "command": "<path>",
  "env": {"AGENTMEMORY_SECRET": "..."}}`. agy (antigravity-cli) reads the same
  `~/.gemini/config/mcp_config.json`.
- **Hermes** memory provider: see above (official plugin).

## VM start trap (Azure / GH Actions)

Azure `POST /virtualMachines/{id}/start` — the script must use POST; GET → **405**.
Classic trap: workflow_dispatch "success" runs only exercised the already-running branch,
so the start path was never tested until the VM was actually deallocated at run time.
When adding a VM-start script, force-test with the VM deallocated (or add a dry-run that
hits instanceView and confirms state). VM auto-shutdown ~0h + GH Action schedule 9h ICT
(`0 2 * * *` UTC) + systemd-enabled services on the VM = self-healing boot loop.
