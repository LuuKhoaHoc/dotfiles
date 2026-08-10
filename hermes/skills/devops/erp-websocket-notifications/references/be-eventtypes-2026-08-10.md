# BE eventType list (confirmed by user 2026-08-10)

Full set of eventTypes the notify service sends — source: user-provided list, 2026-08-10:

```
hr.request.approval.pending
hr.request.approval.approved
hr.attendance.sheet.refresh.result
hr.attendance.adjustment.bulk.succeeded
hr.attendance.adjustment.bulk.failed
hr.payroll.run.calculation.succeeded
hr.payroll.run.calculation.failed
```

FE also keeps legacy keys NOT in this list (kept deliberately — BE may still send them): `hr.request.approved`, `hr.request.rejected`, `employee.request.approved`, `employee.request.rejected`.

## Worked fix 2026-08-10 (toast showed raw key `hr.request.approval.approved`)

Missing at the time:
- i18n: `hr.request.approval.approved` (vi/en), `hr.payroll.run.calculation.failed`, `hr.attendance.adjustment.bulk.succeeded/failed`
- EVENT_ROUTES entries for attendance + payroll events (click → PATHS.HR_ATTENDANCES / PATHS.HR_SALARY_PAYROLL_PERIODS)

Fix applied:
1. Added vi/en `notification.message.*` + `notification.eventType.*` keys (raw dotted form, per user preference).
2. Added EVENT_ROUTES entries.
3. Simplified `resolveNotificationText` to the raw chain (removed `.`→`_` normalize + strip-module-prefix variants).
4. Updated `notification-i18n.test.ts` (dotted message key; errorCodes test now passes the snake_case error code raw).

Verification used: `python3 -m json.tool` both locales, `tsc -b` shared + shell, rebuild `@hilo/shared` + `@hilo/locales` dists, vitest `apps/shell/src/utils/notification-i18n.test.ts` (3/3), prettier --check, eslint.
