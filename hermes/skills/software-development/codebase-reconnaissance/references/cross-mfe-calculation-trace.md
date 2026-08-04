# Cross-MFE Calculation Trace Analysis

Trace a calculation (working days, grace period, late/early minutes) across multiple MFEs and shared packages to determine what is computed server-side vs client-side.

## Workflow

### 1. Identify All DTO Fields Related to the Calculation

Collect every field name that touches the calculation across all MFE types and shared types. Look for:

- **Raw values** (simple number/string passthrough — likely server-calculated)
- **Derived/display values** (formatted strings, boolean statuses, hour-minute text — likely client-formatted)
- **Configuration fields** (grace minutes, thresholds, toggles — sent to server, not applied client-side)
- **Aggregation fields** (totals, summaries — check whether server returns them or client sums them)

### 2. Trace Each Field Through the Data Flow

For each field, follow: **types → API DTO → hook/query → mapper → UI component**.

| Layer | What to look for |
|---|---|
| **Types** | Field name, type, optionality. If multiple MFEs have the same field, confirm the contract is shared (`packages/shared/`) or duplicated (per-AGENTS.md convention). |
| **API** | Does the endpoint return the field directly? Is there a `select` transformation in the query hook? |
| **Mapper** | Is the field mapped 1:1, transformed (e.g. `minutesToHours()`), or derived from multiple fields? |
| **UI** | Is the field rendered directly or via a formatting helper (`formatMinutesAsText`, `formatWorkHours`)? |

### 3. Determine Calculation Boundary

| Signal | Boundary |
|---|---|
| Field mapped 1:1 from backend DTO with no transformation | **Server-side** — frontend trusts the value |
| Field is computed/aggregated in a mapper or hook from backend values | **Client-side** — verify the aggregation logic |
| Field drives a `refresh` or `recalculate` API call | **Server-side** — frontend triggers but doesn't compute |
| Field configures a policy/rule that affects calculation | **Configuration** — frontend sends it to server for application |
| Field is formatted for display only (minutes → "X giờ Y phút") | **Display formatting** — not a calculation change |

### 4. Check for Recalculation Triggers

Search for API endpoints or mutations that initiate server-side recalculation:

- `refresh`, `recalculate`, `recompute`, `reprocess` endpoint names
- Mutations that invalidate large query subtrees (e.g. `invalidateQueries({ queryKey: ATTENDANCE_QUERY_KEYS.TIMESHEETS.ALL })`)

### 5. Look for Configuration That Affects the Calculation

In ERP systems, calculation behavior is often configurable via policy, rule, or settings features:

- Grace period tolerances (`lateGraceMinutes`, `earlyLeaveGraceMinutes`)
- Calculation toggles (`skipLateEarlyCalculation`)
- Defaults in form-level constants that feed into API request bodies
- Check whether the configuration is stored server-side and applied server-side (common) or stored client-side and applied client-side (rare for timesheet calc)

### 6. Verify with Targeted Tests

Run tests at each boundary:

```bash
# Test the mapper (1:1 passthrough vs transformation)
pnpm --filter <app> exec vitest run <mapper-path>

# Test the form-building config (policy → API payload)
pnpm --filter <app> exec vitest run <form-utils-path>

# Test the aggregation logic (if client-side)
pnpm --filter <app> exec vitest run <aggregation-utils-path>
```

## Worked Example: Attendance/Timesheet Calculation

From an ERP monorepo with `apps/hr`, `apps/employee`, and `packages/shared`:

### Target: Working Days + Grace Period Logic

**Question**: Where are working days and grace-period adjustments calculated?

### Step 1 — DTO Fields

| Field | Appears In | Type |
|---|---|---|
| `standardWorkingDays` | `AttendanceSheetDetailRowDto` (HR) | Number passthrough |
| `actualWorkingDays` | `AttendanceSheetDetailRowDto` (HR) | Number passthrough |
| `totalWorkDays` / `total_work_days` | `AttendanceSheetDetailRowDto` (HR) | Number passthrough |
| `totalStandardWorkingDays` | `AttendanceSheetDto` (HR) | Sheet-level aggregation (server) |
| `totalActualWorkingDays` | `AttendanceSheetDto` (HR) | Sheet-level aggregation (server) |
| `lateMinutes` | `AttendanceSheetDetailDayDto` (HR), `AttendanceHistoryLogDto` (shared) | Number passthrough |
| `earlyLeaveMinutes` | `AttendanceSheetDetailDayDto` (HR), `AttendanceHistoryLogDto` (shared) | Number passthrough |
| `lateGraceMinutes` | `AttendancePolicyDto` (HR-config) | Policy configuration |
| `earlyLeaveGraceMinutes` | `AttendancePolicyDto` (HR-config) | Policy configuration |
| `skipLateEarlyCalculation` | `AttendancePolicyDto` (HR-config) | Policy toggle |

### Step 2 — Trace

**Working days** (`standardWorkDays`, `actualWorkDays`, `totalWorkDays`):

