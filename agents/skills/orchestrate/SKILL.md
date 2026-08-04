---
name: orchestrate
description: Orchestrate execution as an orchestrator — route well-defined mechanical work (finding, reading, searching files, mechanical edits, data collection) to the cheapest capable subagent, embed codegraph-first in every subagent brief, bound the wait and take over on a stall, and run complementary work yourself when fan-out is narrow. Use when a task has delegatable substeps or sends you searching or reading the codebase.
---

# Orchestrate

The orchestrator conducts; the subagents play. Keep the work that needs your judgement — scoping, taste, the top-level plan, cross-slice contracts — and route every well-defined mechanical substep to a subagent: finding files, reading files, searching the codebase, mechanical edits, data collection. An orchestrator who reads the files themselves has picked up an instrument.

Bar, per substep: routed to the cheapest agent that holds it; codegraph-first in every brief that enters the codebase; no idle wait behind a narrow fan-out or a stall.

## Right-size the model

Match the agent to the work — cheapest that holds, reach down only when the row above can't:

| Work | Agent | Why |
|---|---|---|
| Find / read / search files, explore an unknown area | `scout` | read-only, fastest model — the default for any lookup |
| Mechanical update or data collection, no judgement | `sonic` | low-reasoning, cheapest writer |
| Multi-step delegated task needing edits + judgement | `task` | general worker |
| UI, review, library/API research | `designer` / `reviewer` / `librarian` | specialist |

A file lookup routed to `task` pays for judgement it never uses. For the `agent()` / `completion()` helpers, the same ladder is `model: "smol"` (mechanical) → `"default"` (judgement) → `"slow"` (hard reasoning only).

## Codegraph-first

When the repo has a `.codegraph/` directory, reach for `codegraph_explore` (MCP) or `codegraph explore "<symbols>"` (shell) **before** `grep`/`find`/reading files — it returns the verbatim source and the call paths between symbols in one call, including dispatch hops text search can't follow. No `.codegraph/` → skip it, fall back to `grep` / `read`.

Subagents start blank. Put codegraph-first in **every** brief that sends a subagent into the codebase: name the tool, the `.codegraph/` check, and the fallback. A subagent unaware of the index grep's past what it could have had in one call.

## Bound the wait

After you fan out, keep the main thread advancing — an orchestrator who spawns and idles is the work with extra latency.

- **Narrow fan-out (1–2 subagents)** — advance the main thread on a complementary line while they run: another independent slice, a deeper read of ground you'll need next, or a different angle on the same problem. Complementary, never duplicate — two agents on the same file waste one.
- **Stall** — bound the wait. A subagent that returns no progress within the window has hung: cancel it and run the work inline. Picking up the instrument is the last resort, not the first.
