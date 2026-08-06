---
name: agents-md-sync
description: Use when updating AGENTS.md to match the codebase.
---

# AGENTS.md Sync — Keep Agent Guides True to the Code

Class of task: bring agent-facing guide docs (AGENTS.md hierarchy, child guides, `WHERE TO LOOK` tables) into exact agreement with the current codebase and docs. Typically assigned as one subagent per directory (app, package, feature). Subagent deliverable: a per-file diff + a report, NOT a commit (the orchestrator verifies, formats, and commits).

## Ground rules (hard)

- **Fix ONLY claims that are SAI (wrong) or STALE (superseded by evidence).** Leave everything else untouched, even if slightly incomplete or awkwardly worded.
- **Do NOT add content you cannot back with code evidence.** A plausible-but-unverified addition is worse than a known omission.
- "Not wrong, just a subset" is NOT stale. Example: a guide listing 2 of 3 enum variants is accurate-but-incomplete → leave it, flag in the report for human review.
- Preserve existing structure/format (tables, tree blocks, bullet style). Markdown table column alignment is cosmetic — do not churn padding.
- Never commit, branch, or touch .env/credentials. Confirm the working tree only touched the assigned guide files (`git status --porcelain`).

## Workflow

1. **Read the assigned AGENTS.md file(s)** in full.
2. **Verify every `WHERE TO LOOK` file path exists.** Use `search_files(target='files')`. A "Path not found" on a listed directory/file = STALE. This is the single highest-yield check (tables rot fastest).
3. **Verify every named symbol/identifier exists** via `search_files(output_mode='content')`. A symbol that appears ONLY inside the AGENTS.md file (and not in code) is a fabricated/stale reference — e.g. `MFE_STYLE_LOADERS`, `components/skeletons/`, `components/PersonalAlertDialog.tsx`. Grep the whole subtree; if the only hit is the guide itself, delete/correct it.
4. **Verify config constants against the real config file.** For Vite/MFE apps: `name`, `base`, `port`, exposed entries all come from `vite.config.ts`. Do not trust the guide's numbers — read the config.
5. **Verify workspace scripts against `package.json`.** A claim like "No local test command" is only true if `package.json` has no `test` script — even when a `.spec.tsx` file exists.
6. **Cross-reference the source-of-truth manifests.** When a guide claims "this file is the source of truth for X", confirm X actually derives from that file. E.g. if remotes moved into a manifest (`src/registry/mfe-manifest.ts`) and `vite.config.ts` now imports it, then any guide line saying "`vite.config.ts` is the source of truth for remotes" is STALE and must point to the manifest.
7. **Confirm the code path does what the guide says** by reading the relevant source (hook/component/route). A guide saying "use `PATHS` from @hilo/shared, not hardcoded routes" needs the import actually present.
8. **Patch** the confirmed stale lines. For a deleted directory, prefer swapping it for a real sibling directory over dropping the tree line (keeps the tree informative) — only if the real one exists.
9. **Report** with a per-file 3-column table (File | Đã sửa gì + lý do + bằng chứng | Verified OK), plus a "Điểm CHƯA chắc chắn / cần human review" section for: out-of-scope stale guides (e.g. root AGENTS.md claims now contradicted by code), unrunnable spec files, and "not wrong but incomplete" claims.

## Orchestrator workflow (fan-out refresh of ALL guides)

When the user asks to refresh every AGENTS.md in a repo (20+ files), run it as a parallel fan-out:

1. **Scope with the user first.** Clarify which files (root-only / app+package / all incl. feature-level) and the source of truth (codebase on branch X + `docs/solutions/`). A 28-file refresh is expensive — get explicit buy-in, don't assume.
2. **Prepare shared context**: enumerate all AGENTS.md (`search_files(target='files', pattern='AGENTS.md')`), read 1–2 representative files (especially any known-stale one), list `docs/solutions/` newest-by-date, confirm `git status` clean + branch.
3. **Dispatch ≤5 subagents with DISJOINT file ownership**, grouped by area (root+packages / apps/hr / shell / employee...). Each prompt must state:
   - the exact assigned file list (absolute paths) and files owned by OTHER agents → explicitly off-limits ("do NOT edit root AGENTS.md, another agent owns it") to prevent races;
   - mandatory per-file procedure: read → verify every claim with real code (file:line evidence) → patch only stale/wrong → preserve structure & language → no rewrite-from-scratch, no unverified additions;
   - source-of-truth priority: (1) real code, (2) `docs/solutions` + ADRs (newest filename date wins; `replaces:` frontmatter supersedes), (3) real config (`package.json`, `vite.config.ts`, `pnpm-workspace.yaml`, `.nvmrc`, `lefthook.yml`);
   - known-stale hotspots found in step 2 so agents don't miss them;
   - forbidden: commit/branch, code edits, .env, deleting AGENTS.md, creating new files;
   - required report: 3-column table per file (File | đã sửa + lý do + bằng chứng file:line | Verified OK) + "uncertain, needs human review" list.