```
API:  getAttendanceSheetDetail() → AttendanceSheetDetailData
DTO:  AttendanceSheetDetailRowDto.standardWorkingDays
Hook: useAttendanceTimesheetDetailRows() → select → mapAttendanceSheetDetailRow()
Mapper: mapAttendanceSheetDetailRow() at line 918-920
  → { standardWorkDays: toNumber(row.standardWorkingDays),
       actualWorkDays: toNumber(row.actualWorkingDays),
       totalWorkDays: toNumber(row.totalWorkDays ?? row.total_work_days) }
UI:   AttendanceTimesheetDetailRecord.standardWorkDays / actualWorkDays / totalWorkDays
```

All three fields are **1:1 numeric passthrough** with `toNumber()` parsing only — no recalculation. The `minutesToHours()` function at line 925 is called for `overtimeHours` only, not working days.

**Grace period** (`lateMinutes`, `earlyLeaveMinutes`):

```
API:  getAttendanceSheetRowDayDetail() → AttendanceSheetRowDayDetailData
DTO:  AttendanceSheetDetailDayDto.lateMinutes / earlyLeaveMinutes
Hook: useAttendanceTimesheetDayDetail() → mapAttendanceSheetRowDayDetailToModel()
Mapper: mapped to lateMinutes/earlyLeaveMinutes at lines 812-819
  → { lateMinutes: formatMinutesAsText(detail.lateMinutes ?? session.lateMinutes ?? day.lateMinutes),
       earlyLeaveMinutes: formatMinutesAsText(detail.earlyLeaveMinutes ?? session.earlyLeaveMinutes ?? day.earlyLeaveMinutes) }
UI:   AttendanceTimesheetDayDetail.lateMinutes / earlyLeaveMinutes
```

The values are **server-calculated** — the mapper resolves fallback chains (`detail → session → day`) and formats for display, but never computes the minutes. The `formatMinutesAsText()` helper (`line 569-573`) only converts number → `"X phút"` label.

**Refresh trigger** (`refreshAttendanceSheet` API):

```typescript
// useAttendanceTimesheetData.ts line 1464-1498
// POST to API_ENDPOINTS.HR.ATTENDANCE_SHEETS_REFRESH
// On success: invalidates ATTENDANCE_QUERY_KEYS.TIMESHEETS.ALL
```

This triggers a **server-side recalculation** of the timesheet.

### Step 3 — Boundary Summary

| Field | Boundary | Evidence |
|---|---|---|
| `actualWorkingDays` | **Server-side** | 1:1 DTO passthrough; frontend never computes |
| `totalWorkDays` | **Server-side** | 1:1 DTO passthrough (dual field name fallback) |
| `lateMinutes` | **Server-side** | Returned from server; frontend only formats |
| `earlyLeaveMinutes` | **Server-side** | Same as lateMinutes |
| `lateGraceMinutes` | **Configuration** | Sent to server; applied server-side during recalculation |
| `earlyLeaveGraceMinutes` | **Configuration** | Same as lateGraceMinutes |
| `convertedWorkDays` | **Server-side** | `day?.convertedWorkDays ?? day?.payableWorkDays` passthrough |
| `overtimeHours` | **Server-side** (raw) / **Client-side** (format) | Raw minutes from server → `minutesToHours()` conversion |
| Summary totals (leaveDays, overtimeHours) | **Client-side aggregation** of server values | `mapAttendanceSheetDetailSummary()` at line 447 sums row values |

### Step 4 — Verification

```bash
# Month grid builder (calendar days, not working days)
pnpm --filter hr-dashboard exec vitest run src/features/attendances/utils/presenters/attendance-timesheet-month.spec.ts

# Time value normalization (for edit dialogs)
pnpm --filter hr-dashboard exec vitest run src/features/attendances/utils/attendance-timesheet-day-dialog.spec.ts

# Policy form default values and mutation building
pnpm --filter hr-dashboard exec vitest run src/features/hrm-settings/features/attendance/utils/attendance-policy-form.spec.ts
```

## When to Use This Pattern

Use this reference when:

- Investigating a numerical or time-based calculation that appears in the UI but whose source is unclear
- Determining whether a bug requires a frontend fix, backend fix, or both
- Planning to add or modify a calculation and need to know where the boundary lies
- Auditing "where does value X come from" across a multi-MFE monorepo
- Migrating from mock/static data to real API and need to distinguish display-only values from server-calculated ones

## Common Pitfalls

- **Assuming frontend computes what it displays**: Just because a value appears in a table cell doesn't mean the frontend calculated it. Trace back to the API DTO field.
- **Missing the fallback chain**: Mappers often try multiple source fields (e.g. `row.totalWorkDays ?? row.total_work_days`). The first one present wins — make sure you check which field the server actually sends.
- **Confusing display formatting with calculation**: `formatMinutesAsText(minutes)` doesn't calculate the minutes — it only wraps the server-provided number in a label. The actual latency/reduction happens server-side.
- **Not checking the refresh endpoint**: A value might be computed on initial save but not recalculated until a `refresh` API is called. Check for explicit recalculation triggers.
