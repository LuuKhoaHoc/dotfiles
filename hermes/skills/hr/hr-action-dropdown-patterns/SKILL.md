---
name: hr-action-dropdown-patterns
description: Row action dropdown patterns for HR DataTable features.
triggers:
  - adding row action buttons to an HR table
  - creating a new RowActionDropdown component
  - wiring action column in use*Columns hook
  - adding activate/deactivate toggle to HR table
---

# HR Action Dropdown Patterns

## Trigger

Adding, wiring, or refactoring row-level action menus in HR DataTable features.

## Three UI Component Patterns

### 1. TableOptionMenu (preferred, from @hilo/ui)

Wraps shadcn DropdownMenu with standardized trigger, layout, item rendering. Accepts items: TableOptionMenuItem[] with key, label, onSelect, hidden, disabled, className.

Features using this: Employees, Organizations (all 7 tabs), Time-Off, Attendance Policy, Attendance Location, Attendance Reminder, Take Leave, Work Schedule, Work Schedule Shift.

### 2. Raw DropdownMenu (shadcn, legacy)

Manually builds DropdownMenu + DropdownMenuTrigger + DropdownMenuContent + DropdownMenuItem. Uses shared constants CONFIG_DROPDOWN_MENU_CONTENT_CLASS and CONFIG_ROW_ACTION_BUTTON_CLASS from @hr/shared/constants/action-controls.

Features using this: Offboarding, Insurance Tax, Change Management (list mode), Salary Fund, Work Request.

### 3. Popover (attendance-specific)

Uses shadcn Popover instead of DropdownMenu. Found only in attendance features.

Features using this: Attendance List, Attendance Timesheet, Bulk Attendance.

### 4. Inline Icon Buttons (no dropdown)

When only 2-3 actions exist and need to be immediately visible (not hidden in menu), use inline Button components. Found in approval modes.

Features using this: Request Management (pending mode), Change Management (approval mode).

## Status Toggle Patterns

Three distinct patterns for activate/deactivate in action menus:

| Pattern | Where Used | How It Works |
|---------|------------|--------------|
| Dual items (separate deactivate/reactivate, each conditionally hidden) | Take Leave, Employees | Two menu items, each has hidden: !show or condition |
| Single toggle item (label changes based on status) | Organizations, Attendance Policy, Attendance Reminder, Work Request, Salary Fund | One item whose label swaps between Deactivate/Reactivate based on isActive |
| Deactivate only (no reactivate) | Insurance Tax | Only shows Deactivate; no reactivate from dropdown |

### Toggle Implementation Patterns

**Dual items (Take Leave pattern):**
```tsx
{ key: 'deactivate', label: t('...deactivate'), hidden: !row.isActive }
{ key: 'reactivate', label: t('...reactivate'), hidden: row.isActive }
```

**Single toggle (Organizations pattern):**
```tsx
{ key: 'toggleActive', label: isActive ? t('...deactivate') : t('...activate'), onSelect: onToggleActive }
```

## Column Hook Wiring

Two approaches exist:

### A. Separate actionColumn return (preferred for display-settings features)

Hook returns { byKey, actionColumn }. The consuming tab component appends actionColumn after the configurable data columns.

**Used by**: Request Management, Time-Off, Change Management.

### B. Inline action column in hook (simpler features)

Action column is appended inside the hook's useMemo:

```ts
return [...dataColumns, actionColumn];
```

**Used by**: Attendance Policy, Attendance Location, Insurance Tax, Offboarding, Leave Type.

### C. Action column via callback props

Hook accepts action callbacks in options, builds action column inline:

```ts
export function useXxxColumns({ onViewDetail, onEdit, ... }: Options): ColumnDef<T>[] { ... }
```

**Used by**: Employees, Attendance Policy, Attendance Location, Offboarding, Insurance Tax, Take Leave.

## Feature Component Registry

