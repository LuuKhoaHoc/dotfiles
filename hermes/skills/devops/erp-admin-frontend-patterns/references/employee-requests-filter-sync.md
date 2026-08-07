# Worked example: employee requests — 4-tab filter sync + filter button relocation (issue #153, 2026-08-06)

Context: `apps/employee/src/features/requests` had 4 tabs (`all`/`pending`/`approval`/`handled`).
Tabs `approval` + `handled` (new) were missing the requestType filter section that `all`/`pending` had,
and the filter trigger sat in the DataTable toolbar instead of next to the "Tạo đơn" header button.

## 1. Shared filter config (new)

`features/requests/constants/requests-filters.ts`:
- `REQUEST_TYPE_FILTER_OPTIONS: readonly { value, labelKey }[]` — 9 options, `labelKey` = `requests.types.*` i18n keys (labels NOT resolved in constants — resolve in the builder via `t`).
- `getRequestsFilterCategories(t: (key: string) => string): TableFilterCategory[]` — single category `general` with `sectionIds: ['search', 'requestType', 'dateRange']`.
- `getRequestsFilterSections(t)` — search (id `q`), requestType (id `type`, select), dateRange (id `dateRange`).
- Both `t`-typed builders work with `useTranslations('employee').t` (verified assignable).
- Test `constants/requests-filters.test.ts` locks: category sectionIds == section ids; section order; `type` field id/type; option values unique with `all` first.

Consumers (both replaced local useMemo categories/sections):
- `components/RequestsTable.tsx` (tabs all/pending)
- `components/RequestsTableShell.tsx` (shell for ApprovalInboxTable + HandledRequestsTable)

## 2. Per-tab URL state for the type filter

`hooks/useRequestsUrlState.ts` — approval/handled previously hard-pinned `currentType = 'all'` and dropped `type` from `setFilters`:
- Schema: add `approvalType` + `handledType` (`z.string().catch(DEFAULT_REQUESTS_TYPE).default(DEFAULT_REQUESTS_TYPE)`).
- `currentType` becomes tab-aware (`approvalType`/`handledType`/`myType`).
- `setType` no longer guards early-return for approval/handled — it sets the active tab's key + resets that tab's page.
- `setFilters` approval/handled branches add `approvalType`/`handledType: filters.type ?? DEFAULT_REQUESTS_TYPE`.
- `approvalParams`/`handledParams` add `...(state.approvalXType === DEFAULT_REQUESTS_TYPE ? {} : { requestType: state.approvalXType })` + deps.

## 3. Trigger relocation (header slot)

- `RequestsHeader.tsx`: new prop `actions?: ReactNode` rendered in the right-side flex BEFORE the create button.
- `RequestsOverview.tsx`:
  - `const [filterOpen, setFilterOpen] = useState(false);`
  - `activeFilterCount = (q?.trim()?1:0) + (type && type !== 'all' ? 1 : 0) + (fromDate || toDate ? 1 : 0)` — `type` is tab-aware so the count is correct on every tab.
  - `handleTabChange(value)` = `setFilterOpen(false)` + `setStatus(value)`; wired to `Tabs onValueChange`.
  - Header renders `<EmployeeFilterTriggerButton activeCount ariaLabel={t('requests.filters.panelTitle')} onClick={() => setFilterOpen(true)} />` in the `actions` slot.
- Tables: `RequestsTable`/`ApprovalInboxTable`/`HandledRequestsTable` + `RequestsTableShell` replace internal `useState(false)` with `filterOpen`/`onFilterOpenChange` props; trigger removed from `toolbarExtra`; `TableFiltersPanel` stays in the table/shell.
- Shell `filterValues`/`onApplyFilters` widened to include `type?: string`; `currentFilterValue` adds `type: filterValues.type ?? 'all'`; onApply maps `type` like RequestsTable does.

## 4. Review-fix notes from the same session

- Column-cell dedup: extracted `RequestTypeTimeCell` (~50-line cell, 3 copies) but kept `employeeName || '-'` inline (1-line, 2 copies) after user pushback ("tại sao phải tạo component RequestEmployeeCell").
- `HandledRequestsTable` ≈ `ApprovalInboxTable` clone → extracted `RequestsTableShell` (DataTable + TableFiltersPanel + DefaultPagination), both tables became thin wrappers (props unchanged for ApprovalInboxTable so its existing test stayed green).
- Decision-info lookup in `useHandledRequestsColumns`: use `[...approvals].reverse().find(a => a.status === request.status) ?? approvals[approvals.length - 1]` — the original `|| a.decidedAt || a.decisionNote || a.decidedByName` clause effectively always returned the LAST approval even when its status disagreed with the request's final status.
