# Agent Memory Landscape — Research Notes (2026-08)

Snapshot captured 2026-08-11 from web research. **Re-verify before trusting** — this space moves fast (see OpenMemory MCP case below).

## OpenMemory MCP cautionary tale (verified 2026-08-11)

- 2026-07-31: mem0 blog "Introducing OpenMemory MCP" — local-first memory MCP server, Docker stack (Postgres + Qdrant + FastAPI), dashboard at :3000, MCP at `http://localhost:8765/mcp/<client>/sse/<user>`.
- 2026-08-11 (this session): `github.com/mem0ai/mem0/tree/main/openmemory` → **404**; `mem0ai/openmemory` repo now a **session-porting CLI/TUI** (Claude Code ↔ Codex ↔ OpenCode), 29★; folder gone from mem0 main branch.
- Lesson: a product can pivot/repurpose within 1.5 weeks of launch. Always check repo existence + description + updated_at before recommending/setup.

## Benchmarks (vendor-reported — treat as marketing)

| System | LoCoMo | LongMemEval | Notes |
|---|---|---|---|
| Mem0 (self-reported) | 91.6 | 94.8 | Independent eval (arxiv 2603.04814): 49.0 LongMemEval — disputed |
| Zep (cloud) | 94.7 | 90.2 | <200ms retrieval, SOC2/HIPAA |
| Graphiti (OSS) | — | 63.8 (GPT-4o) | Temporal validity windows, provenance |
| Evermind EverOS | 93.05 | 83.00 | New entrant, ~6.7K★, claims #1 BEAM |

BEAM / LoCoMo / LongMemEval = the 2026 standard benchmarks.

## Option details

### Mem0 (`mem0ai/mem0`, ~63K★)
- Dual-store: vector (Qdrant/Chroma/Milvus/pgvector/Redis) + knowledge graph (Pro tier).
- Pricing: free → $19/mo → $249/mo (graph = Pro).
- Needs LLM API key for extraction (OPENAI_API_KEY etc.) + optional MEM0_API_KEY for cloud.
- MCP server: `mem0ai/mem0-mcp` (Docker HTTP :8081, needs MEM0_API_KEY).
- Verified on this machine: no OpenAI/Anthropic key in ~/.hermes/.env → cloud path blocked without signup.

### Zep / Graphiti (`getzep/graphiti`, ~26K★)
- Temporal knowledge graph: facts get validity windows, invalidation on change — best for "what changed" questions.
- Zep cloud: managed platform; Graphiti: OSS engine, self-host.
- SDKs: Python/TS/Go. Needs LLM key for extraction.

### Letta (MemGPT, ~23K★)
- Stateful agent platform — memory is part of agent runtime (memory blocks, archival), not a passive store.
- Self-host needs Postgres + pgvector; has MCP server (useful for coding agents).

### Cognee (~17K★)
- remember/recall/forget/improve API, local execution, graph+vector.
- Platform pricing: €8.50/1M input tokens; on-prem €1,970/mo.

### ReMe (~3K★)
- File-based: memory = readable/editable markdown-ish files + vector/BM25 hybrid search.
- Best for transparency + portability; no Docker.

### `@modelcontextprotocol/server-memory` (official MCP, chosen for this user)
- Knowledge graph (entities/relations/observations), JSONL persistence via `MEMORY_FILE_PATH` env.
- **No LLM key needed** — agent decides what to store; this decided the choice (user had no OpenAI/Anthropic key).
- 9 tools: create_entities, create_relations, add_observations, delete_*, read_graph, search_nodes, open_nodes.
- File created on first tool call (verified).
- Known limits: no semantic/vector search; no temporal invalidation; concurrent writers to one JSONL risk lost updates.

## Hermes integration facts (verified 2026-08-11)

- `hermes mcp add <name> --command npx --env KEY=VALUE --args -y <pkg>` — **`--env` MUST precede `--args`**; `--args` is variadic and swallows trailing options into args (observed: env landed under `args:` → fixed by reorder).
- `echo "Y" | hermes mcp add ...` needed for the "Enable all N tools?" prompt in non-interactive runs.
- Verify placement: `grep -A8 "^  memory:" ~/.hermes/config.yaml` → expect `env:` block, not inside `args`.
- MCP tools load at startup only → new session required (`hermes mcp test` verifies connection without restart).
- User machine env (2026-08): no OPENAI/ANTHROPIC/GEMINI/DEEPSEEK/OPENROUTER keys in ~/.hermes/.env; has OPENCODE_GO_API_KEY (opencode-go provider), GitLab PAT, GWS client secret.
- Hermes built-in memory (memory/user profile) is separate from MCP memory layer — MCP layer is for cross-tool sharing.
