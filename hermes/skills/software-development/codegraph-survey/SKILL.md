---
name: codegraph-survey
description: How to use CodeGraph (the codegraph_explore MCP tool + CLI) as the PRIMARY code-survey tool for structural/semantic questions in any repo, and when to fall back to search_files. Includes the init/sync/index workflow so the index stays warm. Trigger whenever the user asks to understand, trace, refactor, or impact-analyze code.
---

# CodeGraph Survey Workflow

CodeGraph gives semantic, structure-aware answers (symbols + call paths + blast
radius + verbatim source) that plain grep/text search cannot. Use it as the FIRST
survey tool for any "how / where / trace / impact / refactor / who-calls / depends"
question. Use `search_files` only for literal text, regex, counting occurrences, or
filename globs.

## When to use `codegraph_explore` (PRIMARY)

Use it for structural/semantic questions, including natural language:
- "Hàm X làm gì / ở đâu?" — name the symbol (`codegraph_explore` query: `"useLoginFlow"`)
- "Ai gọi / depend vào X?" — asks for blast radius
- "Sửa component shared này ảnh hưởng chỗ nào?" — impact analysis
- "Flow login chạy thế nào?" — name the symbols spanning the flow
  (`"mutateElement renderScene"`)
- Trace / architecture / how data flows / where a type is defined

The MCP tool returns: relevant symbols across files, the call/reference graph,
**blast radius** (what depends on the symbol), and **verbatim source** (treat as
already Read — do NOT re-Read those files). It also flags "⚠️ no covering tests
found", which is gold for MR review.

ALWAYS pass `projectPath` = absolute path to the repo (or a dir inside it).
CodeGraph uses the nearest `.codegraph/` index at or above that path. For a
monorepo, pass the workspace root so the whole graph is in one index.

## When to use `search_files` (FALLBACK — text only)

- Find a literal string (error message, config key, hardcoded value)
- Count occurrences of a pattern
- Find files by glob (`*.py`, `*config*`)
- Quick content sweep when you do NOT need symbol/dependency understanding

## Index lifecycle (keep it warm)

The CLI `codegraph` is installed via mise. The MCP tool auto-indexes on the fly if
no `.codegraph/` exists, but that is slower and not cached. For stable, fast,
repeatable results, keep a real index:

- **Init a repo (once):** `codegraph init <repo_abs_path>`
  - Creates `.codegraph/` in that dir. Do NOT run at `~` or `/` (blocked unless
    `-f`); always init inside the specific repo.
  - For a pnpm/turbo monorepo, init at the workspace root (one index for all apps).
  - `.codegraph/` is a local index — do NOT commit it; add to `.gitignore` if the
    repo doesn't already ignore it (do not modify repo config without asking).
- **Re-index after big changes / stale results:** `codegraph index <repo_abs_path>`
  (full rebuild) or `codegraph sync <repo_abs_path>` (incremental).
- **Check state:** `codegraph status <repo_abs_path>`.
- **Remove if needed:** `codegraph uninit <repo_abs_path>` (deletes `.codegraph/`).

## Auto-init rule (per-repo, on-demand — DO NOT bulk-init)

This is a PER-REPO, ON-DEMAND rule — NOT "scan the whole machine and init every
repo at once". Apply it only for the specific repo you are about to read/work with
in the current task:

- When you start reading or working with a repo and that repo's root has NO
  `.codegraph/` directory, run `codegraph init <repo_abs_path>` first — prefer in
  the background with `notify_on_complete=true` (indexing a large repo takes a while
  and you can keep working). Especially important for big repos (>1k source files).
- Then use `codegraph_explore` with that `projectPath`. If `init` is still running,
  the MCP tool still works via auto-index, just slower — so don't block on it.
- Only init the ONE repo you're actually working with this turn. Never walk
  `~/Projects` (or elsewhere) to init everything proactively.
- Re-init when results look stale after big changes: `codegraph sync <repo>` (incremental)
  or `codegraph index <repo>` (full rebuild).

## Pitfalls

- The bundled **codegraph plugin's auto-inject** (pre_llm_call) only fires when
  `.codegraph/` is in CWD or `..` / `../..`. With the Hermes session CWD at
  `~`, repo indexes under `~/Projects/...` are NOT auto-injected. So RELY ON THE
  MCP `codegraph_explore` TOOL (pass projectPath), not the plugin.
- Never trust auto-indexed (no `.codegraph/`) output for MR review impact checks —
  run `codegraph init`/`sync` first so blast radius is accurate.
- MCP `codegraph_explore` output is verbatim source; do not waste calls re-Reading
  those files.
- For monorepos, pass the workspace root as `projectPath`; passing a deep sub-app
  path narrows the graph and may miss cross-app callers.
