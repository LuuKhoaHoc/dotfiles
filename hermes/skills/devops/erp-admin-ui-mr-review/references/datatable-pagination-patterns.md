# DataTable Pagination Patterns in erp-admin

## Background

`@hilo/ui` DataTable has an `enablePagination` prop that controls client-side pagination (TanStack `getPaginationRowModel`). As of MR !610 (2026-08-17), the default changed from `true` to `false`.

## Server-side vs Client-side

**Server-side pagination (dominant pattern):**
- Table components render `footer={<DefaultPagination ... />}` with `safePage`, `totalPages`, `onPageChange`, `pageSize`, `onPageSizeChange`
- DataTable does NOT paginate data — the footer handles page navigation externally
- `enablePagination` is irrelevant for these tables (they don't use `getPaginationRowModel`)
- These tables typically also have `footerRangeSummary` for "1-10 trên tổng số 100 thành viên"

**Client-side pagination (opt-in):**
- DataTable internally paginates the `data` array using TanStack's `getPaginationRowModel`
- Requires `enablePagination={true}`
- No `footer`/`DefaultPagination` needed — DataTable renders its own pagination

## Census (2026-08-17)

- **66 total `<DataTable>` usages** across apps/ and packages/
- **51** explicitly set `enablePagination={false}` (server-side)
- **14** don't set `enablePagination` — ALL use server-side via `footer` prop:
  - HR: AttendanceConfigPolicyTab, AttendanceConfigLocationsTab, AttendanceConfigRemindersTab, TakeLeaveConfigLeaveTypesTab, RequestTypesTable, WorkScheduleConfigSchedulesTab, WorkScheduleConfigShiftsTab, LeaveModuleTable, PayrollPeriodsView, SalaryGradesListView
  - Sale: CustomerListTable, DossierListTable, OrderListTable, RenewalTable
- **1** (DataTable.test.tsx) — test file
- **0** use client-side pagination without explicit `enablePagination={true}`

## Verification Commands

Find DataTable usages without explicit `enablePagination`:
```bash
grep -rn '<DataTable' apps/ packages/ --include='*.tsx' --include='*.ts' \
  | grep -v 'DataTable.tsx' | grep -v 'test' | grep -v 'dist/' \
  | while IFS=: read -r file line rest; do
    if ! sed -n "${line},$((line+30))p" "$file" | head -30 | grep -q 'enablePagination'; then
      echo "NO_ENABLE: $file:$line"
    fi
  done
```

Check if a specific DataTable uses server-side pagination:
```bash
sed -n "${line},$((line+30))p" "$file" | grep -E 'footer=|DefaultPagination|safePage|totalPages'
```

## Key Insight for MR Reviews

When an MR changes DataTable default behavior:
1. Don't flag as "breaking" without auditing consumers
2. Server-side pagination via `footer` prop makes `enablePagination` irrelevant
3. All current consumers without explicit `enablePagination` use server-side → default change is safe
4. New convention: server-side = default, client-side = opt-in