| Feature | Dropdown Component | Pattern | Actions |
|---------|-------------------|---------|---------|
| Employees | EmployeeRowActionsDropdown | TableOptionMenu | View, Edit, Active/Inactive toggle |
| Organizations (7 tabs) | OrganizationRowActionDropdown | TableOptionMenu | View, Edit, Delete, Toggle Active |
| Request Management | RequestManagementRowActionDropdown | TableOptionMenu (list) / Inline buttons (pending) | View Detail; (pending: View, Approve, Reject) |
| Time-Off Requests | LeaveModuleRowActionDropdown | TableOptionMenu | View (configurable array) |
| Time-Off Balances | LeaveModuleRowActionDropdown | TableOptionMenu | View (configurable array) |
| Attendance Policy | AttendancePolicyRowActionDropdown | TableOptionMenu | View, Edit, Apply, Delete, Toggle Active |
| Attendance Location | AttendanceLocationRowActionDropdown | TableOptionMenu | View, Edit, Delete |
| Attendance Reminder | AttendanceReminderRowActionDropdown | TableOptionMenu | View, Edit, Toggle Active, Delete |
| Take Leave | TakeLeaveRowActionDropdown | TableOptionMenu | View, Edit, Delete (non-system), Deactivate/Reactivate |
| Work Schedule | WorkScheduleRowActionDropdown | TableOptionMenu | Apply (active only), View, Edit, Delete |
| Work Schedule Shift | WorkScheduleShiftRowActionDropdown | TableOptionMenu | View, Edit, Delete |
| Work Request | WorkRequestRowActionDropdown | Raw DropdownMenu | View, Edit, Delete, Toggle Active |
| Offboarding | OffboardingRowActionDropdown | Raw DropdownMenu | View, Edit, Cancel Process, Print Decision |
| Insurance Tax | InsuranceTaxRowActionDropdown | Raw DropdownMenu | View, Edit, Deactivate |
| Change Management | ChangeManagementRowActionDropdown | Raw DropdownMenu (list) / Inline buttons (approval) | View, Edit (draft), Submit for Approval (draft), Cancel (draft/pending); (approval: Approve, Reject) |
| Salary Fund | Inline in SalaryFundManagementView.tsx | Raw DropdownMenu | View, Edit, Delete, Clone, Configure and Apply, Toggle Active |
| Attendance List | AttendanceListRowActions | Popover | View Detail |
| Attendance Timesheet | AttendanceTimesheetRowActions | Popover | View Detail |
| Bulk Attendance | BulkAttendanceRowActions | Popover | View Detail |

## Shared Constants

From @hr/shared/constants/action-controls (or @/shared/constants/action-controls):

- CONFIG_DROPDOWN_MENU_CONTENT_CLASS — standard content styling for raw DropdownMenu items
- CONFIG_ROW_ACTION_BUTTON_CLASS — standard trigger button styling (More icon button)

From @hilo/shared:
- ACTION_COLUMN_META — standard head/cell className for action columns

## Conventions

- Prefer TableOptionMenu for new action dropdowns. It handles trigger icon, menu layout, item separators, and hidden item filtering.
- Raw DropdownMenu only when you need custom trigger styling or item rendering that TableOptionMenu cannot express.
- Inline buttons only for approval/decision flows where actions must be immediately visible (not hidden in a menu).
- Action column stays outside display-settings data model; append at render time only.
- i18n keys follow pattern: features.{feature}.{actions|table}.{actionName}.
- Every user-triggered action must emit toast feedback (success on onSuccess, error on onError/catch).

## Audit Checklist: Which dropdowns need toggles?

When auditing all RowActionDropdown files for missing activate/deactivate:

1. **List all files**: `search_files(*RowAction*Dropdown*, target=files)` + `search_files(*RowActions*Dropdown*, target=files)`
2. **Check each for existing toggle**: grep for `deactivate|reactivate|toggleActive|isActive|onDeactivate|onReactivate|onToggleActive`
3. **For files WITHOUT toggle, check DTO type** — the row type imported in the dropdown or its parent `types/*.ts`:
   - Has `status: GenericStatusValue` or `isActive: boolean` → **needs toggle** → add task
   - Has workflow status (e.g. `OffboardingStatus = 'DRAFT'|'PROCESSING'|'COMPLETED'`) → **not applicable** — document as out-of-scope
   - Has no status field at all (e.g. `AttendanceLocationDto`) → **needs BE support first** — document as blocked
4. **Check for missing reactivate** — Insurance Tax has `onDeactivate` only; if BE supports reactivation, it needs the reverse action too
5. **Classify results** into: ✅ done / ❌ needs work / ⚠️ needs review / N/A out-of-scope

### Non-applicable categories (do NOT add toggle)

| Category | Examples | Why |
|----------|----------|-----|
| Request approval | RequestManagement, ChangeManagement | Approve/Reject ≠ entity status toggle |
| Workflow status | Offboarding (DRAFT/PROCESSING/COMPLETED) | Status = lifecycle stage, not active/inactive |
| View-only records | Attendance Timesheet, Bulk Attendance, Attendance History | Read-only audit data, no entity to toggle |
| No status field in DTO | AttendanceLocationDto | BE must add field first |

## Pitfalls

- Mixing DropdownMenu patterns in same feature — prefer standardizing on TableOptionMenu when refactoring. Offboarding, Insurance Tax, and Work Request still use raw DropdownMenu.
- Attendance features use Popover instead of DropdownMenu — this is a historical anomaly. New attendance tables should use TableOptionMenu.
- Toggle label inconsistency — some features use Active/Inactive (Employees), others use Deactivate/Reactivate (Take Leave, Organizations). Check the feature existing convention before adding a new toggle.
- Missing hidden guard on toggle items — if you add deactivate/reactivate without conditional hidden, both items appear simultaneously.
- isSystem guard on Delete — Take Leave hides Delete for system leave types (row.isSystem). Similar pattern needed for any entity that cannot be deleted.
- `execute_code` `read_file` returns empty for files that direct `read_file` reads fine — always verify with `terminal cat` when auditing multiple files programmatically.
- `read_file` has a 3-read retry limit per conversation per file path. After that, use `terminal cat` to access the file.

## Verification

```bash
pnpm --filter hr-dashboard typecheck
pnpm --filter hr-dashboard build
```