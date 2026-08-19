---
name: gitlab-mr-review-lifecycle
description: "Use for GitLab MR re-review, approval, and merge lifecycle."
version: 1.1.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [gitlab, merge-request, code-review, lifecycle]
    related_skills: [gitlab-mr-review, gitlab-mr-review-feedback, pr-review]
---

# GitLab MR Review Lifecycle

## When to Use

Use this skill when a teammate's GitLab MR has already received review feedback and the user asks to re-review, approve, merge, or complete the review-to-merge lifecycle.

This is a lifecycle skill, not a replacement for code-review criteria. Use `gitlab-mr-review` for branch-first diff retrieval, `gitlab-mr-review-feedback` for consolidated-note discipline, and `pr-review` for correctness/security/coverage criteria.

## Core invariants

1. **The MR HEAD is the unit of truth.** Re-fetch MR metadata before every re-review or side effect. Record `source_branch`, `target_branch`, `head_sha`, pipeline status, mergeability, and current state.
2. **Never trust a fix commit message.** Inspect the actual commit diff and then re-enumerate every prior finding against the new tip. A commit titled "address review feedback" may fix only part of the list.
3. **Review against the MR branch, never an unrelated local checkout.** Read changed files at `ref=<source_branch>` or from a verified fetch/worktree whose SHA equals `head_sha`.
4. **Approval and merge are separate side effects.** A prior "approve" verdict is not permission to approve or merge later. Execute those actions only after the user explicitly asks.
5. **Verify every external side effect.** After posting, approving, or merging, read back the note/MR metadata and report the direct URL or merge commit SHA.

## Re-review workflow

### 1. Pin the new tip

- Fetch MR metadata.
- Compare the new `head_sha` with the SHA reviewed previously.
- If unchanged, do not claim a new push was reviewed. Check whether the user meant another MR before continuing.
- Fetch the source branch and verify `git rev-parse FETCH_HEAD == head_sha`.
- Inspect `git diff <old_head>..<new_head>` and the full MR diff, not only the latest commit.

### 2. Re-enumerate prior findings

Build a status table for every previous finding:

| Finding | Status | Evidence |
|---|---|---|
| old issue | ✅ FIXED / ❌ STILL OPEN / ↩️ VOID | exact file:line and branch-tip behavior |

For each item:

- Verify the implementation independently at the new tip.
- Check the consuming path and relevant tests; do not accept a fix solely because the commit message or MR description says it is fixed.
- Retract false positives explicitly with `↩️ VOID`, including why the original claim was wrong.
- Do not re-litigate an item that is confirmed fixed; show the evidence once and move on.

### 3. Run targeted gates

Run the narrowest relevant tests, typecheck, lint/format checks, and build. Report real output, not claims copied from the MR description. For the Hilo ERP monorepo, the usual dashboard gates are:

```bash
pnpm --filter hr-dashboard exec vitest run src/features/dashboard
pnpm --filter hr-dashboard typecheck
pnpm --filter hr-dashboard build
pnpm --filter hr-dashboard exec eslint <changed-files>
pnpm --filter hr-dashboard exec prettier --check <changed-files>
git diff --check
```

When verifying in a fresh worktree, build package infrastructure first if workspace packages expose types from generated `dist/` artifacts:

```bash
pnpm build-infra
```

If the first typecheck/test run produces a cascade of `Cannot find module '@hilo/*'` errors, treat that as the expected missing-artifact signature: run `pnpm build-infra` and rerun the same gate before inspecting source errors. Do not report the first run as a product regression. Record the corrected command result, not the setup failure.

Also reconcile the implementation against the current linked issue/acceptance criteria, not only the MR description. If the MR intentionally changes a UX contract (for example, removing an "all employees" mode in favor of selection-only) while the issue still describes the old behavior, report it as a non-blocking spec-drift note and recommend updating the issue so future reviews and release tracking use the same contract.

Treat setup failures separately from source failures; never convert missing generated artifacts into a code finding without first satisfying the repository's documented build prerequisite.

### Stale `@hilo/shared` dist after merge/stash (Hilo erp-admin)

Shell and remote MFEs resolve `@hilo/shared` types/runtime from the built `dist/` (package exports), not from `src/`. After `git merge origin/develop` or a `git stash push -u` / `git stash pop` cycle, the dist can be stale while the source is fresh:

- Symptom 1: shell typecheck fails `TS2305: Module '@hilo/shared' has no exported member 'NotificationListFilter'` right after merging develop (new shared source, old dist).
- Symptom 2: shell tests pass/fail inconsistently after stash/pop — e.g. `isCrmRoute` returns `false` though `navigation.ts` source has `requiresCrmContext: true`, because `dist/config/index.mjs` is stale.

