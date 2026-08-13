# CRM Authz / Onboarding Contract — Reconciliation 2026-08-12

Spec files (local): `~/Projects/Hilo-Vppos/Documents/ERP/`
- `crm-authz-overview.md` — khái niệm, 4 lớp bảo vệ, error codes CRM-*
- `crm-authz-integration-api.md` — IdentityContext contract, header X-Auth-*, API reference authorization
- `crm-authz-flows.md` — Flow A–G business flows
- `crm-onboarding-integration-guide.md` — **contract mới nhất** (login/context/partner/staff/authorization + E2E verified 59/59 + 72/72)

## Key contract change (onboarding guide supersedes old auto-resolve)

- CRM **không còn auto-resolve** membership từ HR token. Token chưa có `membershipId` gọi `/crm/*` → `403 CRM-403-004`.
- Bắt buộc: `GET /auth/crm/contexts` (HR token) → user chọn `membershipId` → `POST /auth/crm/select-context` → CRM access token (cookie `access_token`, HttpOnly; FE dùng `withCredentials`, **không** token trong localStorage, **không** query string).
- Áp dụng **kể cả user chỉ có 1 context**. HR token vẫn dùng được cho route HR sau khi chọn context (token giữ HR identity).
- `POST /auth/crm/login` (email/password) trả `contextToken` + `contexts[]` — đường tương thích khi chưa có HR session.

## Business rules (user-confirmed / BE-verified)

- **Admin clone/assign template/system role: ĐƯỢC** (user chốt 2026-08-12). Admin = `CRM_SYSTEM_ADMIN` + scope `ALL`. Non-admin: chỉ custom role. → Docs conflict (Flow B "or caller is admin" vs API ref blanket vs onboarding §2.4 blanket) — cần BE cập nhật doc.
- Chỉ `CRM_SYSTEM_ADMIN` được assign `scope_type=ALL`; role khác gửi ALL → bị chặn.
- Đại lý (không admin) chỉ assign được `PARTNER` (hoặc `CUSTOMER`); `PARTNER_TREE`/`ORGANIZATION`/`TEAM`/`ALL`/`OWNED` → 403 CRM-403-002.
- Activate partner: chỉ user có `crm:partner:activate` (seed chỉ gán cho CRM_SYSTEM_ADMIN) — đại lý L1 KHÔNG activate được con (thiết kế duyệt). Activate sinh user + `temporaryPassword` + membership + tự gán `PARTNER_OWNER` (external → scope PARTNER; INTERNAL_STAFF → PARTNER_TREE).
- `POST /partners/:id/staff`: role chỉ `PARTNER_SALES/MANAGER/ACCOUNTANT/VIEWER` (KHÔNG `PARTNER_OWNER` → CRM-400-027); user mới → `isNewUser=true` + temporaryPassword; user cũ → `isNewUser=false`, không trả password.
- `POST /partners` tạo INACTIVE, chưa gán scope; scope gán lúc activate. L1 tạo L2 → L2 INACTIVE chờ admin activate.
- `commissionRate` field-protected: cần `crm:partner:commission_rate:manage` để gửi (PARTNER_OWNER chỉ có read).
- Scope đọc: PARTNER = chỉ partner mình (L1 đọc L2 → 403); PARTNER_TREE = cả cây con.
- Role ≠ scope: role = hành động, scope = phạm vi dữ liệu — 2 chiều độc lập.
- BUG-03 (mở): validation binding (thiếu field, sai email) trả 500 `internal_error` thay vì 400.
- Email external partner trùng user có sẵn → activate 409 (không tìm user theo email trước).

## Open BE blockers for FE

1. `GET /authorization/permissions` (catalog cho permission selector) — flows tham chiếu, API reference không có.
2. Pagination 2 format: integration spec `meta.pagination{page,pageSize,totalItems}` vs onboarding guide `meta{page,pageSize,totalItems,totalPages}` — repo convention = `meta.pagination` (AGENTS.md, cấm normalize 2 shape).
3. Xác nhận rule admin clone/assign template/system (docs mâu thuẫn).
4. `GET /auth/my` sau select-context: roleCodes/permissionKeys có phản ánh CRM context không? (source of truth cho user info).

## FE impact notes (erp-admin)

- Auth store hiện tại chỉ có `user` + `language` (persist `hilo-auth-v2`) — cần thêm selected context metadata (không persist token).
- API endpoints chưa có: `AUTH.CRM_CONTEXTS`, `AUTH.CRM_SELECT_CONTEXT`, `CRM.AUTHORIZATION.*`.
- Sale MFE (#108 Orders, #109 CA Dossier) gọi `/crm/*` → **bị chặn bởi 403 CRM-403-004** nếu chưa có context selection → context foundation là dependency của #108/#109.
- temporaryPassword: modal hiển thị 1 lần + copy + warning; không persist, không re-call (activate lần 2 → 409 CRM-409-001).
- Issue slices đề xuất: FE-1/FE-2 (context discovery + guard) → FE-3 (partner lifecycle+activate) → FE-5 (staff) → FE-6/FE-7 (role/permission/membership) → FE-8/FE-9 (permission-aware UI + audit).