4. **Post-run: verify the verifiers (never trust self-reports).**
   - `git status --short` + `git diff --stat`: actual changed files must match the union of agents' claims.
   - If a result carries a file-mutation warning ("1 file(s) NOT modified" / "Found 2 matches for old_string"), do NOT redo the work — the agent usually retried with more context and the file IS edited. Confirm with `git diff`.
   - Re-verify the highest-risk claims yourself with grep/ls, batched into 2 terminal calls (~15 checks): anything that (a) contradicts a memory entry or (b) rewrites repo-wide claims (remote lists, ports, canonical patterns, routes).
   - When a subagent's code evidence contradicts memory, the CODE WINS — update the stale memory entry.
5. **Format before commit.** Subagent edits misalign markdown tables; the repo's pre-commit lint-staged would run prettier anyway — run `pnpm exec prettier --check $(git diff --name-only)` then `--write` FIRST so the diff is predictable. Then `git add` + commit with `docs:` type, push (pre-push hook runs typecheck — budget minutes).

## Deprecated-pattern detection & module triage

- **Detect deprecated code patterns from the docs, not just the code.** AGENTS.md can still call a pattern "canonical" long after it was superseded. Read `docs/solutions/**` pattern docs and check YAML frontmatter `replaces:` — a doc that `replaces:` an older one means the older pattern is deprecated. Example: AGENTS.md said "canonical table wiring: `apis/` → `hooks/use*DataSource.ts` → `DataSourceResult<TRow>`", but `canonical-list-wiring-pattern-2026-07-27.md` declared `replaces: canonical-data-source-hook-pattern-2026-05-07.md` and explicitly said "update apps/.../AGENTS.md: remove the line referencing `use*DataSource.ts`". Update the guide to name the replacement (3-layer: `use*UrlState` + thin `use*ListQuery` → component extracting `list`/`total`, using `computeTotalPages`/`safePage` from the shared pkg) and point to the new doc.
- **Distinguish three discrepancy buckets — treat each differently:**
  1. **Stale claim / wrong path** → fix directly with evidence (file renamed `XViewWrapper.tsx`→`XView.tsx`; folder `attendance`→`attendances`; spec `.spec.ts`→`.test.ts`; store dir `store/`→`stores/`; mock file claimed but deleted; "no `apis/` folder yet" gone stale once `apis/` appeared).
  2. **Deprecated-but-still-in-code** → keep the file reference (it is functional) but annotate: "deprecated pattern; new code should use `<replacement>`, see `<doc>`". Do NOT delete functional references just because the pattern is old.
  3. **Aspirational / not-yet-created** (doc labeled "cấu trúc mục tiêu" / "target structure", or a file genuinely absent) → do NOT invent content; fix only clearly-false sentences inside it and flag the rest for human review.
