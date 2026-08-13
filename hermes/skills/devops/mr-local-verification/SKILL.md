---
name: mr-local-verification
description: Verify MR test/typecheck claims on branch code locally.
---

# MR Local Verification

Verify an MR's claims by actually running its tests/typechecks on the BRANCH code, not by trusting the description checklist. Use when reviewing an MR whose description lists commands like "đã chạy test/typecheck/build thành công" — re-run the focused ones.

## Workflow

0. **Branch-first READING (no worktree needed)** — for reviewing diffs/files on the branch, the main clone is enough:
   ```bash
   git fetch origin <branch> develop
   git diff origin/develop...origin/<branch>            # the MR diff
   git show origin/<branch>:<path/to/file> | sed -n '1,120p'   # read a full file on the branch
   git log --format='%h %s' origin/develop..origin/<branch>    # commits in the MR
   ```
   Worktree only when you must RUN branch code (tests/typecheck) — see below.

1. **Branch code isn't in the main clone** (it's on develop) → temp worktree:
   ```bash
   git worktree add <clone-root>-<iid> origin/<branch>   # FOREGROUND — background shells can mangle git
   cd <worktree> && pnpm install --offline --prefer-offline  # shared store → fast
   ```
2. **Focused tests first** — the fastest signal for logic claims. Run the exact test files the MR mentions:
   ```bash
   pnpm --filter <pkg> exec vitest run <path/to/file.test.ts>
   ```
3. **Typecheck** the touched workspaces. ⚠️ In a fresh worktree, app typechecks fail with `Cannot find module '@hilo/*'` (or `@scope/*`) — that's **missing built package outputs, NOT code errors**:
   ```bash
   pnpm build-infra   # build shared packages first
   pnpm --filter <app1> typecheck && pnpm --filter <app2> typecheck
   ```
4. **Pipeline status** via MCP `list_merge_request_pipelines` (match head sha) — don't trust "CI passed" in the description. ⚠️ In this setup the `mcp__gitlab__*` tools are **deferred**: `tool_describe` the tool first, then invoke with `tool_call(name, arguments)` — direct calls fail with "Tool does not exist" (that error means "load it via tool_call", not "tool is gone"). ⚠️ Repo fact (vppos erp-admin, verified 2026-08-07): MR pipelines run ONLY `trivy:iac` (non-optional) + `sonarqube:scan` (`allow_failure: true`) — **no test/typecheck/build jobs at all**. A green MR pipeline therefore verifies almost nothing about the code; every test/typecheck claim in the MR description must be re-run locally (steps 2–3). To see what a pipeline actually ran, `list_commit_statuses` (requires `sha` + `project_id`, pipeline_id optional).

4a. **Finding the MRs to verify** — `list_merge_requests` WITHOUT `project_id` (even with `author_id`/`author_username`) can silently return `[]` while the author has open MRs (observed 2026-08-07, cuongt id=10). Never conclude "no MRs" from that call. Reliable: project-scoped `list_merge_requests(project_id="vppos-team/erp-admin", state="opened", order_by="updated_at", sort="desc", per_page=50)`, filter by `author.username` in the response. "Vừa push fix" = most recent `updated_at`, cross-checked with the head sha in `list_merge_request_pipelines`. One author's MRs may span several authors' MRs in the same list (e.g. !558/!556 cuongt vs !560/!561 QuyCN) — filter carefully.
5. **Cheap contract greps** before approving FE changes:
   - Caller wiring: does the parent actually pass the new prop? `grep -rn "<ComponentName>" apps/<x>/src --include="*.tsx"` excluding the component file itself.
   - i18n parity: every new locale key exists in BOTH `en` and `vi` (and in the right parent object — verify with `sed -n` around the insertion). ⚠️ Nested-key check trap (real case MR !556): `'a.b' in d.get('a', {})` is a LITERAL-key membership test — the dotted string is not an actual key, so it silently returns `False` → false "missing key" alarm. Check parent-scoped instead (`'b' in d.get('a', {})`) or find the real path recursively (`def find(o, k, p=''): ...`). Before reporting a missing locale key, confirm the check itself is correct.
   - JSON validity: `python3 -m json.tool <file>`.
6. **Cleanup**: `git worktree remove --force <path>` — recreating is cheap; don't leave clutter.

## Pitfalls

