# HR List-View Search / Date-Filter Review Checklist (MR !514)

When an MR adds search + date-range filters to many HR list views at once, review each feature through this chain. A filter is only real when the **entire chain** is wired; a break at any link renders the toolbar inert while the URL changes.

## The wiring chain to trace per feature

```
DataTable toolbar prop (searchValue/dateRange/onSearchChange/onDateRangeChange)
  → url-state setter (setSearch / setDateRange) resets page to 1
  → data-source hook reads q/fromDate/toDate from url-state
  → query params sent to API (or client-side mock filter)
```

### Checklist (each = potential 🔴/🟡)

1. **Dead props** — child tab adds new props to its `interface` but never destructures/uses them, and never sets `showToolbar`. Parent passes them; child ignores. `git grep` the child's full body for the prop name.
2. **Filters don't reach query params**
   - API mapper drops them (e.g. `change-management.api.ts` `getChangeManagementRequestParams` destructures `{page, pageSize, q, status, changeType, tab}` but omits `fromDate`/`toDate`).
   - Shared query builder strips them (see below — the big one).
   - url-state adds `fromDate`/`toDate` + `setDateRange` but NO component passes `dateRange` to a DataTable or reads the dates into a query → **dead state** (real case: organizations dashboard — `useOrganizationUrlState` adds `fromDate`/`toDate`/`setDateRange`, but `OrganizationDashboardView` only destructures `q`/`setQuery` and no org tab query includes the dates).
3. **Mock data missing fields the filter depends on** — filter keys off `createdAt`/`updatedAt`/`submittedDate`/`participationStartDate`; confirm the mock rows actually populate that field and in the format the parser expects (e.g. offboarding parses `dd/MM/yyyy`; insurance parses `dd/MM/yyyy`; reminders use ISO with offset). Missing → `matchDate` always true → filter no-op.
4. **Mock rows not filtered at all** — mock builder just `rows.slice(start, start+pageSize)` and never applies `q`/`fromDate`/`toDate` (real case: attendance timesheet `buildMockRowsState`). Search/date UI shows but data never changes in mock mode.
5. **setter clears OTHER active filters** — `setSearch`/`setDateRange` that also reset `employeeId` + `status` to defaults silently wipes filters the user already applied (real case: `useAttendanceUrlState.setSearch`/`setDateRange`). Should only set `{q|dates, page:1}`.
6. **Unused imports after edit** — the diff removed a raw search `Input`/`SearchNormal1` and local `useState('')` query in favor of `useDebouncedSearch`; verify the old imports are gone.
7. **i18n keys** — every new `t('features.X.filters.searchPlaceholder')` (and `fromDate`/`toDate` labels) must exist in BOTH `en` and `vi`. See §7 of SKILL.md for the nested-JSON traversal (dotted grep lies).
8. **Page reset to 1 on filter change** — every `setSearch`/`setDateRange` must set `page: 1`; if a removed `useEffect` that reset page on `q` change is deleted, confirm the new setters still reset the page (else the user lands past the end of the filtered result).
9. **URL vs local state consistency** — reminders section uses URL-state (`reminderQ` etc.) while locations/policy sections in the same view use `useState` — inconsistent, and local state loses filters on back/deep-link (violates AGENTS.md "URL query params as source of truth").

## The `buildSharedListQueryRequest` zod-strip gotcha (root cause of most date no-ops)

`packages/shared/src/schemas/list-query.ts`:
- `sharedListQuerySchemaShape` = `{page, pageSize, q, includeInactive}` only.
- `normalizeSharedListQuery(input)` = `sharedListQuerySchema.parse(input)`.
- `buildSharedListQueryRequest(input)` = spread of that normalized result + trimmed `q`.

zod's `z.object().parse()` (non-strict) **silently drops unknown keys**. So `buildSharedListQueryRequest({page, pageSize, q, fromDate, toDate})` returns an object WITHOUT `fromDate`/`toDate`.

**Probe (deterministic):**
```bash
node -e "const {z}=require('zod'); \
const s=z.object({page:z.number().default(1),pageSize:z.number().default(10),q:z.string().default('')}); \
console.log(JSON.stringify(s.parse({page:1,pageSize:10,q:'a',fromDate:'2026-01-01',toDate:'2026-01-31'})))"
# → {"page":1,"pageSize":10,"q":"a"}   (fromDate/toDate gone)
```

**Affected in MR !514** (all route dates through `buildSharedListQueryRequest`): `attendance-location.ts`, `attendance-policy.ts`, `take-leave-config.ts`, `work-request-config.ts`, `weekly-shifts.ts`, `work-shifts.ts`.

**Fix pattern:** add `fromDate`/`toDate` to the shared schema shape, OR spread the date fields directly into the axios `params` object instead of inside `buildSharedListQueryRequest` (as `request-management.ts`/`time-off-management.ts` do by passing `params` straight through).

**Secondary variant — per-feature API mapper:** even when dates reach the query hook, the feature's own param-mapping function can drop them (change-management's `getChangeManagementRequestParams`). Check the last function that builds the actual HTTP params.

## DataTable semantics that make filters look wired but do nothing

`packages/ui/src/components/ui/DataTable.tsx`:
- `isServerSearch = searchValue !== undefined && typeof onSearchChange === 'function'` — when true, **no client-side filtering**; the table relies entirely on the upstream data source having filtered by `q`.
- `dateRange` is forwarded only to the toolbar's `DateRangePicker` — **DataTable never filters rows by date**. Date filtering must happen in the data source / API / client-side mock.
- `showToolbar` is what actually renders the toolbar; `showToolbar={false}` (the old default) hides search+date entirely.
