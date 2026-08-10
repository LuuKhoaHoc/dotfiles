# Filter trigger placement audit — erp-admin (2026-08-10)

Canonical rule (user-confirmed): `toolbarExtra` on DataTable = **quick filters ONLY** (Selects, search shortcuts). The button opening `TableFiltersPanel` / `*FilterModal` goes on the list page **Header** next to the primary action. HR/finance/product already comply; employee + sale have violations.

## ✅ Correct (trigger in Header, toolbarExtra = quick filter)

- **hr** — all: SalaryView→`SalaryHeaderActions`, TimeOffView→`TimeOffManagementHeader`, OffboardingView (`onFilter`), EmployeeViewWrapper→`EmployeeHeader`, RequestManagementViewWrapper (`onOpenFilter`), Attendance*Card, hrm-settings sections, OrganizationDashboardHeader, PayrollPeriodDetailView. HR uses **no `toolbarExtra` at all**.
- **finance** — `InvoiceRequestsHeader` (trigger inside Header).
- **product** — `ProductCatalogView` (trigger in `<header>`).
- **sale** — CustomerListPage, OrderListPage, DigitalSignatureDossierListPage, RenewalsPage: trigger in page header; `toolbarExtra` carries only Select quick filters (service/status/isLocked).
- **employee** — requests feature (`RequestsOverview`: trigger in Header + zustand `useRequestsUiStore`).

## ❌ Violations (trigger inside DataTable `toolbarExtra`)

1. `apps/employee/src/features/time-off-management/components/LeaveRequestsTable.tsx` (used by LeaveOverview)
2. `apps/employee/src/features/organization/components/OrganizationMembersTable.tsx` (used by OrganizationOverview)
3. `apps/employee/src/features/attendance/components/AttendanceHistoryTable.tsx` (used by AttendanceHistoryModal)
4. `apps/employee/src/features/attendance/components/AttendanceAdjustmentRequestListModal.tsx` (trigger in the table toolbar inside a ResponsiveModal — modal header would be the right home)
5. `apps/sale/src/features/reports-dashboard/components/ReportDataTable.tsx` — shared base for **8 report tables**: MaintenanceFeeTable, TopIndebtedCustomersTable, CertListTable, ExpiringCertTable, MonthlyRevenueTable, RevenueDetailTable, AgentPerformanceTable, ExpiringSubTable. Parent Views (DebtMaintenanceView, DigitalSignatureView, RevenueOrdersView, SubscriptionAgentView) currently have **no header** with a filter trigger — they need one.

## Fix shape

Lift `filterOpen` to the page/view component; render the trigger in its Header (via an `actions`/`onOpenFilter` slot); keep `<TableFiltersPanel>` where it is (portal — trigger position doesn't affect it). Same shape as the Requests pattern in SKILL.md ("Moving a table filter trigger to the page header"). For features with a zustand UI store, read `filterOpen` from the store instead of threading props.
