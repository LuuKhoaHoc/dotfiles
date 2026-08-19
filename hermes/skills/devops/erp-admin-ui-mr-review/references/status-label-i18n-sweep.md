# Status-label i18n sweep — issue #188 worked example (2026-08-13)

Prod bug: HR "Nghỉ phép và quỹ nghỉ phép" list showed raw key `features.timeOffManagement.statuses.canc`
on a cancelled leave request (screenshot from user). BE sends status value `canc`; FE canonical constant is
`cancelled`. This file is the full sweep matrix behind the fix issue.

## Severity tiers (same BE value, different UI damage)

| Rendering path | Example site | Missing key → UI shows |
|---|---|---|
| Tier 1: `t(\`<ns>.statuses.${status}\`)` no defaultValue | `useLeaveRequestColumns.tsx:111`, `useChangeManagementColumns.tsx:178`, `ChangeManagementFiltersPanel.tsx:116`, `ChangeManagementChangeContentSection.tsx:216` | FULL raw key `features.<ns>.statuses.canc` |
| Tier 2: `getStatusLabel(status, tCommon)` — `packages/shared/src/utils/status.ts` (`tCommon(\`status.${key}\`, { defaultValue: status })`) | HR `useRequestManagementColumns`, employee `useRequestsColumns`/`useApprovalInboxColumns`/`useHandledRequestsColumns`, `ApprovalListSection` (HR+employee), dashboard `RequestSummaryCard`, `AttendanceAdjustmentRequestListModal` | Bare value `canc` (no key braces) |
| Safe namespaces (have `cancelled`) | `features.changeManagement.statuses`, `common.status`, employee `leave.history.status` | — |

## Namespace key matrix at develop (2026-08-13)

| Namespace (file) | Keys present | `canc` | `cancelled` |
|---|---|---|---|
| `features.timeOffManagement.statuses` (hr.json en+vi) | draft/pending/approved/rejected/applied/auto_approved/waiting | ❌ | ❌ |
| `features.changeManagement.statuses` (hr.json en+vi) | + cancelled | ❌ | ✅ |
| `features.requestManagement.statuses` (hr.json en+vi) | + cancelled/auto_approved/waiting | ❌ | ✅ |
| `common.status` (common.json en+vi) | broad incl. cancelled | ❌ | ✅ |
| employee `leave.history.status` (employee.json) | cancelled present | ❌ | ✅ |

## Fix scope (umbrella, one issue)

1. hr.json en+vi: add `features.timeOffManagement.statuses.canc` + `.cancelled` ("Đã hủy"/"Cancelled") — the only namespace missing `cancelled` entirely.
2. hr.json en+vi: add `features.changeManagement.statuses.canc` (canonical `cancelled` exists).
3. common.json en+vi: add `status.canc` — covers every Tier-2 consumer in BOTH MFEs in one key.
4. BE confirmed (2026-08-13): canonical value = `cancelled`; `canc` keys are legacy-data fallback (prod still sends `canc`).

## Non-issues verified (don't re-flag)

- `StatusBadge` color: `getStatusStyles` normalizes and falls back to neutral gray — badge renders, only label broken.
- Employee MFE already safe (`leave.history.status.cancelled`).
- HR request-management date+status column uses STATIC keys (`t('features.requestManagement.statuses.cancelled')`) + `getStatusLabel` — no interpolation bug.
- Attendance-adjustment statuses (`present`/`absent`) and payroll-period statuses (`locked`/`active`/...) are different enums — untouched.

## Issue hygiene

- Labels: `HR`, `MFE::hr`, `employee` (when sweep crosses MFEs), `bug`, `frontend`, `priority::high` (prod-visible), `ready-for-agent`; milestone v1.0.4.
- Issue title should name BOTH symptoms (`raw key ...statuses.canc` + `"canc" thô ở danh sách đơn yccv`) so the two severity tiers are discoverable.
- After user confirms the canonical BE value, patch the issue AC (`update_issue_description_patch`, search_replace format) to record it — the fix then adds canonical + legacy keys.
