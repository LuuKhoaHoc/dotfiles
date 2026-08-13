# Agent Memory Landscape — research notes (checked 2026-08-11)

## Sources
- mem0.ai/blog/state-of-ai-agent-memory-2026 (benchmarks, quickstart options)
- vectorize.io/articles/best-ai-agent-memory-systems (8 frameworks ranked)
- graphlit.com/blog/survey-of-ai-agent-memory-frameworks (honest conclusion: no single best)
- evermind.ai/blogs/best-open-source-agent-memory-frameworks-2026 (OSS ranking)
- braintrust.dev/articles/best-ai-agent-memory-tools-2026 (comparison table)
- machinelearningmastery.com/the-6-best-ai-agent-memory-frameworks-you-should-try-in-2026

## Benchmarks (self-reported unless noted — treat with suspicion)
- Mem0: 92.5 LoCoMo / 94.4 LongMemEval claimed; independent eval 49.0% LongMemEval (arxiv 2603.04814) — competitors dispute the self-reported LoCoMo
- Zep/Graphiti: 94.7% LoCoMo, 90.2% LongMemEval (broader product claims); 63.8% LongMemEval (GPT-4o) independent-ish; <200ms retrieval on cloud
- Evermind EverOS: 93.05 LoCoMo / 83.00 LongMemEval / 93.04 HaluMem (new entrant, ~6.7K★)
- Standard benchmarks 2026: LoCoMo, LongMemEval, BEAM, HaluMem

## Adoption (GitHub stars, 2026-08)
- mem0: ~63K★ (7.3K forks); mem0-mcp server: 658★, updated 2026-07-21
- Graphiti (Zep): 24–26.9K★
- Letta: ~23.1K★
- Cognee: ~17.6K★
- ReMe: ~3K★; LangMem: ~1.5K★

## Pricing
- Mem0: free tier → $19/mo → $249/mo Pro (graph "Mem0g" Pro-only); SOC2 + HIPAA on managed
- Zep cloud: managed paid; Graphiti OSS free (Apache-2.0)
- Cognee: OSS free; platform €8.50/1M input tokens; on-prem €1,970/mo
- Letta: OSS self-host (PostgreSQL + pgvector)
- OpenMemory MCP: free local, but needs your own LLM key

## OpenMemory MCP (mem0) — STATUS: UNRELIABLE
- Blog launch 2026-07-31: mem0.ai/blog/introducing-openmemory-mcp
- Described as: local Docker stack (postgres + qdrant + FastAPI/MCP), tools `add_memories` / `search_memory` / `list_memories` / `delete_all_memories`, dashboard at :3000, MCP endpoint `http://localhost:8765/mcp/<client>/sse/<username>`, needs OPENAI_API_KEY in `api/.env`, `make build && make up && make ui`
- Reality 2026-08-09: `mem0ai/mem0/tree/main/openmemory` → 404; `mem0ai/openmemory` repurposed into CLI/TUI to port coding sessions across Claude Code/Codex/OpenCode (29★). Do NOT build on it.

## mem0-mcp (official, active)
- github.com/mem0ai/mem0-mcp (658★, updated 2026-07-21)
- Docker: `docker run -d --name mem0-mcp -e MEM0_API_KEY=m0-... -p 8080:8081 mem0-mcp-server`
- Smithery: `pip install mem0-mcp-server`; MCP config via `npx -y @smithery/cli@latest run @mem0ai/mem0-memory-mcp --key <smithery-key> --profile <name>` with env `MEM0_API_KEY`
- Hermes wiring: `mcp_servers` entry (stdio or HTTP), `env: {MEM0_API_KEY: ...}`; tools appear as `mcp_mem0_*` after restart

## This user's constraints (2026-08)
- ~/.hermes/.env has NO OPENAI/ANTHROPIC/GEMINI/DEEPSEEK/OPENROUTER key — only OPENCODE_GO_API_KEY (provider opencode-go, base_url ''), GITLAB_PAT, GWS secrets
- Hermes v0.20.0; Docker 29.7.2 + Compose 5.4.0 available; no ollama local
- Toolchain: Hermes + antigravity IDE + opencode/omp + Claude Code/Codex → cross-tool memory via MCP is the relevant integration path
- Decision pending with user (2026-08-11): Mem0 self-host vs Zep/Graphiti vs ReMe vs Hermes built-in
- User asked "có trả phí hả" — answer pattern: local/OSS = free (minus own LLM API usage); managed cloud tiers quoted explicitly
