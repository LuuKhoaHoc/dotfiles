# TableFiltersPanel migration review notes (erp-admin, MR !529)

Session detail from reviewing MR !529 (`feat/hr-issue-122-table-filters-panel`, 80 files,
3314+/1584−, QuyCN). The MR class: migrate HR list views from DataTable toolbar search/dateRange +
hand-written filter dialogs to the shared `TableFiltersPanel` from `@hilo/ui`
(`packages/ui/src/components/customs/TableFiltersPanel.tsx`, API: `categories / sections / value /
onApply`, field types: search, input, select, async-select, multiselect, checkbox-list, date,
date-range). The component ALREADY existed on develop (used by dashboard/payroll) — check
`git log origin/develop -- packages/ui/src/components/customs/TableFiltersPanel.tsx` before
assuming the MR introduces it.

## The checklist to run on ANY TableFiltersPanel migration MR

1. **Enumerate the panels**: `git diff --name-only <base>...<head> | grep 'FiltersPanel.tsx'`,
   then count `date-range` fields per panel (`grep -c "'date-range'"`). 9 of 10 panels in !529 had
   a date-range section — that's the highest-risk field type.

2. **Date serialization — enumerate per panel, don't trust the MR description**:
   `git show <head>:<file> | grep -n "toISOString\|formatDateValue"`.
   - `toISOString().slice(0, 10)` on a `Date` is WRONG in this repo: `DateSelectPicker` builds
     dates via `startOfDay` = `new Date(y, m, d)` (local midnight), so UTC serialization shifts the
     day back by the UTC offset (VN UTC+7 → always −1 day).
   - Re-apply-stability nuance (runtime probe, MR !531): whether an UNCHANGED range corrupts on
     re-apply depends on the panel's value-mapping parse. !529 panels parsed
     `new Date('YYYY-MM-DDT00:00:00')` (local) → toISOString re-serialization shifts −1 day EVERY
     apply, even re-applying unchanged. !531 panels parse `new Date('YYYY-MM-DD')` (UTC per
     ECMA-262 date-only form) → UTC-parse → UTC-serialize round-trips STABLE (no shift on re-apply),
     but a NEW pick from `DateSelectPicker` still serializes −1 day. So a stable re-apply in the
     browser does NOT clear the bug — the defect still corrupts every freshly-picked date.
   - Correct: `formatDateValue(date)` in `packages/shared/src/utils/datetime.ts` (uses local
     getFullYear/getMonth/getDate).
   - MR !529: 7/10 panels buggy (AttendanceListFiltersPanel:100-101, EmployeeFiltersPanel:98-99,
     AttendanceConfigDateFilterPanel:98-99, OrganizationConfigFiltersPanel:98-99,
     WorkRequestConfigFiltersPanel:98-99, WorkScheduleConfigFiltersPanel:98-99,
     OffboardingFiltersPanel:98-99) while the description claimed the fix was done; only
     ChangeManagement/TimeOff/RequestManagement panels used formatDateValue correctly.

3. **Date delivery — trace fromDate/toDate panel → URL state → query → api params**. No-op
   screens in !529 (date section renders, URL state updates, server never receives):
   | Screen | Drop point |
   |---|---|
   | Change management | `getChangeManagementRequestParams` (`apis/change-management.api.ts:33-44`) destructures only `{page,pageSize,q,status,changeType,tab}` — drops `fromDate`/`toDate` (type has them) |
   | Attendance locations / policy | `buildSharedListQueryRequest({..., fromDate, toDate})` → zod `sharedListQuerySchema` (`packages/shared/src/schemas/list-query.ts`, keys: page/pageSize/q/includeInactive) strips them |
   | Weekly shifts / work shifts / work-request config | same zod-strip (`weekly-shifts.ts:23-28`, `work-shifts.ts:21-26`, `work-request-config.ts:29`) |
   | Take-leave config | same zod-strip (no panel, but same api bug) |
   | Payroll periods status/unit | `buildListParams` (`salary-fund.ts:73-82`) keeps only `{page,pageSize,q,organizationId}` |
   Reference WORKING pattern: `getEmployeeList` (`employees/apis/employee.ts:74-75`) spreads
   `fromDate`/`toDate` AFTER `buildSharedListQueryRequest`. Also `request-management`/`time-off`
   pass `params` straight to axios → dates work.
   KEY LESSON: the 6 hrm-settings apis were flagged in the !514 review and NEVER fixed — the
   follow-up MR built new UI on the broken plumbing. Re-grep api params at branch tip every time.