- **Dead-vs-alive module triage via the router.** Read `App.tsx`/routes/`PATHS` to decide whether a feature is **dead** (never imported or route-mounted → leave its AGENTS.md untouched; do not add a "dead module" note you can't prove) vs **alive** (mounted → keep and reconcile). Mounted ≠ dead: a feature with an active route is alive even if it still contains deprecated patterns or leftover `adapters/` files.
- **Adding newly-existing modules.** When a module has a real `index.ts` + a real route but is absent from the parent STRUCTURE tree / WHERE TO LOOK, add it there. Do NOT create a child `AGENTS.md` for it (out of scope unless assigned) and do NOT add "child guide" rows pointing at nonexistent guide files.

## Pitfalls

- **Root-guide claims can be stale even when the file you're assigned is fine.** In an MFE monorepo, remote/mount status lives in 3 places that must agree: the Vite remote manifest (`MFE_REMOTE_CONFIGS`), the route loader map (`MFE_LOADERS`), and shared module metadata (`APP_MODULES` `enabled`). A claim "X is configured but not mounted" is STALE the moment X appears in all three. Flag it for the root-guide owner even if it's not your file.
- **A file existing ≠ the guide's claim about it being true.** Always read the file. `MFEErrorBoundary.tsx` exists but "style loader wiring" described next to it does not.
- **"Keep thin / small workspace today" role lines rot.** If the app grew (new pages, search/filter, tests), the "small workspace" framing is stale — drop it rather than defend it.
- **Verification is read-only + grep, not build/run.** You do not need to boot the app to confirm file paths, symbols, and config constants. Build/typecheck is for the user, not for a doc-audit subagent.
- **Do NOT build the source tree with a hand-rolled depth-limited `os.walk`.** A walk that only prints files to depth N silently hides nested subdirectories (e.g. `components/detail-request-dialogs/`, `edit-request-dialogs/`), making you wrongly conclude a referenced path doesn't exist and "fix" a claim that is actually correct. Always use `search_files(target='files', pattern='*')` (a real recursive listing) to enumerate the tree before judging any path missing.
- **`search_files(target='files')` takes GLOB patterns, NOT regex.** A pattern with `|` alternation (e.g. `useCreateCustomer|useCustomerDetailQuery`) returns 0 matches and falsely reads as "these files don't exist" — a real false 🔴 during existence checks (worked example, customers-feature audit 2026-08-05: index.ts exports looked broken until each name was globbed separately). Verify one name per glob call (`*useCreateCustomer*`) or use `target='content'` for regex.
- **Route lists rot differently from filenames.** The router path and the page filename are independent — page `LeavePage.tsx` can sit at route path `time-off-management`. Always read the router file (`App.tsx`) for actual route paths; do not infer routes from page filenames.
- **Verify i18n namespaces by checking the actual JSON files.** Before assuming a namespace is dedicated or shared-with-a-sibling, list `translations/en/` + `translations/vi/` and confirm the namespace file exists in *both* languages. A dedicated `employee.json` in both languages contradicts a guess that employee keys live in the `hr` namespace.
- **Parallel subagents edit sibling guides in the same repo.** When multiple agents are each assigned one AGENTS.md, `git status` will show their files modified too. Scope `git diff <your own files>` and don't flag others' edits — only confirm *your* files changed and no code/tests were touched.
- **A delegation "file NOT modified" warning is not failure.** It usually means the agent's patch hit a non-unique match, it retried with more context, and succeeded. Confirm with `git diff` before redoing anything.
- **Live delegation logs truncate final summaries; don't poll them.** `task-*.log` lines cap around ~500 chars (`…(+N chars)` at the end), and `ls -t` on the delegation cache dir surfaces stale summary files from OLDER runs — both mislead you into thinking results are lost or mixed up. The consolidated batch result re-enters the conversation automatically once ALL tasks finish; just end the turn and continue when it arrives. (Also: `search_files(target='files')` is GLOB-only — see the search_files pitfall above; a `|` regex pattern returns 0 hits.)
- **Code beats memory.** When a subagent's file:line evidence contradicts a memory note (e.g. "module X is a dead module"), verify the router/code directly — memory rots as routes get added (worked example: `change-management` had gained a real route). Update the memory entry; don't discard the finding.
- **A convention can be MISSING or MIS-SHAPED in AGENTS.md even when users believe it's documented** (real case, 2026-08-05): root AGENTS.md described the API envelope as `{ data, success, code }` — a shape that doesn't exist (actual `ApiResponse<T>` = `{ success, data, error, meta }`) — and the type name `ApiResponse` appeared in ZERO AGENTS.md files. The stale shape actively misled agents into inventing wrapper interfaces (`CrmPagedListResponse`) + normalize helpers that passed both code and review. When a convention is violated repeatedly in code AND review: (1) grep ALL AGENTS.md for the contract TYPE NAME (0 hits = effectively undocumented — the doc must NAME the type, not describe a vague shape); (2) check docs/solutions + docs/plans for citations that BLESS the anti-pattern and fix those too; (3) ensure the review skill/checklist has a dimension for it. Fix the doc triad (AGENTS.md + docs/solutions + review checklist), not just memory.

## Support files

- `references/erp-admin-mfe.md` — worked example: auditing the Hilo erp-admin MFE monorepo's AGENTS.md files (which claims were stale, the exact evidence, and the 3-way remote-status check).
- `references/orchestrator-batch-run.md` — orchestrator side: dispatch prompt skeleton, post-run verification command batch, prettier/commit sequence, and false-alarm + stale-memory lessons from the 28-file fan-out run.
