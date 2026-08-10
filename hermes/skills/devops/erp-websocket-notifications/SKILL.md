---
name: erp-websocket-notifications
description: Use when a toast shows a raw eventType key (missing i18n).
triggers:
  - toast or notification bell showing a raw i18n key like 'hr.request.approval.approved'
  - adding a new BE websocket eventType (translation text or click navigation)
  - editing notification translations or event routing in Hilo ERP
---

# ERP WebSocket Notifications (eventType → i18n + route)

Hilo ERP realtime notifications: BE notify service pushes WS messages + REST hydrate (docs/adr/0001, 0003). BE sends `eventType`, often `title`/`payload.message` **as translation key strings** — FE must map them or the UI shows the raw key.

## Symptom: raw key in toast/bell

Toast (or bell list item) shows something like `hr.request.approval.approved` instead of Vietnamese text → BE sent that value and no translation matched. Fix = add i18n keys (vi + en) + optionally EVENT_ROUTES entry.

## Where things live

| File | Role |
|------|------|
| `packages/shared/src/websocket/event-routing.ts` | `EVENT_ROUTES`: eventType → route on click; `getEventTypeI18nKey` |
| `apps/shell/src/utils/notification-i18n.ts` | `resolveNotificationText(t, value)` — the only translation resolver (toast + bell) |
| `packages/locales/src/translations/{vi,en}/common.json` | `notification.message.*` + `notification.eventType.*` — namespace `common`, NOT `shell` despite ADR 0001 |
| `packages/shared/src/websocket/notification-browser-event.ts` | `NOTIFICATION_EVENT_TYPES` constants (attendance/payroll events) |
| Consumers | `apps/shell/src/components/NotificationToastHandler.tsx` (toast), `NotificationBell.tsx` (list, same resolver) |

`resolveNotificationText` chain (namespace `common`):
`notification.message.${value}` → `notification.eventType.${value}` → `errorCodes.${value}` → raw `value`.

## USER PREFERENCE (2026-08-10, enforced): raw dotted keys — NO normalize layer

- common.json eventType keys use the RAW BE value: `notification.eventType.hr.payroll.run.calculation.failed`.
- DO NOT normalize `.`→`_` (`hr_payroll_run_calculation_failed`) and DO NOT add a key-mapping layer in code. User explicitly rejected the old normalize/strip chain in `notification-i18n.ts` ("đỡ map qua map lại").
- `errorCodes.*` keys stay snake_case — those are BE error codes (separate from eventTypes); lookup passes the raw error-code value through unchanged.

## Adding a new eventType (checklist)

1. `common.json` vi + en: `notification.message.<eventType>` (toast text) + `notification.eventType.<eventType>` (label) — ALWAYS both languages (parity rule).
2. `event-routing.ts` `EVENT_ROUTES`: `'<eventType>': PATHS.X` via PATHS constants (e.g. `PATHS.HR_ATTENDANCES`, `PATHS.HR_SALARY_PAYROLL_PERIODS`).
3. Only if code needs the constant: `NOTIFICATION_EVENT_TYPES` in `notification-browser-event.ts`.
4. Verify: JSON valid, `tsc -b` shared + shell, rebuild `@hilo/shared` + `@hilo/locales` dists (MFEs consume dist), vitest `apps/shell/src/utils/notification-i18n.test.ts`.

## Known BE eventTypes

Full list BE sends (2026-08-10, confirmed by user): `references/be-eventtypes-2026-08-10.md`. When BE adds more, ask for the authoritative list — don't guess.

## Pitfalls

- Toast handler uses `useTranslations('common')` — keys go in `common.json`, NOT `hr.json`/`shell.json`.
- Don't delete i18n keys/routes for eventTypes absent from the latest BE list (e.g. `hr.request.approved`, `employee.request.*` kept) — BE may still send them; keep unless BE confirms removal.
- Failed events render `toast.error` (`eventType.includes('failed'|'error')`) — the failed variant needs its own message key (real case: `hr.payroll.run.calculation.failed` was missing while `succeeded` existed).
- Legacy ADR 0001 says namespace `shell`; actual code uses `common` — trust the code.
