# GitLab MCP + local cross-verification — full recipe

From an MR review of `vppos-team/erp-admin` (gitlab.vppos.vn). Repo: pnpm + Turborepo
MFE monorepo, root `AGENTS.md` pins `node` 22 + `pnpm@11.1.3`, no `pnpm test` at root.

## 1. Pull the diff via `gitlab` MCP

Tools: `mcp__gitlab__get_merge_request_diffs`, `mcp__gitlab__list_merge_request_changed_files`,
`mcp__gitlab__approve_merge_request`, `mcp__gitlab__merge_merge_request`, etc.

### Schema gotchas (recurring)
- `project_id` is numeric string: `vppos-team/erp-admin` → `"9"`.
- Keys are snake_case: `merge_request_iid`, `project_id`.
  - `mergeRequestIid` → `"project_id: project_id is required"` (misleading).
  - `merge_request_iid` w/o `project_id` → `"Either mergeRequestIid or branchName must be provided"`.
  - Always send both.
- `get_merge_request_diffs(project_id, merge_request_iid, excluded_file_patterns)` →
  exclude lockfiles: `["package-lock.json","yarn.lock","pnpm-lock.yaml",".*.lock"]`.
- `list_merge_request_changed_files(project_id, merge_request_iid)` → file list only.

### Server unreachable
`"MCP server 'gitlab' is unreachable after 3 consecutive failures. Auto-retry
available in ~58s."` → `sleep 65` then retry. Don't hammer it.

## 2. Local cross-verification against `erp-admin/` (develop, pre-merge)

Use `search_files` (path-grouped mode lists file + matched lines).

### A. Removed barrel re-export → broken consumers
Grep `from '@/shared/utils'` and `from '@hilo/shared/utils'` across `apps/`.
If the MR drops `export { formatDateShort, formatDateTimeShort } from '@hilo/shared'`
in `apps/employee/src/shared/utils/index.ts`, every employee file importing those from
`@/shared/utils` must also be in the MR. Cross-reference with `list_merge_request_changed_files`.
(In MR !470 all 6 employee consumers were inside the MR → safe.)

### B. New symbols reachable via public barrel
`@hilo/shared/src/index.ts` re-exports `./utils/*` and `./constants`; `constants/index.ts`
re-exports `./common`. So importable `from '@hilo/shared'`: `formatDate`, `formatDateTime`,
`formatDateValue` (utils/datetime), `DEFAULT_LIST_VIEW_PAGE_SIZE`, `PLACEHOLDER_STRINGS`
(constants/common). Verify with `search_files` before trusting the diff compiles.

### C. Shared-constant blast radius
`DEFAULT_LIST_VIEW_PAGE_SIZE` 10→100 (MR !470). Grep shows it's consumed by many lists
via `useState`/`urlState`: HR request-management, renewals, orders, dossiers, employee
leave, ReportsDataTable, websocket event-routing. All default lists jump to 100/page after
merge → needs owner/BA confirmation + backend paging capacity. `LIST_VIEW_PAGE_SIZE_OPTIONS
= [10,20,50,100]` keeps 10 selectable, so not blocking.

### D. DTO-first adapter move → raw-value leak
`request-management.adapter` stopped calling `formatDate()` and returned raw ISO for
`submittedDate`/`reviewedDate`; the column wraps `formatDate()`. Grep all consumers of
`RequestManagementListItem.submittedDate`/`reviewedDate` (CSV/print/detail, server
attachment lists) to ensure none renders ISO directly.

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

## 3. Unverified env
No node22/pnpm → don't fake results. List from AGENTS.md:
```bash
pnpm --filter @hilo/shared test
pnpm --filter @hilo/shared typecheck
pnpm --filter hr-dashboard typecheck
pnpm --filter employee typecheck
pnpm --filter sale typecheck
```
State build/typecheck were NOT run.
