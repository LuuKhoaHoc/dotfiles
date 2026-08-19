---
name: erp-crm-onboarding
description: "Use for erp-admin CRM FE work: context, authz, partner."
---

# ERP CRM Onboarding — FE Integration Contract

Use when implementing/verifying CRM FE issues in erp-admin (context selection, partner lifecycle, authorization admin, sale/CKS API). BE-confirmed contract + workflow lessons (chốt 2026-08-12). Docs gốc: `~/Projects/Hilo-Vppos/Documents/ERP/crm-onboarding-integration-guide.md`, `crm-authz-overview.md`, `crm-authz-integration-api.md`, `crm-authz-flows.md`, `crm-cks-remote-sales-tmsra-integration.md`, `crm-standard-product-sales-integration.md`.

## Context selection — P0 dependency

- Mọi request `/crm/*` bằng token chưa có `membershipId` → `403 CRM-403-004`; BE KHÔNG auto-resolve. Flow: `GET /auth/crm/contexts` (HR token) → user chọn `membershipId` → `POST /auth/crm/select-context` → CRM token (cookie ưu tiên; cấm query string; FE không persist raw token — cookie HttpOnly).
- User có 1 context vẫn phải select. Membership lock/revoke → `contexts` không trả nữa → tải lại + yêu cầu chọn lại/logout.
- **Sale/CKS API (#108/#109) gọi `/crm/*` nên bị chặn bởi rule này** — context selection là dependency của chúng, phải làm trước.

## Authz rules (BE chốt 12/08/2026 — docs cũ có dòng mâu thuẫn)

- **`CRM_SYSTEM_ADMIN` ĐƯỢC clone/assign system/template role.** Onboarding guide ghi "Không clone/assign template/system role" + "admin cũng không gán được template/system role" (§1.5, §2.4, Flow 7/9, §7.3) = **OUTDATED** (issue #184 mang spec correction). Non-admin chỉ clone/assign custom role.
- Scope khi assign: non-admin chỉ `PARTNER`/`CUSTOMER` khớp context; admin mọi scope; **`ALL` chỉ với role `CRM_SYSTEM_ADMIN`** (DB constraint). Permission ceiling: chỉ gán được permission caller có.
- Role ≠ Scope: role = hành động, scope = phạm vi dữ liệu. `PARTNER` = chỉ mình; `PARTNER_TREE` = mình + cây con. INTERNAL_STAFF activate → `PARTNER_TREE`; đại lý ngoài activate → `PARTNER`. L1 (PARTNER) đọc L2 → 403 là đúng thiết kế.
- Activate: cần `crm:partner:activate` (seed: chỉ CRM_SYSTEM_ADMIN) — đại lý tạo con nhưng KHÔNG activate được con. `temporaryPassword` trả đúng 1 lần → UI modal copy + cảnh báo, cấm persist URL/cache/localStorage/log.
- Staff: chỉ 4 role `PARTNER_SALES/MANAGER/ACCOUNTANT/VIEWER` (không `PARTNER_OWNER`); `isNewUser=true` → temp password, `false` → không trả.
- `GET /authorization/permissions` TỒN TẠI (BE xác nhận 12/08, thiếu trong spec) — dùng cho permission selector; curl xác nhận shape trước khi code.

## Sale contract mới (12/08, thay sales.md cũ)

- Product `classification`: `STANDARD` / `CKS_USB_TOKEN` / `CKS_HSM_REMOTE`; product CKS bắt buộc 3 field `cksCertificateProfileCode`/`cksFormFactorCode`/`cksCertificatePurposeCode` (thiếu → `400 CRM-400-033`).
- Order: STANDARD = tạo DRAFT trống → `POST /orders/:id/items` (snapshot từ product); CKS = items inline + `draftFulfillmentInputs` (`fulfillmentType=CERTIFICATE_ISSUANCE`, DK011 form) + `isCKS: true`.
- **Dossier tạo tại CONFIRM** (không phải complete); complete bị `409 SYS-409-001` tới khi dossier ISSUED/ACTIVE. STANDARD complete → subscriptions[] + receivable (OPEN) + invoiceRequest (PENDING); customer → ACTIVE.
- TMS-RA: register qua TMSRA2 (`POST /crm/cks/tmsra/dossiers/:id/certificate`), sync qua `/sync`; register response `data` = **int 6000–6999** (không phải object); sync chỉ lọc được `filter.taxCode` nested. #109: phần dossier giữ `cks.md` cũ; doc CKS mới chỉ cho TMS-RA register/sync/state mapping.

## Partner/Đại lý — MFE RIÊNG (BA chốt 14/08/2026)

- Business đổi: **"luân chuyển" (chuyển đại lý) THUỘC module Đại lý/partner** (ban đầu define ở customers) — customers chỉ còn "chuyển dịch vụ của khách hàng" (AgentTransferModal cũ = semantic "chuyển khách hàng sang saler", chờ spec mới). **"Doanh thu"** = 3 sub-feature: doanh thu partners cấp dưới / theo sản phẩm / báo cáo — CHƯA có spec, sau này viết thẳng vào MFE partner. Sidebar có mục riêng "Đại lý" → module == MFE → MFE `partner` (label MFE::partner, route /partners, requiresCrmContext). Checklist tách MFE: `references/partner-mfe-split.md`.
- Partner FE lessons (review #183 14/08 — đã bắt agy fix):
  - Query keys: BẮT BUỘC dùng `QUERY_KEYS.CRM.PARTNERS*` (shared, prefix membershipId) — KHÔNG feature-local factory kiểu cũ (rò cache giữa context khi đổi context).
  - Permission: `User.permissionKeys` (đã có sẵn) + fallback `roleCodes` (CRM_SYSTEM_ADMIN/SUPER_ADMIN) + `crmContext.roles`; pattern = utils thuần nhận (user, crmContext) như `customer-permissions.ts`, KHÔNG phải hook. **Placement**: constant `CRM_PERMISSIONS` hiện chỉ 1 MFE (partner) dùng → để mfe-local `apps/partner/src/shared/constants/`, CHƯA harvest vào `@hilo/shared` (rule ≥3 MFE — audit 17/08 đánh premature harvest).
  - **StatusBadge dùng từ `@hilo/ui` bản promoted** (DEFAULT_TONE_MAP đã cover active/inactive/locked, `toneMap` prop cho status riêng domain) — CẤM tạo bản local ở MFE mới (audit 17/08: partner còn `apps/partner/src/shared/components/StatusBadge.tsx` duplicate + import ngược `features/` → xoá, import `@hilo/ui`).
  - Staff endpoint cần `crm:authorization:membership:manage` + `crm:authorization:assignment:manage` (guide truncate thành `member...age`/`assign...ge`) — verify curl `GET /authorization/permissions` trước khi code; cấm placeholder `crm:authorization:***`.
  - i18n validation: zod message key (`codeRequired`, `phoneTooShort`...) phải nằm trong `common.json errorCodes` nếu form lookup `errorCodes.*`; sẵn có chỉ `invalidEmail`/`invalidPhone`/`invalidNumber` — thiếu key → UI hiện raw key tiếng Anh.
  - PITFALL duplicate key JSON: trước khi thêm error code vào common.json, grep key đã tồn tại chưa — `JSON.parse` lấy giá trị CUỐI nên message mới bị shadow bởi key cũ ở cuối file (dính thật: CRM-403-001 + SYS-409-001 xuất hiện 2 lần, cả vi+en).

## User workflow preferences (đã đính chính nhiều lần)

- **Deploy checklist / draft mail cho QC: hiển thị TRỰC TIẾP trong chat** (bảng # / nội dung / "Kiểm tra cho QC" + mục cần xác nhận + out-of-scope + draft email). KHÔNG tạo file .md — user: "xóa file md này đi, gửi checklist giúp tôi thôi là được". Luôn fetch snapshot milestone mới trước khi soạn (status drift trong ngày).
- **File gửi RA NGOÀI (BA/management): .docx hoặc .pdf, KHÔNG .md** (user-corrected 2026-08-14: "Tôi muốn gửi file docx hoặc pdf chứ không phải markdown"). Markdown chỉ cho chat/internal; external deliverables là Word/PDF. Flow: docx skill → `docx_create.py spec.json out.docx` → `soffice --headless --convert-to pdf` nếu cần; thay emoji (✅⛔🔵) bằng text plain vì Word render xấu. Chi tiết + pitfalls trong skill `ba-status-report`.
- **Spec correction từ BE/PO:** ghi `**Spec correction (BE chốt <date>):**` vào issue description + nêu rõ section doc nào outdated. Trước khi khẳng định "spec nói X": grep đúng dòng trong doc, quote chính xác — bước trong sequence diagram là implication, KHÔNG phải explicit rule (2 lần bị user bắt bẻ vì diễn giải quá rộng).
- Issue tạo theo nhóm: title `[CRM] <mô tả>`, labels `crm,feature,frontend,status::todo,priority::high` (+`shell,shared` cho context selection; `MFE::partner` cho partner — KHÔNG còn `sale`), milestone patch tuần sau (v1.0.x — tạo milestone mới nếu chưa có), `due_date` độc lập (deadline có thể trước due của milestone). Label MFE mới chưa có → tạo theo pattern `MFE::<id>`: `glab label create --name "MFE::partner" --color "#6699cc"` (glab label create dùng `--name`, không phải positional).
- Docs BE tham chiếu trong issue: upload lên GitLab (`/uploads/...` link), không ghi tên file trần — curl `-F file=@` (glab api -F lỗi `file is invalid`); token ở `~/.config/glab-cli/config.yml`.

## Verification

- MFE gates: `node ../../node_modules/typescript/bin/tsc -b`, vitest/eslint/vite qua `node ../../node_modules/...` (pnpm shim chết trong Hermes terminal — xem `erp-admin-fe-workflow`).
- API mới: curl trước, ghi status vào issue (convention team).
- Snapshot issue map 08/2026: #182 context selection (SHIPPED MR !601), #183 MFE partner tách + onboarding (luukhoahoc, label MFE::partner), #184 authorization admin (luukhoahoc); #108 Orders, #109 CA Dossier (QuyCN) → milestone v1.0.5.
