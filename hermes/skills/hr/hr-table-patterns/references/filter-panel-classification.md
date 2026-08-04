# Filter Panel Classification — HR list views audit (erp-admin)

How to classify the filter state of every list view in `apps/hr` and produce an
evidence-backed table (file:line). Run before adding/standardizing filters.

## Classification grid

| Status | Meaning |
|--------|---------|
| ✅ STANDARD | Filter trigger + panel both wired, panel uses `TableFiltersPanel` from `@hilo/ui` |
| ⚠️ CUSTOM | Has filter UI (button/dialog/chips hand-written) but does NOT use `TableFiltersPanel` |
| ❌ NONE | Search-only or no filter at all. **Search-only counts as NONE.** |
| 🔍 SUB | Sub-list inside a dialog/detail (no filter needed) — note briefly only |

## Wiring-trace recipe (do this per list view)

1. Find the list view file (grep `DataTable` per feature).
2. Find its filter panel: `grep -rn "XxxFilterPanel" --include="*.tsx" . | grep -v "own-file-path"` —
   **excluding the panel's own file** reveals real importers (unused panels exist!).
3. Trace the trigger chain: `*Header.tsx` Filter-icon button (`onFilterClick`/`onFilter`)
   → view component → section ref (`useImperativeHandle` exposing `openFilter`)
   → panel render with `open={filterOpen}`.
4. Detect DEAD triggers — filter button visible but no panel:
   - `openFilter: () => undefined` (no-op ref, e.g. `AttendanceLocationsSection.tsx:99`,
     `AttendanceRemindersSection.tsx:115`)
   - `handleComingSoon('...filterComingSoon')` toast (e.g. `OffboardingView.tsx:43`)
5. Do NOT misclassify DataTable toolbar `dateRange`/`onDateRangeChange` props as CUSTOM:
   they render the shared `DateRangePicker` (`packages/ui/src/components/ui/DataTable.tsx:242-244`)
   — shared UI, not a filter panel. Note it, classify NONE.

## Verified wiring locations (2026-08 scan)

- Panel files: `hrm-settings/features/attendance/components/dialogs/AttendancePolicyFilterPanel.tsx`,
  `hrm-settings/features/take-leave/components/dialogs/TakeLeaveLeaveTypeFilterPanel.tsx`,
  `insurance-tax/components/dialogs/insurance-profile/InsuranceProfileFiltersDialog.tsx`,
  `organizations/components/OrganizationDashboardHeader.tsx` (header-level, not per-tab).
- STANDARD wiring: `AttendancePolicySection.tsx:419-425` + header btn `AttendanceConfigHeader.tsx:108-111`;
  `TakeLeaveConfigView.tsx:285/408-418` + btn `TakeLeaveConfigHeader.tsx:94-96`;
  `InsuranceTaxView.tsx:48-51` (onFilter) + `:81-83` (dialog) + btn `InsuranceTaxHeader.tsx:118-120`.

## Audit result snapshot (Part B, 7 features, 29 list views)

- ✅ STANDARD: 4 — Attendance/Policy, Take-leave/LeaveTypes, Insurance-profiles, Org dashboard header
- ⚠️ CUSTOM: 1 — Offboarding/Tasks (`OffboardingTasksTab.tsx:80-102` filter chips, inside record dialog)
- ❌ NONE: 22 — all `organizations` tabs (7), `hrm-settings` org-config (5) + work-request/work-schedule (3)
  + attendance Locations/Reminders (2, dead btn) + offboarding records (1, dead btn)
  + change-mgmt/request-mgmt/time-off lists (4, have DataTable dateRange only)
- 🔍 SUB: 2 — `OffboardingAssetsTab`, `OrganizationDepartmentMembersDialog`

Lowest-cost tickets: features whose header Filter button already exists but is a
no-op — just implement `openFilter` and mount the panel.

## Audit result snapshot (Part A, 4 features, 12 list views)

Paths relative to `apps/hr/src/features/`. All lines verified 2026-08.