- `git diff --check` and `git diff --cached --check` for whitespace; locale JSON must parse.
- **Stale-base trap (real case #156 worktree, 2026-08-07):** when the branch base predates other merged MRs, `git diff origin/develop --stat` mixes in REVERSE-diffs from those MRs (deletions of files other MRs removed on develop, unrelated `+N` hunks) — it is NOT the feature's scope and its file list can be dominated by noise (27 files where the feature touched 3). Attribute changes with `git log --oneline <base>..HEAD` and `git show <commit> --stat` WITHOUT a pathspec — a pathspec-limited `git show <sha> -- <paths>` only shows those paths, so its stat can make a commit look like it never touched a file it did (the +135 test-file hunk was in the commit all along). The branch also shows as "behind" forever until rebased — flag rebase-before-MR when the base is stale.
- **Review the FULL working tree of a WIP worktree, not just commits:** `git status -sb` + `git diff` (uncommitted) + `git log --oneline <base>..HEAD`. The latest state often lives in uncommitted changes — dead helpers exported-but-unused, half-wired functions (real case #156: `formatTimePickerDraft` uncommitted, exported, never wired into `onChange` → typed `0830` reverted on blur). Flag dead exports as blocking either way: wire them or delete before commit.
- A typecheck failure listing only `Cannot find module '@scope/*'` errors means build-order issue, not code issue — never report it as a code bug.
- **"Module '@hilo/ui' has no exported member 'X'" ≠ code broken — check worktree node_modules FIRST** (real case #156, 2026-08-07: wrongly told the user "develop is broken" twice and retracted). Worktrees don't auto-install node_modules; a stale or missing dist (`node_modules/@hilo/ui` absent) makes tsc resolve an OLD package build while the checked-out source already has the member. Diagnosis order: (1) `ls node_modules/@hilo/ui` in the worktree → missing/stale → `pnpm install` and re-run; (2) verify SOURCE not dist: `git show origin/develop:<path>` for BOTH sides of the contract (the app's import AND the package's export) — source consistent ⇒ code fine, environment stale; (3) read `git diff origin/develop -- <file>` direction carefully: a `-` line exists in origin/develop and is ABSENT in the worktree — reading it backwards yields the inverted conclusion ("develop removed X" when the branch was simply based before X landed). Only declare "develop broken" after both sides check out on origin/develop source.
- Focused tests pass ≠ app compiles: always run the app typechecks for apps that import the changed package.
- Don't review what's not in the diff: `git diff origin/develop...origin/<branch> --stat` first to confirm scope.
- **Tests asserting Tailwind class strings (`toHaveClass('pl-6')`) prove nothing about layout** (real case MR !560: tree rows indented, inter-level `TreeGapBridge` left at pl-0 → connector spine severed; spec passed). For tree/indent diffs, compute the rendered geometry from the component source: `TreeConnector`/`TreeGapBridge` (packages/ui) draw the spine at `left-1/2` of a fixed `w-6` box → spine x = row padding + 12px; bridges must carry the SAME padding as the level below (wrap them in a padded div — padding on the bridge itself doesn't move an `absolute left-1/2` line). If geometry can't be verified from code alone, demand a screenshot in the review.
- **MR description checkbox "Đã chạy test local" unchecked ≠ tests fail** — run the claimed commands yourself; if they pass, tell the author to tick it, citing your run (real case MR !560: 2/2 vitest + eslint + tsc all green, checkbox blank). Also flag leftover template text (`<!-- ... -->` comments, `<workspace>` placeholders) as blocking description hygiene.
- **erp-admin monorepo: cross-MFE near-duplicates are the pattern, not duplication** — HR/employee vs shell have separate API-layer hooks (`useXEmployeeDocuments` vs `useProfileXEmployeeDocuments`); a feature hook byte-identical except for which per-MFE query hooks it calls is CORRECT boundary separation (real case MR !556, two 162-line hooks differing in 6 import lines). Don't flag it. Flag instead: logic copy-pasted across MFEs that belongs in `@hilo/shared`/`@hilo/ui`; thin per-MFE wrappers (grids/slot cards) staying local is fine. Mutation payload shapes (e.g. `attachmentIdsToDelete` replace pattern) must match existing consumers — `git grep` the field on `origin/develop` first.

## Verification

Every command above exits 0 with the expected output (`N tests passed`, `tsc -b` clean, pipeline `success`) before you approve. Report real outputs in the review.
