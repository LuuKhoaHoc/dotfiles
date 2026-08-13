# Re-review, Approval, and Merge Checklist

## Re-review evidence block

```text
MR: !<iid>
Source branch: <branch>
Previous reviewed SHA: <old sha>
Current HEAD: <new sha>
Pipeline: <pipeline/status>

Prior findings:
- <finding>: ✅ FIXED / ❌ STILL OPEN / ↩️ VOID — <file:line evidence>

Gates:
- targeted tests: <real result>
- typecheck: <real result>
- lint/format: <real result>
- build: <real result>
- diff check: <real result>

Verdict: Approve / Request changes / Needs discussion
```

## Approval + merge preflight

- [ ] User explicitly requested the side effect.
- [ ] MR is still open and non-draft.
- [ ] Current `head_sha` equals the SHA just reviewed.
- [ ] Blocking discussions are resolved.
- [ ] MR is mergeable and the latest pipeline for this SHA is successful.
- [ ] Approve with the exact current SHA.
- [ ] Merge immediately; do not schedule auto-merge unless requested.
- [ ] Remove the source branch when that is the repository/user convention.

## Post-action read-back

Verify and report all of:

- `state == merged`
- `merged_by` is the expected authenticated user
- `merged_at` is present
- `merge_commit_sha` is present
- target branch is correct
- source branch removal policy was applied
- direct MR URL

## Hilo ERP worked pattern

For `vppos-team/erp-admin` dashboard MRs, the focused gate set is:

```bash
pnpm --filter hr-dashboard exec vitest run src/features/dashboard
pnpm --filter hr-dashboard typecheck
pnpm --filter hr-dashboard build
pnpm --filter hr-dashboard exec eslint <changed-files>
pnpm --filter hr-dashboard exec prettier --check <changed-files>
git diff --check
```

If a detached/fresh worktree has no generated package declarations, run `pnpm build-infra` first. A missing `packages/*/dist` artifact is setup state, not evidence of a source regression.

## Clean-note convention

When the user prefers one consolidated review note, delete the previous consolidated note before posting the re-review note. The replacement should tag the author, name the verified branch and SHA, show a per-finding status table, and include the direct note URL after read-back verification.