4. **Client-side search emulation (fetch-all-pages)**: when BE lacks `q` for an endpoint, the
   queryFn fetches EVERY page via `Promise.all` (pageSize 100) then filters with
   `normalizeSearchText` (new shared util, `packages/shared/src/utils/string.ts` — NFD strip +
   đ→d, exported from `@hilo/shared`) and re-paginates client-side. 5 instances in !529:
   `getAllChangeManagementPages`, `fetchAllRequestPages` (×2: list + inbox),
   `getAllLeaveBalance`, `getAllLeaveRequests`. Acceptable at ~170 users; every search = full
   dataset fetch. Before accepting, check the BE contract: `q` exists on
   `OrganizationRequestsQueryParams` for the shared `/requests` endpoint — server-side search may
   simply be available.

5. **Double filter source**: MR description claimed 'Loại bỏ showToolbar... để tránh 2 nguồn
   filter song song' — but `RequestManagementViewWrapper` (toolbar `showToolbar={Boolean(onSearchChange)}`
   + panel) and time-off tabs (`LeaveRequestTab`/`LeaveBalanceTab` toolbar + panel) kept both.
   Both write the same URL `q` (no data bug) but contradict the stated goal. Grep changed files
   for `showToolbar` + `searchValue=`/`dateRange=` to find them.

6. **Removed-search ≠ lost search**: org tabs dropped toolbar search — NOT a regression because
   `OrganizationDashboardHeader` already had a `TableFiltersPanel` (pre-existing) whose search
   writes per-tab `q` via `useOrganizationDashboardHeaderFilters`. Before flagging 'feature
   removed with no replacement', grep the module for remaining `TableFiltersPanel`/`setQuery`.

