---
name: agent-memory-setup
title: Agent Memory Layer Setup
description: "Use when setting up agent memory (Mem0/Zep/ReMe)."
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [memory, mcp, setup, agent-memory, mem0, zep]
    related_skills: [mcp-config, hermes-agent]
---

# Agent Memory Layer Setup

## When to Use

- User asks to "set up agent memory", "add memory to my agents/tools", or "which memory framework is recommended".
- User wants cross-tool memory (Hermes + IDE agents sharing one memory store).
- Choosing between memory vendors (Mem0/Zep/Letta/ReMe/official MCP server).

When the user asks to "set up agent memory", "add memory to my agents/tools", or "which memory framework is recommended" — research the current landscape first (it shifts quarterly), then wire the chosen layer into the user's agents via MCP.

## Decision Flow

1. **Research current landscape** (do NOT rely on this skill's snapshot — memory is a fast-moving space; vendor repos get repurposed within weeks). Search: `best agent memory framework <year>`, `agent memory MCP server comparison`.
2. **Check the user's constraints first**:
   - Do they have an LLM API key available? (Mem0/Zep cloud need one; `@modelcontextprotocol/server-memory` does NOT — the agent itself decides what to store)
   - Docker available? → Mem0 self-host / OpenMemory possible
   - Privacy: local-first vs cloud. User keeps personal data off public dotfiles.
3. **Verify the vendor repo is real and current** — the OpenMemory MCP case (2026-07): blog launched it, repo `mem0ai/openmemory` was repurposed into a session-porting CLI within 1.5 weeks and the folder vanished from `mem0` main. Always `curl` the GitHub API for repo description/stars/updated_at + check the path exists before recommending.
4. **Prefer the official MCP reference server for simple personal memory** — no API key, no Docker, runs via npx.

## Recommended Default: `@modelcontextprotocol/server-memory`

Official MCP knowledge-graph memory server (entities + relations + observations), persists to JSONL. Free, local, no LLM key, no Docker.

### Add to Hermes

```bash
# CRITICAL: --env must come BEFORE --args (--args is variadic and swallows trailing flags)
echo "Y" | hermes mcp add memory --command npx \
  --env MEMORY_FILE_PATH=/home/<user>/.hermes/memory/memory.jsonl \
  --args -y @modelcontextprotocol/server-memory

# Verify env landed in the right place (NOT inside args):
grep -A8 "^  memory:" ~/.hermes/config.yaml
# expect: env: \n  MEMORY_FILE_PATH: /home/<user>/.hermes/memory/memory.jsonl

hermes mcp test memory   # connection check
```

- File is created on **first tool call**, not at startup — don't expect the file after `hermes mcp add`.
- Tools appear **only in new sessions** (MCP loads at startup; no hot-reload). Verify end-to-end with `hermes chat -q "call create_entities ... then read_graph"`.
- Memory file holds personal info → keep it under `~/.hermes/memory/`, NEVER sync to public dotfiles repo.

### Pitfalls

- **`hermes mcp add` arg order**: `--args` is variadic; `--env KEY=VALUE` after it gets swallowed into `args` and the server silently runs with defaults. Fix: `--env` first, then `--args`.
- **Interactive prompt**: `hermes mcp add` asks "Enable all N tools? [Y/n/select]" — pipe `echo "Y" |` for non-interactive.
- **Concurrent writers**: each MCP client spawns its own stdio server instance; two agents writing the same JSONL → lost updates. One writer per file, or use a server (Mem0/Zep) with real storage.
- **Memory server ≠ Hermes built-in memory**: Hermes already has its own memory/skills system; the MCP memory layer is for cross-tool sharing (antigravity, opencode, claude-code, etc. can point at the same file).

## 2026 Landscape Snapshot (as of 2026-08)

| Option | Type | Cost | Notes |
|---|---|---|---|
| Mem0 (`mem0ai/mem0`, ~63K★) | Managed/self-host, vector+graph | Cloud free → $19/mo → $249/mo Pro (graph) | Most adopted; needs LLM key; MCP server exists |
| Zep / Graphiti (~26K★) | Temporal knowledge graph | OSS self-host or cloud | Best for facts changing over time; needs LLM key |
| Letta (MemGPT, ~23K★) | Stateful agent platform | OSS/self-host or cloud | Memory as runtime, heavier |
| Cognee (~17K★) | Graph memory control plane | OSS | remember/recall/forget API |
| ReMe (~3K★) | File-based, transparent | Free | Readable/editable files, no Docker |
| `@modelcontextprotocol/server-memory` | MCP KG server | Free | Official, no LLM key, JSONL |

Full research notes: `references/memory-landscape-2026.md`.

## Verification

- `hermes mcp list` shows the server ✓ enabled
- `hermes chat -q` new session can create + read entities
- JSONL file contains the entity after first write
