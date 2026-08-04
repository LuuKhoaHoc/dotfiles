---
name: hr-table-patterns
description: HR table patterns — sticky columns, search, filtering.
triggers:
  - add sticky columns to HR table
  - add search to HR table
  - client vs server filtering in HR
  - DataTable column pinning
  - HR table search filter
  - sticky left column DataTable
category: hr
---

# HR Table Patterns

## Filter Panel Classification (audit before adding filters)

To classify every HR list view's filter state (STANDARD / CUSTOM / NONE / SUB) and
report evidence file:line, or before standardizing a hand-written filter:

1. Trace panel usage: `grep -rn "XxxFilterPanel" --include="*.tsx" . | grep -v "own-file"` — panels can exist unused.
2. Follow the trigger chain: `*Header.tsx` Filter button → view → section ref
   (`useImperativeHandle` `openFilter`) → `<XxxFilterPanel open={filterOpen}>`.
   Alternative chain: store-driven open state (`useXxxUiStore` `filterOpen`/`setFilterOpen`)
   + shared header button — the panel must be MOUNTED in the active tab, otherwise the
   button is dead on other tabs (see `SalaryView`/`SalaryGradesListView`).
3. Watch for DEAD triggers (3 variants):
   - `openFilter: () => undefined` or `handleComingSoon('...filterComingSoon')`
     → header button visible but filter not implemented (cheapest tickets)
   - Filter button rendered with NO `onClick` at all (e.g. `EmployeeHeader.tsx:118-124`)
   - Component ACCEPTS `onOpenFilter` prop but never uses it (e.g. `PayrollPeriodsView.tsx:107`
     — shared header opens the flag, but `SalaryFundFiltersPanel` is only mounted in the
     salaryGrades tab, so the button is dead on payrollPeriods)
4. DataTable `dateRange`/`onDateRangeChange` props render the shared `DateRangePicker`
   toolbar — shared UI, NOT a custom filter; classify NONE, not CUSTOM.
5. Custom filter SHEETS count as CUSTOM even when well-built: `AttendanceTimesheetFilterSheet`
   (ResponsiveModal + Popover/Select/Checkbox, triggered store-side via
   `requestTimesheetFilter()` → `setIsFilterOpen(true)` in the detail view).

Full methodology + verified wiring locations + 2026-08 audit snapshot (Part A: attendances/
salary/dashboard/employees, Part B: remaining features):
`references/filter-panel-classification.md`.

## API-First Filtering Workflow

**Before implementing search/filter, TEST the API first.** The TypeScript params type may not reflect actual backend support.

### Steps

1. Check `*Params` type for existing filter params (`q`, `employeeIds`, etc.)
2. **Test with curl/Postman/Bruno** — verify the param actually filters
3. If API supports filtering → server-side (send param, refetch via React Query)
4. If API doesn't → client-side (filter loaded rows with `useMemo`)

### curl test pattern (cookie auth)

```bash
curl 'https://api-erp.vppos.vn/api/v1/endpoint?param=value' \
  -H 'Cookie: access_token=TOKEN; refresh_token=...; device_id=...'
```

Compare row count with and without the param to verify filtering works.

### Known API limitations (erp-admin)

| Endpoint | `q` param | `employeeIds` param |
|----------|-----------|---------------------|
| `/attendance-sheets/{id}` (timesheet detail) | ❌ Not supported | ❌ Not supported |
| `/payroll-runs/{id}/employees` (payroll detail) | ✅ Server-side | N/A |

**File:** `references/api-testing-patterns.md` has session detail.

## DataTable Sticky Columns

DataTable supports sticky **right** action column built-in. For sticky **left** columns, use column meta classes.

### z-index stacking order (critical)

```diff
DataTable headClassName:  z-30  (sticky top-0)
Column meta head:         z-40  (sticky left-0) ← MUST be higher than z-30
Column meta cell:         z-20  (sticky left-0)
```

`cn()` merge means column meta `headClassName` **overrides** DataTable's `z-30`. If you set `z-10` or `z-20` on the column head, it sits BEHIND the sticky header row when scrolling vertically.

**When implementing sticky columns, prefer at least `z-30` on heads and `z-20` on cells** to avoid visual overlap with the table header. If a lower z-index (like `z-10`) is used for simplicity, the sticky column may appear behind the table header row during vertical scroll — acceptable for top-level tables, but not for multi-row headers.

### Canonical classes

```tsx
// In createXxxColumns() → byKey.columnName.meta
meta: {
  headClassName:
    'w-40 min-w-40 sticky left-0 z-40 bg-surface-subtle shadow-[2px_0_4px_-2px_rgba(0,0,0,0.1)]',
  cellClassName:
    'w-40 min-w-40 sticky left-0 z-20 bg-surface-subtle group-hover:bg-surface-subtle shadow-[2px_0_4px_-2px_rgba(0,0,0,0.1)]',
}
```

### Requirements

| Class | Purpose |
|-------|---------|
| `bg-surface-subtle` | Opaque background — prevent content bleed-through |
| `group-hover:bg-surface-subtle` | Maintain background on row hover (DataTable adds `group` to rows) |
| `shadow-[2px_0_4px_-2px_rgba(0,0,0,0.1)]` | Right-edge shadow for visual separation |
| `z-40` on head, `z-20` on cell | Correct stacking order vs sticky header |