Fix: `pnpm --filter @hilo/shared build` (runs `vite build && tsc -p tsconfig.build.json`), then rerun the same gate. Treat the first run after merge/stash as a setup check, not a product regression. The pre-push hook also runs the full monorepo typecheck (`pnpm -r --parallel run typecheck`), so rebuild shared dist before pushing after any merge.

To prove a failing test is pre-existing (not caused by the MR): `git stash push -u` → run the failing test(s) on clean develop → `git stash pop` → rebuild `@hilo/shared` dist (stash/pop can leave it stale) → rerun.

### Approve with the exact SHA

`approve_merge_request` with a wrong/guessed SHA returns `409 {"message":"SHA does not match HEAD of source branch: <correct-full-sha>"}` — retry with the full SHA returned in the error body; never guess or truncate a SHA.

### Vitest/lint pitfalls when adding tests to the MR branch

See `references/erp-vitest-lint-pitfalls.md` — zustand persist localStorage must be mocked at module-load via `vi.hoisted` (before imports) or store-touching interceptor tests crash with `reading 'setItem'`; `react-hooks/set-state-in-effect` (eslint-plugin-react-hooks v7) disables must sit on the exact `setState` line; `vi.importActual<typeof import(...)>` trips `consistent-type-imports`; lint-staged abort leaves files staged (fix + re-commit, no re-add needed).

### 4. Replace review feedback cleanly

If the user prefers one clean review note:

- Delete the previous consolidated review note before posting the corrected/re-review note.
- Post one consolidated note tagged with the actual MR author.
- Include the branch name and verified HEAD SHA.
- Use a per-finding status table, fresh `file:line` evidence, targeted gate results, and a clear verdict.
- Do not leave a public chain of "review → correction → correction #2".
- Verify the note by reading it back and return its direct URL.

## Approval and merge workflow

Only after the user explicitly requests approval/merge:

1. Fetch MR metadata again. Abort or re-review if `head_sha` changed since the last review.
2. Confirm state is `opened`, `draft` is false, blocking discussions are resolved, MR is mergeable, and the latest pipeline for the current SHA is successful.
3. Approve with the exact current SHA when the API supports it. This prevents approving a stale tip.
4. Merge with the repository's intended cleanup policy. For normal teammate MRs, use `should_remove_source_branch: true`; do not enable auto-merge unless the user asks for it.
5. Read back the MR after the mutation and verify:
   - `state == merged`
   - `merged_by` is the expected authenticated user
   - `merge_commit_sha` is present
   - target branch is correct
   - source-branch removal policy was applied
6. Report the MR URL, final state, and merge commit SHA. Never say "merged" from an unverified tool response or a queued auto-merge request.

## Post-merge cleanup

After successful merge, execute these steps in order:

1. **Fetch origin** — `git fetch origin` to sync all refs.
2. **Update linked issue** — Use MCP `update_issue` to:
   - Add "## Shipped" section with MR URL, merge commit SHA, merge date.
   - Set `state_event: "close"` (not delete — close means "released", delete means "never existed").
3. **Sync local develop** — `git checkout develop && git pull --ff-only`.
4. **Delete local feature branch** — `git branch -D <branch>` (force OK since remote branch is already removed via `should_remove_source_branch: true`).
5. **Verify clean state** — `git status` should show clean, `git log --oneline -1` should show the merge commit.

Do NOT skip step 2. An open issue after merge creates confusion in milestone tracking and release notes.

## Sub-agent limitation

Sub-agents dispatched via `delegate_task` using opencode-go or similar models **cannot access GitLab MCP tools** (HTTP 403). Do not dispatch MR review to sub-agents when the goal requires `get_merge_request`, `get_merge_request_diffs`, or other GitLab MCP calls. Instead:
- Use `git fetch origin <branch>` + `git show origin/<branch>:<path>` for file reads (works in any model).
- Use `git diff origin/develop...origin/<branch>` for diff inspection.
- Reserve sub-agents for analysis tasks that don't need MCP access.

## Safety and anti-patterns

| Don't | Do instead |
|---|---|
| Approve because an earlier review said "Approve" | Require the user's explicit current instruction and re-check the SHA |
| Merge with `merge_when_pipeline_succeeds` by default | Merge immediately only when current pipeline is already successful; otherwise ask or wait |
| Trust the fix commit title | Inspect the actual diff and re-check every prior item |
| Review local `develop` | Verify the MR source branch and SHA |
| Post a second correction note without removing the first | Delete and replace one consolidated note |
| Report a successful merge without a final read-back | Verify `state`, `merged_at`, `merge_commit_sha`, and `merged_by` |
| Treat generated-package artifacts as source regressions | Run the documented infra build first, then rerun gates |
| Dispatch MR review to sub-agents using opencode-go | Use git commands directly; sub-agents get 403 on GitLab MCP |
| Skip post-merge issue update | Always close issue with shipped info after merge |

## References

- `references/re-review-approval-merge-checklist.md` — compact checklist and evidence template for the full lifecycle.
