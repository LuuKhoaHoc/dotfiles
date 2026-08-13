---
name: supermemory-ops
description: Store/verify/clean supermemory cross-agent memory.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [supermemory, memory, mcp, cross-agent, containers]
    related_skills: [agent-memory, agent-memory-setup, mcp-config]
---

# Supermemory Ops

## When to Use

- Storing a fact/rule into supermemory so other harnesses (omp, opencode, antigravity, codex, Zed) read it the same way Hermes does.
- Verifying what supermemory's LLM summarizer produced from a stored note (summary must not invert the raw meaning).
- Cleaning corrupted or inverted entries (flood text, dropped negation) and deleting notes vs memory entries.

## Architecture (this user, verified 2026-08-12)

- **Isolation unit = `containerTag`** (API) — app UI calls it `project` (`?project=hermes`). Data is per-container; agents only see their container.
- **Bridge MCP** `~/.local/bin/supermemory-mcp`: `CONTAINER_TAG = $SUPERMEMORY_CONTAINER_TAG || "hermes"`; tools `add_memory`, `listMemories`, `whoAmI` all accept a `containerTag` override. API key in `~/.hermes/.env` (`SUPERMEMORY_API_KEY`).
- **opencode plugin** `~/.config/opencode/supermemory.jsonc`: `userContainerTag: "hermes"`, `injectProfile: true`.
- **Hermes**: `memory.provider: supermemory` in `config.yaml`; `supermemory_store/search/forget/profile` tools available in-session.
- **Two data kinds — do not confuse them:**
  - **Documents (notes)**: the raw content you store. App shows them under `categories=notes`; `doc=<id>` in URL = document ID.
  - **Memories**: LLM-generated summaries/extractions derived from documents. **This is what agents' semantic search actually returns** — raw notes are NOT searched directly. A correct raw note with a wrong summary still misleads agents.

## CRITICAL: LLM summarizer inverts Vietnamese negation

Verified 2026-08-12: raw note *"Giao tiếp với user: tiếng Việt, CẤM xưng 'mày/tao'..."* was summarized by supermemory's backend LLM as *"using informal pronouns like 'mày/tao'"* — the negation **CẤM** was dropped, inverting the meaning. Same happened to *"dotfiles PUBLIC — CẤM lưu secret"* → *"stores secrets in the public dotfiles repo"* (dangerous!).

**Rule — always store in English with explicit, sentence-initial negation:**
- `FORBIDDEN: never address the user as "mày" or "tao"` (not: cấm xưng...)
- `SECURITY RULE (critical): NEVER store secrets, API keys, tokens, or passwords in ...`
- `DO NOT ...` / `NOT afraid of ...` at phrase start.
- Keep positive allowed-alternatives explicit (`ALLOWED: ... 'ní', 'sốp', 'bạn'`).

## Workflow

1. **Store** via `supermemory_store` (English, LLM-proof phrasing; pass metadata tags).
2. **Wait for dreaming**: document `status` goes `done` quickly, but `dreamingStatus` stays `dreaming` while the summarizer runs (~2 min). Check `GET /v3/documents/{id}` → fields `summary`, `dreamingStatus`, `title`, `content`.
3. **Verify the summary is faithful** (read `summary` field) — do not assume it matches raw. Re-store with stronger phrasing if inverted/truncated.
4. **Verify search index**: `supermemory_search` with a distinctive phrase — new result IDs with high similarity mean agents will find it.
5. **Clean corrupted entries** by EXACT ID (`supermemory_forget id=...`) — never query-delete, it may hit a correct sibling entry (verified: correct "CẤM mày/tao" and wrong "using mày/tao" entries coexisted; query matched both).

## Delete endpoints (verified)

| Target | Endpoint | Notes |
|---|---|---|
| Document/note (raw) | `DELETE /v3/documents/{id}` | HTTP 204. **v4 endpoint does NOT work for docs** — `DELETE /v4/memories` returns `Memory not found` for document IDs. |
| Memory entry (summary) | `DELETE /v4/memories` body `{"id","containerTag"}` → `{forgotten:true}` | Or `supermemory_forget` by ID. |
| List documents | `POST /v3/documents/list` body `{"containerTags":["hermes"],"limit":N}` | Response key is `memories` (docs with `documentId`, `title`). |
| List memories | `POST /v4/memories/list` body `{"containerTags":[...],"includeContent":true}` | Returns `memoryEntries` = the summaries. |

## Pitfalls

- **Search results with empty `content`** are still valid hits (documents or processing entries) — judge by ID presence + similarity, then fetch the document for the summary.
- **Deleting a wrong summary removes the fact from search entirely** — raw note remains but is invisible to agents. Fix by re-storing a correct English version, not just deleting.
- **Corrupted entries** seen: flood text (one word repeated thousands of times, sometimes with stray `{'x':'y'}`), truncated mid-sentence merges, and inverted-negation summaries. They come from the auto-capture/summarize pipeline.
- App `project=sm_project_default` is the default project, NOT where configured agents write — config uses container tag `hermes`.

## References

- `references/supermemory-api-and-pitfalls.md` — API endpoints, response shapes, and the 2026-08-12 corruption case study.
- `scripts/sm-doc-status.sh` — check dreaming status + summary for stored document IDs.