### Multiple sticky columns

For 2+ sticky columns, calculate left offsets manually:
- Column 1: `sticky left-0`
- Column 2: `sticky left-[100px]` (width of column 1)
- Column 3: `sticky left-[260px]` (width of col 1 + col 2)

Use Tailwind arbitrary values: `left-[100px]`, `left-[260px]`.

### Payroll reference (raw Table, not DataTable)

`PayrollPeriodDetailView.tsx` uses raw `<Table>` + inline `style={{ left: offset }}` for sticky columns. More flexible for dynamic offsets. Uses `PINNED_CELL_CLASS`, `LAST_PINNED_COLUMN_CLASS`, `getPinnedColumnStyle()`. Copy this pattern when DataTable's class-based approach is too rigid.

## @hilo/ui Input Search Icon — erp-admin Pattern

The erp-admin codebase uses a **custom search icon + suppressed native icon** pattern consistently across all search inputs. The native browser search icon is suppressed in favor of the app's custom `SearchNormal1` icon.

```tsx
// ✅ CORRECT for erp-admin — custom icon + suppress native
<Input
  type="search"
  inputSize="xl"
  suppressNativeSearchIcon
  value={searchValue}
  onChange={...}
  prefix={<SearchNormal1 variant="Linear" color="currentColor" className="size-5" />}
  placeholder={t('...')}
/>
```

This pattern is used in:
- `PayrollPeriodDetailView.tsx`
- `PayrollPeriodsView.tsx`
- `AttendanceTimesheetCard.tsx`

The native clear button (×) is still available at the right side of the input even with `suppressNativeSearchIcon`, satisfying "clear filter" requirements.

## Search — Client-Side Pattern

When API doesn't support `q`, use client-side filtering:

```tsx
const [query, setQuery] = useState('');
const { inputValue: searchInput, setInputValue: setSearchInput } =
  useDebouncedSearch(query, setQuery); // from @hilo/shared, 300ms default

const filteredRows = useMemo(() => {
  if (!query.trim()) return sourceRows;
  const q = query.toLowerCase().trim();
  return sourceRows.filter(
    (row) =>
      row.employeeName.toLowerCase().includes(q) ||
      row.employeeCode.toLowerCase().includes(q) ||
      row.department.toLowerCase().includes(q),
  );
}, [sourceRows, query]);
```

### Empty state distinction

```tsx
emptyMessage={
  hasSearchQuery
    ? t('...searchEmpty')   // "No matching employees found"
    : t('...empty')          // "No timesheet data"
}
```

## Branch Discipline

- Keep unrelated feature work in separate branches/MRs
- One issue = one feature branch: `feat/issue-103-search-sticky`
- Don't mix issue changes into unrelated merge branches

## Removing columns from tables

When removing a column from an existing table, the ripple effect includes:

### 1. Column definition
Remove the column object from the column factory (`createXxxColumns`) or inline `useMemo`.

### 2. Unused imports
Remove the now-unused:
- Constants (`ACTION_COLUMN_META`, `ACTION_BUTTON_CLASS`, etc.)
- Icons (`Trash`, etc.)
- Types (if column-specific)

### 3. Locale keys — CRITICAL: verify scope first
**Before deleting any i18n key from `hr.json`, grep for it across the entire codebase:**

```bash
grep -rn 'payrollPeriods\.actions\.delete\|payrollPeriods\.table\.columns\.action' apps/hr/ packages/locales/
```

A single key may be used by multiple tables/components. Only delete keys that are **exclusively** used by the column being removed.

### 4. Safe locale cleanup technique
Use **Python's `json.dump()`** to remove keys from the JSON tree — avoids trailing-comma and formatting issues that plague `sed`/text-based approaches:

```python
import json

with open(path) as f:
    data = json.load(f)

# Navigate and delete
del data['features']['salary']['payrollPeriods']['actions']['delete']

with open(path, 'w') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
```

⚠️ **Never use `sed` on large JSON locale files** — it is too easy to accidentally remove the same key from multiple unrelated sections, leaving trailing commas that break JSON validity.

## Self-Review Checklist for HR Tables

Before claiming done on any HR table change:

- [ ] **Sticky z-index**: head `z-40`, cell `z-20` (not both `z-20`)
- [ ] **`group-hover` background** on sticky cells
- [ ] **i18n keys**: actually used in code, both `en` + `vi` added
- [ ] **Deleted column locale keys**: grepped the full codebase first, removed only exclusive-use keys
- [ ] **Search empty state**: distinguishes "no data" vs "no search results"
- [ ] **`cn()` merge order**: column meta applied after DataTable defaults
- [ ] **API tested**: verified endpoint support before choosing client vs server filtering
- [ ] **Prettier check**: run `prettier --check` on touched files (action-column removal can cause prettier mismatch with `],` indentation)

## Verification

```bash
pnpm --filter hr-dashboard typecheck
pnpm run lint
# For the specific files changed:
cd apps/hr && npx prettier --check src/features/{feature}/components/...
```
