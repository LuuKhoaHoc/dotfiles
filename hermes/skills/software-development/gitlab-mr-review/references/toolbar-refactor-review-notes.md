# URL-state / DataTable-toolbar refactor review notes (erp-admin)

Session-specific detail from reviewing MR !514 (`feat/hr-data-table-search-date-filter`, 92 files) and
from inspecting shared infra on the branch. Reuse these locations and caveats when reviewing any
MR that wires search/date filters or list URL state in this monorepo.

## Shared utilities — where they live (inspect from the MR branch, not local)

- `optionalDateParam` — `packages/shared/src/schemas/list-query.ts`. `z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional().catch(undefined)`.
- `createSharedListUrlStateSchema`, `buildSharedListQueryRequest`, `omitEmptySearchParam`, `sharedListQueryDefaults` — same file. Adds base keys `page`, `pageSize`, `q` (and `includeInactive` for the query variant).
- `useUrlState` — `packages/shared/src/hooks/useUrlState.ts`. **`setState` accepts a functional updater, but it calls `newState(state)` with the CLOSURE `state` of the current render — not the freshest `prev` from `setSearchParams`. Stale-closure risk if `setState` is invoked twice in the same tick.** Also: `setState` deletes any URL key whose value is `''`/`null`/`undefined`; non-schema keys are kept only if non-empty.
- `useDebouncedSearch` — `packages/shared/src/hooks/useDebouncedSearch.ts`. Returns `{inputValue, setInputValue, debouncedQuery}`. Edge: when `externalValue` becomes `undefined` it does NOT reset `inputValue` (only syncs back when `externalValue !== undefined`).
- `initUrlStateDefaults`, `DEFAULT_LIST_VIEW_PAGE_SIZE` — `packages/shared/src/hooks/initUrlStateDefaults.ts` / constants.

## Typical MR shape (the "URL-state toolbar refactor")

Repeats across every HR list feature:
1. `use{X}UrlState` adds `fromDate`/`toDate` (usually via `optionalDateParam`) + `setSearch`/`setDateRange`/`setQuery`, often wrapping an object in `createSharedListUrlStateSchema` or replacing a hand-rolled `z.object`.
2. Data-source hook threads `q`/`fromDate`/`toDate` into the query and re-exposes the setters.
3. Component flips `showToolbar` on and passes `searchValue`/`onSearchChange`/`dateRange`/`onDateRangeChange` (using `useDebouncedSearch` to bridge local input ↔ URL state).

## Review traps specific to this refactor (all found in MR !514)

- **Dead props** — parent wires the toolbar; child only adds props to its interface but never destructures/renders/uses them (`OrganizationDashboardView` → all org tabs). Verify the child's full body, not the interface diff.
- **Mock no-op filter** — date filter keys off `createdAt`/`updatedAt` added as optional to the row type, but the mock rows never set them (`AttendanceRemindersSection` / `attendance-reminder-data.ts`) → filter always passes.
- **Missing `searchPlaceholder` i18n keys** — `showToolbar` enabled with `searchPlaceholder={t('features.X.filters.searchPlaceholder')}` but key absent from `en`+`vi` → placeholder shows the raw key. 7 features hit in !514.
- **Inconsistent persistence** — within one view, some tabs use URL state for search/date while sibling tabs use local `useState` (Attendance Config: Reminders = URL, Locations/Policy = local) → filters lost on tab switch/reload; note the inconsistency.
- **Over-aggressive reset** — `setSearch`/`setDateRange` also reset unrelated filters (e.g. `useAttendanceUrlState` resets `employeeId`+`status` to default) while the separate `setFromDate`/`setToDate` do not; a user's selected employee filter silently clears when they type or pick a range.
- **Inconsistent date-param helper** — one hook hand-rolls the inline regex instead of `optionalDateParam` (`useWorkScheduleConfigUrlState`) — same semantics, flags a nitpick only.
- **Functional-updater inconsistency** — one setter uses `setState((prev)=>…)` while the rest pass objects (`useRequestManagementListUrlState.setStatus`) — combine with the `useUrlState` closure caveat above.

## Data-semantics regression pattern (leaveDays)

`useLeaveRequestDataSource.ts` changed the displayed leave days from `totalDays * WORKING_HOURS_PER_DAY` to
`(endTime - startTime) / 60`. Both `totalDays`, `startTime`, `endTime` exist on
`OrganizationRequestLeaveDetail` (apps/hr/src/shared/types/organization-request.ts), so no crash — but a
multi-day leave now shows only ONE day's hour span (e.g. 3 days 08:00–17:30 → 9.5h instead of 24h).
When a MR swaps a `totalDays`-derived calc for a time-range calc, check multi-day handling explicitly.

## Cross-MFE blast radius

`apps/employee/.../RequestCreateDialog.tsx` changed in an HR-focused MR: removed custom
`getApiErrorMessage` + `tCommon('errorCodes.${code}')` translation in favor of only
`getApiErrorDisplayMessage`. Flag it as cross-app scope creep and confirm the shared helper already
handles code translation internally before accepting the behavior change.
