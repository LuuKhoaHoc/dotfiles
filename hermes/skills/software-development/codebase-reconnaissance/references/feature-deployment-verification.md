# Feature Deployment Verification — Full Worked Example

This file documents the session where 14 features claimed deployed on erp-admin UAT (develop branch) were systematically verified against the codebase.

## Session Context

- **Project**: erp-admin (pnpm + Turbo + Next.js 16 + shadcn/ui v4 + Tailwind v4 monorepo)
- **Branch**: `develop` (UAT)
- **API**: https://api-erp.vppos.vn/api/v1 (FE-only repo; BE external)
- **Claim source**: BA/PO feature report
- **Origin session**: 2026-07-30, erp-admin verification

## Claim List

**FE features:**
1. Employee directory feature
2. Payslip: P1 gốc + OT mapping, TNCN tax for TTS/TV/CTV
3. Salary period: P3 → Thu nhập tính thuế, remove delete action
4. Salary grade: tabs → dropdown (Chính thức, TTS, TV, CTV)
5. Attendance: remove "Chốt công" tab
6. Vietnamese labels for status/scope in workday selection
7. Personal profile: dependent delete notification → Vietnamese
8. Time-off: fix leave hours display format
9. HR Dashboard: v2 changes

**BE features (consumed by FE):**
1. Payslip: 0-quantity display, OT calc, taxable income formula, union fee, TTS/CTV/TV format
2. Timesheet: working days recalculation
3. Org structure: aggregate headcount + employee list from child→parent
4. Salary period: recalculation performance
5. Attendance: 10-min grace period for check-in

## Task Splitting Strategy

| Batch | Subagents | Focus |
|-------|-----------|-------|
| Batch 1 (FE-HR Salary) | 4 | PayrollEmployeeSlipView, PayrollPeriodDetailView, SalaryGrade views, SalaryManagementTabsList |
| Batch 2 (FE-HR Other) | 3 | Attendance tabs, Dashboard v2, Dependent notification |
| Batch 3 (FE-Employee) | 3 | Directory, Time-off format, Attendance |
| Batch 4 (BE-related) | 4 | Payroll API logic, Timesheet calc, Org aggregation, Performance |

### Dispatch Pattern Used

```python
# Per batch:
delegate_task(
    context="Project context...",
    goal="Umbrella goal for the batch",
    role="orchestrator",
    tasks=[
        {"goal": "Sub-goal A", "context": "Files + specific checklist + evidence requirements"},
        {"goal": "Sub-goal B", "context": "Files + specific checklist + evidence requirements"},
    ]
)
```

## Key Files Checked Per Area

### Salary (apps/hr/src/features/salary/)
- `components/payroll-runs/PayrollEmployeeSlipView.tsx` — payslip display
- `components/payroll-runs/PayrollPeriodDetailView.tsx` — salary period columns
- `components/payroll-runs/PayrollPeriodDetailView.tsx` — period actions
- `components/salary-grades/CreateSalaryGradeView.tsx` — grade creation
- `components/SalaryManagementTabsList.tsx` — tab navigation
- `apis/salary-management.ts` — API calls
- `types/salary-management.ts` — DTO types
- `hooks/` — business logic

### Attendance (apps/hr/src/features/attendances/)
- `components/AttendanceTabs.tsx` — tab configuration
- `components/tabs/` — individual tab content

### Dashboard (apps/hr/src/features/dashboard/)
- `components/DashboardView.tsx` — main dashboard
- `components/DashboardCardsCarousel.tsx` — card carousel
- `components/DashboardStatCard.tsx` — stat cards

### Employee Directory (apps/employee/src/features/directory/)
- `components/EmployeeDirectoryView.tsx` — main view
- `components/DirectoryUnitAccordionList.tsx` — unit tree
- `components/DirectoryUnitMembers.tsx` — member list
- `components/DirectoryHeaderToolbar.tsx` — search/filter

### Time-off (apps/employee/src/features/time-off-management/)
- `components/LeaveOverview.tsx` — leave balance display
- `components/LeaveRequestsTable.tsx` — leave requests

### Organization (apps/hr/src/features/organizations/)
- `components/OrganizationDashboardView.tsx` — org chart
- `components/tabs/` — tab content
- `apis/` — API calls

### Employee Detail (apps/hr/src/features/employees/)
- `components/employee-detail/` — dependent management

### Employee Attendance (apps/employee/src/features/attendance/)
- `components/AttendanceOverview.tsx` — overview
- `apis/` — API calls

## Evidence Quality Template

Use this per-claim format in the final report:

```markdown
### Feature: {name}
**Status**: ✅ / ⚠️ / ❌ / 🔍

**Evidence**:
- File: `{path}:{line}`
- Code: `{relevant snippet}`
- What it shows: {plain English explanation}
- Missing: {if partial, what else is needed}
```

## Pitfalls Specific to Deployment Verification

- **FE-only repo**: Many "BE" claims (calc logic, DB queries) cannot be verified from FE code alone. Check if FE has API calls or display logic for the claimed feature as a proxy.
- **Multiple apps**: The same concept (e.g. "attendance") may exist in both `apps/hr` (admin) and `apps/employee` (self-service) — check both.
- **Locale files**: Vietnamese text changes may be in `packages/locales/` not in the component directly. Use full-text search for the exact Vietnamese string.
- **Monorepo boundaries**: Don't search in `node_modules/` or `.turbo/` — restrict to `apps/` and `packages/`.
- **Feature-Sliced design**: Each feature has `types/`, `apis/`, `hooks/`, `components/` — check each layer separately.
- **DTO-first display**: Data fields from BE are displayed directly (no adapter), so DTO types in `types/` reveal what the FE expects.
