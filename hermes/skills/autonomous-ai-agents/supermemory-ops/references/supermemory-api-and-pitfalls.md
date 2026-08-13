# Supermemory API endpoints & corruption case study (2026-08-12)

## Verified endpoints (supermemory@4.25.4, REST API, api.supermemory.ai)

Auth: `Authorization: Bearer $SUPERMEMORY_API_KEY` (key in `~/.hermes/.env`), header `x-sm-source: <source>`.

| Purpose | Call | Response shape |
|---|---|---|
| Store memory/note | `POST /v4/memories` (via `supermemory_store` / bridge `add_memory`) | `{ documentId, memories: [{ id, memory, ... }] }` — the returned `id` is the **document** id shown as `doc=` in the app |
| List memory entries (summaries) | `POST /v4/memories/list` body `{"containerTags":["hermes"],"limit":N,"includeContent":true}` | `{ memoryEntries: [{ id, memory, createdAt }] }` — these are LLM summaries, NOT raw |
| Forget a memory entry | `DELETE /v4/memories` body `{"id","containerTag"}` | `{ forgotten: true }` |
| Get document detail (raw + summary) | `GET /v3/documents/{id}` | fields: `content` (raw), `summary` (LLM), `title`, `status` (`done`), `dreamingStatus` (`dreaming` while summarizer runs), `metadata`, `containerTags` |
| **Delete a document/note** | `DELETE /v3/documents/{id}` | HTTP 204 |
| List documents | `POST /v3/documents/list` body `{"containerTags":["hermes"],"limit":N}` | `{ memories: [ { documentId, title, ... } ] }` — note the misleading key name |

**Key gotcha:** `DELETE /v4/memories` with a *document* id returns `{"error":"Memory not found"}`. Documents are deleted via **v3** only.

## Timeline of a store → summary

1. `supermemory_store` returns document id immediately.
2. `status` → `done` quickly; `dreamingStatus` stays `dreaming` while backend LLM builds `title` + `summary` (~1–3 min).
3. Only after dreaming completes does the summary appear in semantic search. Poll `GET /v3/documents/{id}` until `dreamingStatus` changes, then read `summary`.
4. Semantic search may return entries with **empty `content`** — these are valid hits (documents/processing); fetch the doc to read the summary.

## Corruption case study (2026-08-12)

Symptoms found in container `hermes`:

1. **Flood text**: one word repeated thousands of times (`mandatory mandatory mandatory ...`, sometimes ending with a stray `{'x': 'y'}`) — 2 entries.
2. **Inverted negation**: Vietnamese raw `CẤM xưng 'mày/tao'` → English summary *"using informal pronouns like 'mày/tao'"*; `CẤM lưu secret` → *"stores secrets in the public dotfiles repo"*. Both came from the auto-summarizer dropping mid-sentence negation.
3. **Truncated merge**: an entry that started correctly then exploded into flood text mid-sentence.

Cleanup procedure that worked:
- Find corrupted entries via `supermemory_search` (query distinctive fragments) → get exact IDs.
- Delete by ID (`supermemory_forget id=...`), NEVER by query text — a query can match the correct sibling entry (the correct "CẤM mày/tao" note and the wrong "using mày/tao" summary coexisted; a query-delete would have hit both).
- Re-store the fact in **English with sentence-initial negation** (`FORBIDDEN: never ...`, `NEVER ...`), then verify the new summary reads correctly.

## Container/project model

- API isolation = `containerTag`; app UI = `project` (`?project=<tag>`). `sm_project_default` is the default project, not where configured agents write.
- Bridge MCP container: `SUPERMEMORY_CONTAINER_TAG` env or `"hermes"` default; opencode plugin: `userContainerTag` in `~/.config/opencode/supermemory.jsonc`; Hermes: `memory.provider: supermemory` + its own container wiring.
- Per-container profile: `GET /v4/profile` (or SDK `profile({containerTag})`) returns `profile.static` + `profile.dynamic` — dynamic = derived from memories.
