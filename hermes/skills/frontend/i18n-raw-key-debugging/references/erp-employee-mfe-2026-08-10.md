# Erp-admin employee MFE — i18n raw-key + action-column recon (2026-08-10)

Read-only recon of 4 UI bugs (MFE employee, Hilo ERP monorepo). Findings that transfer to
other MFE investigations.

## Recon source-of-truth rule

Working tree often sits on old `main` (behind many commits). Read the LATEST code from
`origin/develop` with `git show origin/develop:<path>` — NOT the working-tree file.
First confirm the file exists on develop:
`git show origin/develop:<path> >/dev/null 2>&1 && echo EXISTS || echo NOT`
Locales live in `packages/locales/src/translations/{vi,en}/*.json` (employee/common/hr/...),
NOT app-local.

## Bug 4 — action-column raw keys (the clean, transferable finding)

`apps/employee/src/features/attendance/components/AttendanceAdjustmentRequestListModal.tsx`,
action column: calls `t('requests.actions.viewDetail' / 'edit' / 'submit' / 'delete')`.
Locale (`vi` + `en` employee.json) has ONLY `requests.actionMenu.*`
(keys: viewDetail, edit, submit, cancelRequest, delete). `requests.actions` does NOT exist
→ all 4 menu items render raw dotted keys.

Deciding evidence: grep showed the WRONG namespace `requests.actions.` in exactly ONE file
(the modal), while the CORRECT `requests.actionMenu.` was used everywhere else
(`useRequestsColumns.tsx`, `useApprovalInboxColumns.tsx`, `LeaveTableActions.tsx`,
`RequestsOverview.tsx`, `RegistrationInfoSection.tsx`). Fix = swap the keys to `actionMenu.*`.

## Standard row-action component = TableOptionMenu (@hilo/ui)

`packages/ui/src/components/customs/TableOptionMenu.tsx`:
- Props: `items: TableOptionMenuItem[]` (`{key, label, onSelect, hidden, disabled, className}`)
  + **`ariaLabel` required** (translated); default `align='end'`, auto-hides menu when no visible items.
- Canonical example: `apps/hr/.../AttendanceListRowActions.tsx`.
- A table whose action column hand-rolls `DropdownMenu`+`Button` inline (instead of
  `TableOptionMenu`) = the "UI action button không đồng bộ" bug class, usually also missing
  an `aria-label` (i18n gap). Fix: refactor to `TableOptionMenu` + add `ariaLabel={t('...more')}` key.

## Bug 3 — approval-status fallback chain

`apps/employee/src/shared/components/ApprovalListSection.tsx` → `getApprovalStatusLabel`:
1. `features.timeOffManagement.leaveRequestStatuses.${status}` (employee.json) — `waiting` PRESENT (vi "Chờ duyệt", en "Waiting").
2. `REQUEST_STATUS_LABEL_KEYS[status]` (`apps/employee/src/shared/utils/request-status.ts`) — only PENDING/APPROVED/REJECTED/DRAFT/CANCELLED, **missing `waiting`**.
3. `common.status.${status}` — `common.status.waiting` MISSING.
Since link 1 resolves, the raw-render symptom is already handled on develop → report as
"likely fixed / verify live", and harden by adding `waiting` to the shared map + `common.status`.
Cross-MFE: the HR copy `apps/hr/src/shared/components/ApprovalListSection.tsx` uses
`getStatusLabel(status, tCommon)` → maps into `common.status.*` which lacks `waiting` →
would render raw if HR sees status `waiting`. Same component duplicated across MFEs with
different resolvers — check both.

## Bug 1 & 2 — nav button on list/card

- "view all" pattern present: `RequestSummaryCard.tsx` → `Button variant="secondary"`
  `onClick={() => navigate(PATHS.EMPLOYEE_REQUESTS)}` + key `dashboard.requests.viewAllAction`.
- Missing nav button (card-list bug): `AttendanceSummaryCard`, `LeaveBalanceCard`,
  `WorkScheduleCard` (dashboard feature) — Card only, no Button. Targets:
  `PATHS.EMPLOYEE_ATTENDANCE`, `PATHS.EMPLOYEE_TIME_OFF_MANAGEMENT`.
- Department list: `DirectoryUnitAccordionItem` only has `AccordionTrigger` (inline expand),
  no nav button; contrast `OrganizationChart.tsx` node = `Button onClick→onSelectDepartment`
  (already has nav). Confirm the exact screen (directory vs organization) before filing
  "missing nav button" — the org-chart nodes already navigate.
