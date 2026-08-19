---
name: agent-memory
description: "Use when choosing or setting up agent memory (Mem0, Zep...)."
version: 1.0.0
---

# Agent Memory for AI Tools

Choose, evaluate, and integrate persistent memory layers across AI coding tools (Hermes, Claude Code, Cursor, OpenCode...). Use when the user wants tools to "remember" across sessions/apps, or asks which agent memory is most recommended.

## Step 0 — Check what you already have
Hermes ships: memory (user profile + notes), skills (procedural memory), session_search (FTS5 over past sessions). For a single-agent setup this may be enough — say so before selling an external layer. External memory only wins when: (a) multiple tools need SHARED memory, (b) memory volume exceeds the compact memory file, (c) user explicitly wants cross-tool portability.

## Step 1 — Audit environment (print key NAMES only, never values)
```bash
grep -oE "^[A-Z_]+=" ~/.hermes/.env          # available API keys
docker --version && docker compose version
ss -tlnp | grep -E "8080|8765|3000|11434"    # ports already in use
```
Memory MCP servers need an LLM key for extraction. No OpenAI/Anthropic key → setup stalls; look for OpenAI-compatible endpoints (existing provider key + base_url) before promising anything.

## Step 2 — Verify repo health BEFORE recommending
```bash
curl -s https://api.github.com/repos/<org>/<repo> | jq .stargazers_count,.updated_at,.description
curl -s https://api.github.com/repos/<org>/<repo>/contents/<path>   # 404 = moved/repurposed
```
Brand-new blog-launched products can be repurposed within weeks (see OpenMemory pitfall). Check stars + last update + documented path actually exists.

## Step 3 — Decision table (checked 2026-08)
| Option | Type | Cost | Best for |
|---|---|---|---|
| Hermes built-in memory/skills/session_search | built-in | free | single agent |
| Mem0 (mem0ai/mem0, ~63K★) + mem0-mcp (658★) | MCP + Docker, vector+graph | self-host free; cloud free→$19→$249/mo | most adopted, fastest drop-in, cross-tool MCP |
| Zep / Graphiti (~26K★) | temporal knowledge graph | OSS self-host; Zep cloud paid | changing facts, provenance, time-aware recall |
| Letta (~23K★) | stateful agent runtime | OSS self-host (postgres+pgvector) | agents managing their own memory blocks |
| Cognee (~17.6K★) | graph memory control plane | OSS free; platform €8.50/1M tokens | org/shared memory, audit trails |
| ReMe (~3K★) | file-based (markdown + BM25/vector) | free | transparent, hand-editable memory, no Docker |
| OpenMemory MCP | local MCP server + UI | free (needs LLM key) | ⚠️ UNRELIABLE — see pitfalls |

## Step 4 — Integrate via MCP into Hermes
`~/.hermes/config.yaml` → `mcp_servers` (stdio: `command`/`args`/`env` | HTTP: `url`/`headers`). MCP subprocess env is FILTERED (only PATH/HOME/XDG_* + explicit `env:`) — pass keys explicitly via `env:`. Tools auto-register as `mcp_<server>_<tool>` after agent restart. Never put secrets in SKILL.md/docs.

