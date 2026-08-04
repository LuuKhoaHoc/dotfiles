---
name: remote-mr-verification
description: Fetch a merge request diff from a remote git host (GitLab) via the gitlab MCP server and cross-verify it against a local checkout before reviewing. Use when reviewing an MR/PR whose diff is large or cross-cutting (shared libs, barrel re-exports, shared constants) and you must catch breaking removals and hidden blast radius that a diff-level glance misses. Pair with `pr-review` for the review lens itself.
---

# Remote MR Verification

A diff is only as trustworthy as what it doesn't show. This skill covers the
**mechanics** of pulling an MR diff from a remote host and cross-checking it against a
local checkout. It does NOT cover the review lens (use `pr-review` for that).

## When to Use

- User asks to review a GitLab MR / PR (e.g. `gitlab.vppos.vn/.../merge_requests/470`).
- The change touches shared packages, barrel re-exports, or shared constants —
  i.e. its blast radius is wider than the file list suggests.

## Step 1 — Pull the diff via the `gitlab` MCP server

Tools are `mcp__gitlab__*` (server name `gitlab`). It is **flaky**. Full gotchas,
exact error strings, and the retry pattern are in
`references/gitlab-mcp-and-local-verification.md`. Essentials:

- `project_id` is the **numeric** id (e.g. `vppos-team/erp-admin` → `"9"`), passed as string.
- MR tools take **snake_case** keys: `merge_request_iid`, `project_id`. Passing
  `mergeRequestIid` yields a misleading `"project_id is required"`. Always pass both.
- `get_merge_request_diffs(project_id, merge_request_iid, excluded_file_patterns)` —
  exclude lockfiles.
- `list_merge_request_changed_files` for the file list without diff noise.
- On `"MCP server 'gitlab' is unreachable ... Auto-retry available in ~58s"` →
  wait ~60s, then retry. Do not retry immediately.

## Step 2 — Local cross-verification (the real value-add)

Cross-check the diff against a local checkout of the **target branch** (pre-merge,
e.g. `erp-admin/`). Use `search_files`, never the terminal for grep.

Checklist (detail + commands in the references file):

1. **Removed re-exports break unseen consumers.** If the MR deletes a barrel re-export
   (e.g. dropped `export { formatDateShort } from '@hilo/shared'`), grep every app for
   `from '@/shared/utils'` / `@hilo/shared/utils` consumers and confirm each consumer is
   itself in the MR's changed-file list. A consumer NOT in the list = broken import after merge.
2. **New imports must be reachable through the public barrel.** Verify each newly
   imported symbol exists and is re-exported by the package root (`index.ts`,
   `constants/index.ts`, `utils/index.ts`) — don't trust the diff to compile.
3. **Shared-constant blast radius.** Changing a shared constant (e.g.
   `DEFAULT_LIST_VIEW_PAGE_SIZE` 10→100) silently changes every default list that reads
   it via `useState`/URL-state. Flag for owner/BA sign-off + backend capacity.
4. **DTO-first leak check.** If formatting is moved out of an adapter into columns,
   grep all other consumers of the now-raw field type (CSV export, print, detail
   dialog, server attachment lists) for direct rendering that would leak ISO values
   or empty metadata.
5. **Shared-component prop changes blast radius.** If an MR changes a component in
   `packages/ui` or `packages/shared` props interface, grep the entire repo for all
   consumers — not just the ones in the MR's changed-file list. A required prop becoming
   optional is usually backward compatible; a prop being removed/renamed is NOT. Also
   check the package barrel `index.ts`: a newly exported type becomes part of the public
   API immediately. (Example: MR !473 changed `DocumentUploadList` `files` from required
   to optional and added `attachments`. Grep showed 15+ consumers across `apps/employee`,
   `apps/hr`, `apps/shell`; all used `files={...}` → backward compatible, no break.)

### E. Shared-component prop interface changes — grep ALL consumers
If an MR changes a component's props interface in `packages/ui` or `packages/shared`,
grep the entire repo for importers **outside the MR's changed-file list** too. Example:
MR !473 changed `DocumentUploadList` `files` from required to optional and added
`attachments`. Grep showed 15+ consumers across `apps/employee`, `apps/hr`, `apps/shell`;
all used `files={...}` only → backward compatible. A prop being removed or renamed would
break callers, even if only 2 files are in the MR.

Also check `packages/<pkg>/src/index.ts` barrel export: a newly exported type/interface
becomes part of the public API immediately.

### F. Batch async patterns in mutations
If an MR uploads multiple files concurrently:
- `Promise.all` is the wrong default when each upload is independent and partial failure
  is acceptable. Use `Promise.allSettled` + per-item retry or cleanup.
- Boolean `isUploading` flags for concurrent operations are race-prone. Use a counter
  (`number`) so each concurrent operation increments/decrements safely. (MR !473 had this
  exact race: file1 uploads → flag=true → user selects file2 → flag overwritten true →
  file1 completes → flag=false while file2 still uploading → UI allows save without file2.)

## Step 3 — Be honest about unverified env

If the repo pins `node` 22 + `pnpm@11.1.3` and they're absent, do NOT fabricate
build/typecheck/test results. State clearly they were not run and list the exact
commands from the repo `AGENTS.md`.

## Step 4 — Post review comments in the right shape

Vietnamese, structured: 📋 overview · ✅ điểm tốt · ⚠️ rủi ro by severity /
P0-P1-P2 · 🟡 follow-up · 🎯 verdict.
When the user responds with shorthand like "A nhé" / "B nhé", post the review
comment immediately instead of asking again.

See `references/gitlab-mcp-and-local-verification.md` for the full recipe.

## GitLab-specific review notes

- `mcp__gitlab__get_merge_request_diffs` output can be very large. Exclude lockfiles and assets with `excluded_file_patterns`.
- Some changed paths appear as `"new_file": true` even when the file already exists in the base branch. Verify intent from the diff content before treating it as brand-new.
- For style/locale/config files, prefer reviewing via `get_file_contents(..., ref=<branch>)` rather than inferring from the raw diff, because meaningful content is often collapsed/truncated.
- `merge_status` may be `mergeable` even if commit policy is not yet finalized; review still needs backward-compatibility checks for shared consumers.