| Status | List view | Evidence |
|--------|-----------|----------|
| ✅ STANDARD | salary / Salary Grades tab | `salary/components/salary-grades/SalaryGradesListView.tsx:587-591` renders `<SalaryFundFiltersPanel open={filterOpen}>`; panel `salary/components/salary-grades/SalaryFundFiltersPanel.tsx:6,78` uses `TableFiltersPanel`; trigger `salary/components/SalaryHeaderActions.tsx:72-75` → `useSalaryFundUiStore.setFilterOpen` |
| ✅ STANDARD | dashboard / global header filter | `dashboard/components/DashboardHeader.tsx:121-123` Filter btn → `:137-155` `<TableFiltersPanel>` (unit multi-select + date range; the only `@hilo/ui` category/section usage in Part A) |
| ⚠️ CUSTOM | attendances / timesheet detail | `attendances/components/tabs/timesheet/AttendanceTimesheetDetailView.tsx:731-748` DataTable, `:765-773` renders `AttendanceTimesheetFilterSheet`; sheet `AttendanceTimesheetFilterSheet.tsx:376-399` hand-written (ResponsiveModal + Popover/Select/Checkbox); trigger `AttendanceHeader.tsx:259-268` → store `requestTimesheetFilter()` |
| ⚠️ CUSTOM | dashboard / detail-list workspace | `dashboard/components/DashboardDetailWorkspace.tsx:124-208` inline filter bar (search Input :130-137, status `AsyncOptionsComboboxControl` :145-160, dateType Select :169-187, sort Select :196-207); DataTable :212-229 |
| ⚠️ CUSTOM | salary / management-groups + payroll-employees tabs | `salary/components/SalaryManagementTable.tsx:104` DataTable; filter bar `salary/components/SalaryManagementFilters.tsx:42-190` hand-written Selects + reset (no TableFiltersPanel); mounted in `SalaryView.tsx:299-311,333-345` |
| ⚠️ CUSTOM | salary / payroll-period detail (employees table) | `salary/components/payroll-runs/PayrollPeriodDetailView.tsx:728-764` inline search + 2 Selects (status :739-752, unit :754-764); Filter btn :714-723 `onClick={onOpenFilter}`; uses raw shadcn `Table` (:26-31), not DataTable |
| ❌ NONE | attendances / List tab | `attendances/components/tabs/attendance-lists/AttendanceListCard.tsx:174-193` DataTable toolbar search + dateRange only |
| ❌ NONE | attendances / Bulk Attendance history | `attendances/components/tabs/bulk-attendances/BulkAttendanceCard.tsx:117-140` toolbar search + dateRange only |
| ❌ NONE | attendances / Timesheet list (no record selected) | `attendances/components/tabs/timesheet/AttendanceTimesheetCard.tsx:150-171` toolbar search + dateRange only; header Filter btn only acts in detail mode |
| ❌ NONE | employees / Employee list | `employees/components/EmployeeListView.tsx:147-163` toolbar search + dateRange; `employees/components/employee-header/EmployeeHeader.tsx:118-124` Filter btn with NO onClick (dead) |
| ❌ NONE | salary / Payroll Periods tab | `salary/components/payroll-runs/PayrollPeriodsView.tsx:412-422` search Input only, DataTable :447-479 `showToolbar={false}`; accepts `onOpenFilter` (:107) but never uses it |
| 🔍 SUB | attendances / employee picker (bulk-attendance create dialog) | `attendances/components/dialogs/bulk-attendances/EmployeeTable.tsx:98-121` DataTable, no filter UI |

Counts: ✅ 2 · ⚠️ 4 · ❌ 5 · 🔍 1. Dead/ineffective triggers to fix first:
`EmployeeHeader.tsx:118-124` (no onClick), `PayrollPeriodsView` unused `onOpenFilter`
(panel only mounted in salaryGrades tab — also true for managementGroups/payrollEmployees
tabs where the shared header Filter btn sets `filterOpen` but nothing renders).