## Pitfalls
- **OpenMemory MCP (mem0)**: launched 2026-07-31 as local memory layer; by 2026-08-09 the repo path was dead (mem0ai/mem0/tree/main/openmemory → 404) and mem0ai/openmemory had become a session-porting CLI. Verify before building on brand-new products.
- **Supermemory (verified 2026-08, khoahoc):** Hermes memory provider chính thức (`memory.provider: supermemory`, cần `pip install supermemory` vào venv Hermes + key `sm_*` vào `~/.hermes/.env`). OpenCode dùng plugin chính thức `opencode-supermemory` (`bunx opencode-supermemory@latest install --no-tui`; config `~/.config/opencode/supermemory.jsonc` với `apiKey` + `userContainerTag`). **KHÔNG dùng MCP remote `https://mcp.supermemory.ai/mcp`** — OAuth của họ lỗi `offline scope invalid` với client yêu cầu `offline_access` (opencode, có thể Zed). Chia sẻ container: Hermes `container_tag` default `hermes`; plugin opencode viết theo project (`repo_{name}__{hash}`), đọc profile từ `userContainerTag` — muốn 2 chiều đầy đủ thì set `projectContainerTag: "hermes"`. Free cloud ~$5 usage/tháng; self-host `npx supermemory local` free vô hạn (cả provider lẫn plugin đều hỗ trợ `base_url`).
- **Supermemory summary ≠ raw — lưu tiếng Anh LLM-proof (verified 2026-08-12, khoahoc):** Supermemory tự sinh `summary` bằng LLM từ nội dung bạn lưu; **search/profile của agent dùng summary, KHÔNG dùng raw**. LLM tóm tắt tiếng Việt dễ **đảo nghĩa câu phủ định**: raw "CẤM xưng 'mày/tao'" → summary "using informal pronouns like 'mày/tao'" (ngược hẳn!); "dotfiles PUBLIC — CẤM lưu secret" → "stores secrets in the public dotfiles" (nguy hiểm). **Rule: lưu memory lên supermemory bằng TIẾNG ANH với phủ định tường minh đầu câu** — `FORBIDDEN: never...`, `NEVER...`, `DO NOT...` in hoa — LLM khó đảo nghĩa hơn nhiều. Xóa summary sai ≠ xóa được fact: raw note vẫn còn nhưng search không đọc nó → fact "mất" khỏi agent. Sau khi lưu, chờ `dreamingStatus` hết `dreaming` (~1-2 phút) rồi GET `/v3/documents/{id}` verify `summary` đúng nghĩa.
- **Xóa note/document supermemory (verified 2026-08-12):** `DELETE /v4/memories` chỉ xóa memory entry (body `{id, containerTag}`), **không xóa document/note** ("Memory not found" với doc id). Document xóa qua **`DELETE /v3/documents/{id}`** (HTTP 204). Các endpoint v4 documents/notes đều 404. `POST /v4/memories` tạo 1 document chứa N memories — id trả về từ store là **document id**, còn id trong `/v4/memories/list` là **memory id** — không trùng nhau, đừng nhầm khi xóa.
- **agentmemory package identity (verified 2026-08-13, khoahoc):** server/CLI package = `@agentmemory/agentmemory` (bin `agentmemory`, engines node ≥20) — bare npm name `agentmemory` is 404. `@agentmemory/mcp` is a thin stdio shim that only talks to a LOCAL engine (127.0.0.1:3111) — for a remote/VM engine, write a small stdio MCP bridge over REST (pattern below). Single-file local data at `~/.agentmemory/standalone.json`; server port 3111 (viewer 3113); client env `AGENTMEMORY_URL` (+`AGENTMEMORY_SECRET`). Deployment playbook: skill `selfhost-vm-deploy`.
- **agentmemory remote/VM pitfalls (verified 2026-08-15, khoahoc):** REST `/agentmemory/sessions` is **GET** (POST → 405); `/remember` needs `concepts`/`files` as **arrays**; `/forget` needs singular `memoryId`; `/observe` requires hookType/sessionId/project/cwd/timestamp. Behind a Cloudflare tunnel, **Python-urllib default UA is blocked (error 1010)** — always send an explicit `User-Agent` (bit the Hermes provider twice). Hermes: use the OFFICIAL plugin (repo `integrations/hermes/` → `~/.hermes/plugins/agentmemory`, env `AGENTMEMORY_URL`/`AGENTMEMORY_SECRET`, preloads `~/.agentmemory/.env`) — re-patch its `_api()` UA after every plugin update; delete any hand-rolled fork first (only one provider named `agentmemory` may register). Author ships **17 official skills** (repo `plugin/skills/` → `~/.hermes/skills/agentmemory/`); key one is `memory-discipline`: search before work, save decisions immediately WITH reason + concepts + file paths, corrections become lessons, session end = stop (hooks own the summary). Full REST contract + per-harness MCP config formats (Zed `command`/`args`/`env` — wrong format is silently ignored with no log line; codex needs `~/.codex/auth.json` + `requires_openai_auth=true`, not an `api_key` field): `references/agentmemory-ops.md`.
- **Self-reported benchmarks are contested**: Mem0 claims 92.5 LoCoMo but independent eval scores 49.0% LongMemEval (arxiv 2603.04814); competitors dispute each other's numbers.
- **No LLM key = no memory extraction**: this user (2026-08) has only OPENCODE_GO_API_KEY; no OpenAI/Anthropic/Gemini key. Confirm key availability first or offer an OpenAI-compatible endpoint.
- **Managed tiers jump fast**: Mem0 free → $19 → $249/mo (graph features Pro-only). Quote pricing honestly.
- Local/OSS memory = free except your own LLM API usage; managed clouds have free tiers then pay.

## Reference
- `references/landscape-2026-08.md` — full research notes: benchmarks, stars, pricing, OpenMemory MCP + mem0-mcp deployment commands, this user's constraints.
- `references/agentmemory-ops.md` — agentmemory operational playbook: verified REST contract (endpoints/methods/payloads), Cloudflare UA 1010 trap, Hermes official plugin install + UA patch, 17 official skills, per-harness MCP config formats (Zed/opencode/codex/omp/gemini), Azure VM start POST trap.
