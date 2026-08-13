# Supermemory containers vs UI projects (verified 2026-08-12)

When the user asks about supermemory "spaces"/"projects" or why the web app looks empty, use this to answer precisely.

## Core model

- **Isolation unit = `containerTag`** (API concept), NOT the UI "project". Every memory belongs to a container; agents read/write only the container they point at.
- Web app URL `?project=sm_project_default` is the UI's default project. The user's setup writes to container tag `hermes`, so the default UI project can look empty — the data is in the `hermes` container.
- One supermemory account can hold many containers. The user's account already has `hermes` + older containers from before the migration.

## Where the container tag is configured (this user's setup)

| Layer | Location | Key |
|---|---|---|
| Hermes | `~/.hermes/config.yaml` → `memory.provider: supermemory` | container from provider default / env |
| opencode plugin | `~/.config/opencode/supermemory.jsonc` → `userContainerTag: "hermes"` | JSONC, not JSON |
| Local bridge MCP | `~/.local/bin/supermemory-mcp` | `CONTAINER_TAG = env SUPERMEMORY_CONTAINER_TAG \|\| "hermes"`; every tool also accepts a per-call `containerTag` override |
| API | `POST /v4/memories`, `/v4/memories/list`, `sdk.profile({containerTag})` | `containerTags: [tag]` |

Bridge tools: `add_memory`, `listMemories`, `whoAmI` — all take optional `containerTag` (default from env).

## Two-tier design for "persona shared + per-project isolation"

1. `user-persona` container: clean user profile (communication, technical preferences, workflow) with NO company info — seeded into every project container so any harness "understands the user".
2. Per-project containers (e.g. `hermes` = company work, `erp-ca-nhan` = personal project): domain knowledge only.
3. Switch by env: `SUPERMEMORY_CONTAINER_TAG=<tag>` per harness invocation, or `userContainerTag` in the opencode jsonc.

## Hermes memory: two independent channels

- `memory` tool → writes `~/.hermes/memories/MEMORY.md` + `USER.md` (local, injected every turn). NOT pushed to supermemory.
- supermemory provider → receives data only via auto_capture (conversation snapshots) or explicit `supermemory-save`. This is why the supermemory app "has nothing new" right after Hermes memory was saved locally — expected behavior, not a bug.
- Recall: `memory` (auto-injected) / `session_search` (past transcripts) / supermemory (cross-agent).

## Evolution history (this user)

Hermes built-in → `agentmemory` (REST localhost:3111, `@agentmemory/mcp`) → `@modelcontextprotocol/server-memory` (JSONL knowledge graph at `~/.agents/memory.jsonl`) → supermemory (cloud, container `hermes`). Old agentmemory entry may still linger in opencode/omp mcp.json; server-memory was removed from Hermes config.
