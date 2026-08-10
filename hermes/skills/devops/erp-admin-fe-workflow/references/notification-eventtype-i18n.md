# Notification eventType → i18n mapping (erp-admin)

Cách FE map eventType notification từ BE notify service (WebSocket push + REST hydrate) sang text hiển thị. **User preference 2026-08-10: dùng RAW dotted keys trực tiếp — KHÔNG normalize `.` → `_` (trước đây có lớp map gây rối, đã bỏ).**

## Kiến trúc

| File | Vai trò |
|---|---|
| `packages/shared/src/websocket/event-routing.ts` | `EVENT_ROUTES`: eventType → route navigate khi click notification; `getEventTypeI18nKey` |
| `packages/shared/src/websocket/notification-browser-event.ts` | `NOTIFICATION_EVENT_TYPES` constants (eventType FE tự phát) |
| `apps/shell/src/utils/notification-i18n.ts` | `resolveNotificationText(t, value)` — fallback chain dịch title/message |
| `apps/shell/src/components/NotificationToastHandler.tsx` | Toast: `useTranslations('common')`, title = resolve(title), description = resolve(payload.message/error/reason) |
| `apps/shell/src/components/topbar/NotificationBell.tsx` | List item cũng qua `resolveNotificationText` |
| `packages/locales/src/translations/{vi,en}/common.json` | Keys: `notification.message.<eventType>` / `notification.eventType.<eventType>` (namespace `common`) |

## Fallback chain `resolveNotificationText` (đã đơn giản hóa 2026-08-10)

```
notification.message.<raw value> → notification.eventType.<raw value> → errorCodes.<raw value> → raw value
```

- eventType/title BE gửi dạng dotted: `hr.request.approval.approved` → key `notification.eventType.hr.request.approval.approved` (i18next dotted path, hoạt động bình thường).
- `errorCodes.*` giữ dạng snake (BE error code thật), lookup dùng raw value luôn.
- **Bug pattern**: BE thêm eventType/title mới mà FE chưa có key → hiển thị RAW KEY (vd toast hiện `hr.request.approval.approved`). Khi user báo "hiện raw key" → check `notification.message.*`/`notification.eventType.*` trong common.json vi+en, thêm key + thêm `EVENT_ROUTES`.

## Danh sách eventType BE (xác nhận 2026-08-10, đủ 7/7)

```
hr.request.approval.pending              → Employee approval inbox
hr.request.approval.approved             → Employee approval inbox
hr.attendance.sheet.refresh.result       → /hr/attendances
hr.attendance.adjustment.bulk.succeeded  → /hr/attendances
hr.attendance.adjustment.bulk.failed     → /hr/attendances
hr.payroll.run.calculation.succeeded     → /hr/salary/periods
hr.payroll.run.calculation.failed        → /hr/salary/periods
```

FE còn giữ legacy keys (`hr.request.approved`, `hr.request.rejected`, `employee.request.approved`, `employee.request.rejected`) — KHÔNG xóa dù BE không còn gửi.

## Quy tắc khi thêm eventType mới

1. Thêm `notification.message.<eventType>` + `notification.eventType.<eventType>` vào **cả vi lẫn en** `common.json` (message = thông báo động, eventType = label).
2. Thêm vào `EVENT_ROUTES` (route navigate).
3. Dùng raw dotted key — không tạo biến thể gạch dưới.
4. Verify: JSON valid + rebuild `@hilo/locales` dist; test `apps/shell/src/utils/notification-i18n.test.ts` (3 cases: message, errorCodes, fallback literal).

## Pitfalls

- Toast dùng namespace `common`, KHÔNG phải `shell` (ADR 0001 ghi shell nhưng code thực tế common).
- Key mới thiếu ở en mà có ở vi → parity break; luôn thêm cả 2.
- `notification.eventType.<value>` lookup match trước tiên với value raw — nếu BE đổi format key (snake↔dotted) thì key cũ miss → hiện raw. Kiểm tra danh sách BE khi thấy raw key lạ.
