# Attendance/Payroll Freeze — Review Notes (MR !540)

Feature class: employee-scoped status-toggle with **required reason + history events + cache sync** (Cường's spec family — sibling: delete/restore). Review date 2026-08-05, head `df0f2b52`, branch `feature/hr-freeze-unfreeze-employee`, 30 files, no conflicts, trivy ✅ / sonarqube ❌ (infra, see SKILL §8c).

## Verified-good checklist (what passed, no need to re-check unless branch changes)

- **API layer**: 3 dumb functions in `apis/employee.ts` returning `ApiResponse<T>` — T=`EmployeeDetailDto` (freeze/unfreeze POST, body `{reason}` only) and `EventDto[]` (GET events). No try/catch, no transform. ✅ envelope contract.
- **Shared**: endpoints + query keys in `packages/shared` (`/hr/employees/{id}/attendance-payroll-freeze|unfreeze|freeze-events`), endpoints.test.ts added. ✅
- **i18n**: 57/57 keys en+vi (verify script), incl. error codes `HRM-400-1250/1251` in common.json. Namespace `features.employee.*` — consistent with existing feature (not flattened per AGENTS.md, but that's feature-wide pre-existing, 🟢 not MR issue). The 3 two-arg keys script reported missing were pre-existing on develop (SKILL §7 trap).
- **4 UI states** in history: Skeleton / error+Retry(`refetch`) / empty / success. History dialog lazy-fetches (`enabled={open}`).
- **Role gate**: `hasRole(user, [ROLES.HR_MANAGER])` in ViewWrapper + Section — matches `PermissionGuard` HR_MANAGER in EmployeeHeader. History view NOT gated (always available) — per spec.
- **Cache sync pattern** (the distinctive part): mutation `onSuccess` → `setQueriesData` patch list (handles BOTH shapes of `EmployeeListResponseData` = `ItemDto[] | Record<string,ItemDto>` — dual-shape loop) + patch detail (merge `{...previous.data, ...detail}`) → invalidate list/detail/events → **re-patch after invalidate** so a refetch payload omitting `attendancePayrollFrozen` can't wipe the badge. This is the repo-correct answer to "list omit field".
- **Double-submit**: dialog buttons `disabled={isPending}` + `loading={isPending}`.
- **Detail data**: new `useEmployeeDetailDto` hook (raw `response.data` via select) shares the SAME query key as old `useEmployeeDetail` (which selects through form-values adapter) — no duplicate fetch; used by JobInfoTab for the freeze section. Verify `EmployeeDetailDialog` passes `employeeId` to tab components (it does — `HR_TAB_COMPONENTS[tabId]` render site).
- **Tests**: apis spec (path+body only reason), events hook spec (QueryClientProvider wrapper), schema spec (trim/min-1), endpoints.test.ts.

## Round 2 status (2026-08-05, head `35cd9ed5`, 31 files) — all round-1 items CLOSED

- 🟡 Edit-mode gate → ✅ `{employeeId && isView ? <FreezeSection/> : null}` (JobInfoTab L190, commit `ca724dbe`).
- 🟡 Mutation spec → ✅ `useEmployeeAttendancePayrollFreezeMutation.spec.tsx` added (3 tests: array list + detail + re-patch after invalidate, Record shape, unfreeze). All 4 HR spec files 11/11 pass + endpoints 8/8 at exact head (worktree), pipeline ✅.
- 🟢 Issue link → ✅ description now cites #128.
- Note: `resolve_merge_request_thread` on the round-1 thread returned **403 Forbidden pre-merge too** (not just post-merge) — the summary note was updated to ask for manual resolve; don't chase the token.

## Re-review recipe for this MR

```bash
git fetch origin feature/hr-freeze-unfreeze-employee develop
git rev-parse origin/feature/hr-freeze-unfreeze-employee   # == new head_sha?
git log <old-head>..origin/feature/hr-freeze-unfreeze-employee --oneline   # what changed
git grep -n 'EmployeeAttendancePayrollFreezeSection' origin/feature/hr-freeze-unfreeze-employee -- apps/hr/src   # edit-mode gate added?
git ls-tree -r --name-only origin/feature/hr-freeze-unfreeze-employee -- apps/hr/src/features/employees/hooks/ | grep -i freeze   # mutation spec added?
```
