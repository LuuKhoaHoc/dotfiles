# Audit: dotfiles/agents/skills vs ~/.hermes/skills — 2026-08-12

Scope: `~/Dev-Work/dotfiles/agents/skills` (64 skills) vs `~/.hermes/skills` (272 SKILL.md, **0 symlinks**). Result: full report delivered to user; **cleanup NOT executed** (awaiting user confirmation).

## TRUE DUPLICATES (same purpose, multiple versions — keep newest)

| Cluster | Versions (size) | Keep | Evidence |
|---|---|---|---|
| Debug | `debug` (3.2K), `diagnose` (7.1K), `diagnosing-bugs` (8.5K) | `diagnosing-bugs` | `debug`+`diagnose` share identical description; both resurrected by restore commit `567d79e`; `diagnosing-bugs` has the completion-criterion refinement (Phase 1 tight-loop) |
| Code review | `code-review` (6.7K), `review` (4.0K) | `code-review` | Identical description; `review` lacks the Fowler smell baseline + refined sub-agent prompts |
| Tickets | `to-tickets` (5.8K), `to-issues` (3.3K) | `to-tickets` | Same tracer-bullet concept; `to-tickets` adds blocking edges + expand–contract for wide refactors |
| Spec/PRD | `to-spec`, `to-prd` | merge into one | Diff is only 8 lines — wording "spec"↔"PRD" + template tag; literally the same skill renamed |

## COMPLEMENTARY PAIRS (explicitly NOT duplicates — do not "clean up")

- `refactor-safe` (execution discipline) vs `request-refactor-plan` (plan via interview + file issue)
- `compound` (create docs) vs `compound-refresh` (audit/stale sweep)
- `handoff` (write doc to temp dir) vs `claude-handoff` (launch `claude --bg` agent)
- `caveman` (speech mode) vs `caveman-commit` (commit message generator)
- `obsidian` (routing: MCP/CLI/git-sync, 9.6K) vs `obsidian-vault` (content conventions: wikilinks, index notes, 1.5K) — overlapping triggers, different roles

## WRAPPERS / ALIASES (router pattern, by design)

- `grill-me` (147B — body is literally "Run a `/grilling` session")
- `grill-with-docs` (grilling + domain-modeling combo)
- `grilling` = the real implementation; `loop-me` (grill about workflows) is a distinct variant

## CROSS-TREE SHADOWING (real conflict)

- **`obsidian` duplicated in hermes**: `~/.hermes/skills/obsidian` (copy of dotfiles, 9.6K) AND `~/.hermes/skills/note-taking/obsidian` (hermes-native v1.0.0, 3.1K, "Read, search, create, and edit notes"). Both `name: obsidian` → both load; canonical source undecided.

## SAME-PURPOSE, DIFFERENT NAME (cross-tree twins)

| dotfiles | hermes twin | similarity |
|---|---|---|
| `handoff` | `session-handoff` | 18% (different bodies, same job) |
| `qa` | `qa-session` | 40% |
| `tdd` (3.2K) | `test-driven-development` | 1% — **hermes copy is 9B placeholder!** |
| `to-prd` | `product-requirements-document` | 12% |
| `to-issues`/`to-tickets` | `issue-to-tickets` | — |

13 dotfiles skills NOT mirrored into hermes: `caveman-commit`, `commit-context`, `debug`, `diagnose`, `handoff`, `qa`, `refactor-safe`, `request-refactor-plan`, `review`, `tdd`, `to-issues`, `to-prd`, `to-tickets`.

## Mirror mechanism findings

- `~/.local/bin/agents-sync` → symlink to `agents/sync-agents.sh`, which does **`cp`** (lines 62/83), NOT `ln -s`. So the mirror is copy-based → drifts whenever dotfiles is edited without running sync.
- `skill-library-mirroring` prescribes symlinks; they were used before and **broken by sync** (commit `567d79e`: "restore 12 skills deleted by sync — fix broken antigravity/gemini symlinks").
- 50/51 same-name skills were byte-identical at audit time (good sync state).
- `.skill-lock.json` (17.8K, version 3) records upstream sources (mattpocock/skills, JuliusBrussee/caveman, ...) — use it to separate user-owned from upstream-installed skills.

## Proposed cleanup (awaiting user go-ahead)

1. Delete `debug` + `diagnose` → keep `diagnosing-bugs`
2. Delete `review` → keep `code-review`
3. Delete `to-issues` → keep `to-tickets`
4. Merge `to-prd` into `to-spec` (or vice versa)
5. Decide canonical `obsidian` (dotfiles routing skill vs hermes-native note-taking)
6. Consider reverting mirror to symlinks per `skill-library-mirroring` — but verify sync script first (symlinks broke before)