7. **i18n** (see SKILL.md §7): run `verify_i18n_keys.py` with CHANGED FILES ONLY; the script
   misses two-arg `t('key','fallback')` forms (MR !529: 12 missing `dashboard.filters.*` keys
   rendered Vietnamese fallbacks in en UI). Missing salary labels in !529:
   `features.salary.filters.clearFilters/emptyOptions/multiSelectPlaceholder/
   multiSelectSearchPlaceholder` (PayrollPeriodDetailView labels, all other features got
   `filterPanel.*` blocks — salary didn't).

8. **Dead component cleanup**: deleted `ChangeManagementFiltersDialog`/`RequestManagementFiltersForm`
   had 0 remaining consumers (verify with `git grep <Name> <branch> -- apps/`). Dead props removed
   properly (payroll detail status/unit were `useState` never consumed — dead UI; org tabs' dead
   toolbar props).

## Things that were fine (don't re-flag next time)

- en/vi parity of added keys was perfect (identical added-key sets).
- `applyFilters` in URL-state hooks reset `page: 1` (incl. inbox key); attendance-config
  per-tab setters reset their own tab's page.
- Offboarding filter button was a 'coming soon' toast → now a real panel (mock data, client-side
  filter — functional).
- The `t('dashboard.filters.X', 'VN fallback')` pattern renders VN text for en users = 🟡-🔴;
  raw-key rendering only happens for single-arg missing keys.

## Employee MFE sibling — MR !531 (feat/employee-issue-123-table-filters-panel, 29 files)

The employee-MFE port of the same migration (7 screens: attendance history, adjustment
requests, org members, my requests, approval inbox, leave requests, directory). Findings
that EXTEND the checklist above:

**6/6 date-range panels re-introduced the `toISOString().split('T')[0]` bug** — the HR !529
fix pattern (`formatDateValue`) was NOT applied anywhere in the employee MR:
`AttendanceHistoryTable.tsx:297`, `AttendanceAdjustmentRequestListModal.tsx:418`,
`OrganizationMembersTable.tsx:146`, `ApprovalInboxTable.tsx:167`, `RequestsTable.tsx:204`,
`LeaveRequestsTable.tsx:195`. Lesson: a sibling-MFE port of an already-reviewed-and-fixed MR
commonly re-introduces the original bug — enumerate panels in EVERY MFE port; never assume
the fix pattern travels with the migration.

**TableFiltersPanel breaks every test that renders the component — new trap.** The chain is
`TableFiltersPanel` → `ResponsiveModal` → `useMediaQuery` → `window.matchMedia`, which jsdom
lacks → `TypeError: window.matchMedia is not a function` on render. The MR's own test
updates (renaming `dateRange`/`onDateRangeChange` → `filterValues`/`onApplyFilters`) are NOT
enough — both touched test files still failed. Fix: copy the `vi.stubGlobal('matchMedia', …)`
stub from `packages/ui/.../TableFiltersPanel.test.tsx:29-40` (or a shared setup file).

**Second trap — hooks that move from `useState` to `useUrlState` break UNTOUCHED tests.**
Data-source hooks now call `useUrlState` → react-router `useSearchParams`, so their
`renderHook` tests crash with `useLocation() may be used only in the context of a <Router>`
— wrap in `MemoryRouter` or mock the hook. In !531 the 2 touched test files AND 4 collateral
files (absent from the MR's changed-files list) failed: 16 new failures on head vs 9
pre-existing on base.

**Isolation recipe — run the FULL app suite at head AND base, diff the failing lists.** Use
`git worktree add /tmp/<mr> <head_sha>` (+ a second worktree at base_sha), symlink
`node_modules` from the main clone (per-package for `packages/*`; pnpm's workspace runner can
choke in detached worktrees on shell-rc noise, so invoke the binaries directly:
`./node_modules/.bin/tsc --noEmit` / `./node_modules/.bin/vitest run`). The base run is the
only reliable way to separate MR-introduced failures from pre-existing ones — and essential
because CI test jobs are COMMENTED OUT in this repo's `.gitlab-ci.yml` (test stage disabled),
so red tests never block merge and MR descriptions claiming "tests pass" are unverifiable
without a local run.

**verify_i18n_keys.py false-positive trap.** The script matches every `t('…')` key against
EVERY locale file; when keys live at a different JSON root than the script assumes (or the
namespace nests differently), its MISSING list floods with false positives (flagged ~15
`requests.*` / test-fixture keys — 'HR Specialist', 'asdfas', 'T' from `getByText(...)` — as
missing across all 14 locale files when they exist). Always re-verify suspected misses with
direct JSON traversal at the correct root, and check the BASE locale file to classify
pre-existing vs MR-introduced. CAUTION — the WRONG-namespace-level case is NOT a false
positive: in !531 the 10 `directory.filters.*` references in `DirectoryHeaderToolbar.tsx`
(lines 30, 40, 86, 115, 125-131, ns `employee`) were genuinely missing because the author
added the block at `features.directory.filters` — top-level `directory.filters` did NOT exist
(en+vi verified at head) and the added path had 0 consumers. A key "exists" only at the EXACT
dotted path the component references: `t('directory.filters.X')` ≠ `features.directory.filters.X`.
Dump both the top-level object keys and the `features.*` subtree before classifying. Real
pre-existing misses re-exposed by the rewritten modal: `requests.actions.delete/edit/submit/
viewDetail`, `requests.createAndApproveDateColumn` (locale has `requests.actionMenu.*` /
`requests.submitAndApproveDateColumn`) + 2 two-arg VN-fallback keys (`leave.requests.empty`,
`leave.requests.errorLoading`) + 1 object-form (`directory.toolbar.clearSearch`).

**URL-state hooks are the new regression surface — no tests were added for them.** The 4
new/rewritten hooks (`useEmployeeAttendanceHistoryUrlState`,
`useEmployeeAttendanceAdjustmentRequestListUrlState`, `useRequestsUrlState`,
`useLeaveRequestsUrlState`) carry all the page-reset/param-namespacing logic with zero unit
coverage. Suggested coverage: filter apply resets page to 1; setPageSize resets page;
malformed URL params `.catch()` to defaults; distinct param prefixes don't clobber each other
across co-mounted modals (history* vs adjustment*). A panel date-range apply test asserting
`onApplyFilters` receives LOCAL-serialized dates would have caught the 6-panel bug.

**Wrong-path locale key addition — added key with 0 consumers while the real missing key
stays missing** (real case, MR !531). The MR added `features.employee.import.actions.settings`
to `hr.json` (en+vi) with ZERO consumers (`ImportEmployeeDialog` only uses
`cancel/processing/import`) while the actually-referenced `features.employee.actions.settings`
(`apps/hr/.../employee-header/EmployeeHeader.tsx:112-113`) stayed missing in both languages →
raw key renders in the settings icon tooltip, the fix is ineffective, and it's out-of-scope
(employee-MFE MR editing an HR import-dialog locale). Detection: for EVERY added locale key,
`git grep -n '<key>' <branch> -- apps packages | grep -v translations` → 0 hits = dead; when a
"settings"-style key is missing and the MR adds a near-identical one, diff the paths
(`import.actions.settings` vs `actions.settings`) — the author placed it in the wrong subtree.
The object-form two-arg `t('key', { defaultValue: ... })` fallback (e.g.
`directory.toolbar.clearSearch`) is the same wrong-language trap as the string two-arg — now
detected by `verify_i18n_keys.py` (T_KEY_DEFAULT_OBJ_RE).

## MR !531 round 2 re-review (commit `62fd09be` "finalize table filter panel cleanup") — verified fixes + 2 new traps

The author answered the 3-🔴 review with ONE 27-file commit + a develop merge (head
`29581b58`). Round-2 verification results to reuse:

- **6/6 date panels fixed via ONE shared util** — `apps/employee/src/shared/utils/date-filter.ts`:
  `formatDateFilterValue(value?: Date)` wraps `formatDateValue` from `@hilo/shared`; all 6
  tables import it from `@/shared` (plus the new `EmployeeFilterTriggerButton` shared component).
  This is the GOOD fix shape for the repeated serialization bug: one MFE-local util wrapping the
  shared helper, not 6 inline copies. `git grep -n "toISOString" <head> -- <feature>/components/`
  → only non-filter uses remain.
- **matchMedia fix went into shared test infra** — `apps/employee/src/test-setup.ts` (+17) +
  `vite.config.ts` setupFiles wiring; NOT per-test stubs. Re-verify by running the previously
  failing files: `CI=true ../../node_modules/.bin/vitest run <files>` from `apps/employee` in a
  detached worktree → all green (5 files, 11 tests), then the FULL suite (46 files / 163 tests
  PASS) + `tsc -p apps/employee/tsconfig.json --noEmit` (exit 0). Full-suite run is the only
  proof the collateral test failures (files absent from the MR diff) are really gone.
- **Directory double-search fixed by REMOVING the panel** — `DirectoryHeaderToolbar` now has
  only the toolbar search input; `TableFiltersPanel` no longer exists anywhere in
  `apps/employee/src/features/directory/`. Legit simplification, BUT see dead-keys trap below.

**New trap — tab-namespace prefix completeness (naming asymmetry that still works):**
`useRequestsUrlState` after the fix namespaces correctly (`myQ/myPage/myType` +
`approvalQ/approvalPage/approvalFromDate/approvalToDate`) EXCEPT one param: My tab reads
`fromDate` (no prefix) paired with `myToDate`; `currentFromDate = isApprovalTab ?
approvalFromDate : state.fromDate`. It works (approval uses its own prefix, no leak) but is a
typo-class inconsistency — flag 🟡 with the literal fix (rename to `myFromDate` across schema +
`setDateRange` + consumer), framed as convention, NOT a bug. When reviewing namespaced URL
state, list EVERY param and check each has its prefix — asymmetry hides in pairs
(`from` unprefixed vs `to` prefixed).

**New trap — dead locale keys after removing a filter source (2-half fix):** the same fix
commit moved `directory.filters.*` to the correct top-level namespace (en+vi) AND removed the
panel that consumed it → the 9 keys are dead (0 consumers — `git grep "directory\.filters"
<head> -- apps/` empty). Grep consumer-side before crediting a locale fix: a namespace that is
now correctly-placed but unreferenced is bloat, not a fix. Half the fix (move keys) landed
without the other half (delete keys or keep the consumer). Also confirmed fixed: the
`features.employee.import.actions.settings` hr.json dead key was removed entirely.

