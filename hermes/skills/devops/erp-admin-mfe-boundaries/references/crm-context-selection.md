# Issue #182 — CRM Context Selection: BE contract + FE state

Nguồn: `scratch/crm-onboarding-integration-guide.md` (trong repo erp-admin) + handoff `~/Documents/ERP/issue-182-crm-context-selection-handoff.md` (2026-08-12).

## BE contract (đã verify từ spec)

- Mọi `/crm/*` với token chưa có `membershipId` → `403 CRM-403-004` (BE **không còn auto-resolve** membership từ HR token; kể cả user chỉ có 1 context vẫn phải select).
- `GET /auth/crm/contexts` [HR token, cookie ưu tiên] → `CRMContextSummary[]`: `membershipId`, `contextType` (`ORGANIZATION|PARTNER|CUSTOMER`), `contextId`, `contextCode`, `contextName`, `displayName`, `roles[]`, `isDefault`. User không có membership → mảng rỗng.
- `POST /auth/crm/select-context {membershipId}` → response **giống LoginResponse** (user/session/accessToken/...); token mới **giữ nguyên HR identity + HR permissions**. Auth bằng cookie `access_token` ưu tiên hơn Authorization header; không chấp nhận token qua query string.
- `POST /auth/crm/login` chỉ là fallback (trả `contextToken` ngắn hạn + `contexts[]`) cho app chưa có HR session — app có HR session dùng `GET /auth/crm/contexts`.
- **Membership LOCKED**: `GET /auth/crm/contexts` không còn trả membership bị lock; token chưa chọn context gọi CRM → cũng trả `CRM-403-004` (cùng code với "chưa chọn context"). FE phân biệt bằng cách reload contexts rồi đối chiếu `membershipId` hiện tại — không dựa vào error code.
- 403 codes: `CRM-403-001` tree access ngoài phạm vi, `CRM-403-002` authz denied (gồm clone/assign template/system role — kể cả admin cũng bị chặn), `CRM-403-003` scope mismatch, `CRM-403-004` chưa chọn context.
- Validation binding lỗi (thiếu field, sai email) hiện trả `500 internal_error` thay vì `400` (BUG-03 đang mở).

## FE state hiện tại (đã grep verify 2026-08-12)

- `API_ENDPOINTS.AUTH` **chưa có** `CRM_CONTEXTS` / `SELECT_CONTEXT` (chỉ có LOGIN/LOGIN_CHECK/ME/REFRESH/LOGOUT...).
- Guards trong `apps/shell/src/guards/`: `AuthGuard`, `GuestGuard`, `AdminGuard`, `RoleGuard` — **chưa có** `CrmContextGuard`.
- `query-keys.ts` chưa có prefix `crm`; MFE dùng key feature-local (sale `['orders']`, finance `REPORTS_DASHBOARD_QUERY_KEY`).
- `useAuthStore` (`packages/shared/src/auth/store.ts`): persist `hilo-auth-v2`, `partialize` chỉ `user` + `language` — muốn thêm `crmContext` phải sửa cả `partialize` lẫn `merge`.

## Đã chốt trong handoff (không hỏi lại)

1. Cờ `requiresCrmContext?: boolean` trong `AppModule` (`packages/shared/src/config/navigation.ts`); bật cho `sale`, `product`, `finance`; shell bọc `CrmContextGuard`; HR/employee không đụng.
2. UX: luôn mở Dialog Picker khi cần chọn context (kể cả 1 context — pre-select `isDefault`, Enter/Tiếp tục); animation card "Đang thiết lập không gian làm việc..."; Topbar badge/switcher luôn hiển thị khi ở module CRM.
3. Interceptor 403 `CRM-403-004`: giữ request vào `failedCrmQueue`, mở picker, replay sau khi chọn; chống loop bằng `originalRequest._crmRetry` (tối đa 1 lần/request); hủy modal khi đang ở trang CRM → redirect `/hr` hoặc `/`.

## Đang grill dở (2026-08-12)

- Q4.1: cache invalidation khi switch context — `removeQueries(['crm'])` KHÔNG chạm cache remote (xem SKILL.md §1); đề xuất Option A = full reload sau animation card.
- Q4.2: persist `crmContext` (DTO metadata, không token) trong `hilo-auth-v2` + restore khi boot + clear khi logout.
- Q5: sau select-context có cần gọi lại `/auth/my` không → BE trả `user` trong response select-context và token giữ nguyên HR identity → KHÔNG cần; `setUser(response.data.user)` trực tiếp.
- Q6: phân bổ — API + hooks + types + query keys + store ở `packages/shared` (cross-cutting, ≥3 MFE); UI (`CrmContextPickerDialog`, `CrmContextSwitcher`, `CrmContextGuard`) ở `apps/shell/src/features/crm-context/`.
