---
name: mfe-onboarding-review
description: Use when reviewing a new MFE module added to a monorepo.
---

# MFE Onboarding Review

Use when reviewing a **brand-new MFE** (new `apps/<x>` module) being wired into a pnpm/Turbo monorepo with Module Federation — e.g. "review code của issue #183 (MFE partner mới)". Covers integration wiring (registry/shared/locales/CI) + verifying an issue checklist end-to-end. For deep audit of feature code *inside* an existing MFE, use `mfe-feature-audit` (user-owned); for general erp-admin FE verify gates see `erp-admin-fe-workflow` (user-owned).

## Workflow

1. **Issue first, code second**: `get_issue(project_id, issue_iid, full_response=true)` → issue chứa checklist (B-items/acceptance) dùng làm test suite. Tìm repo local (`~/Projects/Hilo-Vppos/erp-admin`), `git fetch origin --prune` rồi `git branch -vv` — **branch mới chưa ahead origin = toàn bộ diff nằm ở working tree** (`git status` là nguồn duy nhất).
2. **Triage working tree**: tách nhóm scope vs residue bằng `git diff --stat <path...>` theo nhóm. Prettier collapse-import (import multi-line → 1 line) ở file ngoài scope = residue task khác — không gán vào scope, hỏi user.
3. **Verify từng tầng** (chi tiết: `references/new-mfe-onboarding-checklist.md`):
   - Workspace: package.json (deps `@hilo/*`, scripts — nhớ `test` nếu có vitest.config), vite.config (federation exposes, base `/apps/<x>/`), tsconfig, vitest aliases.
   - Shell registry: `mfe-manifest.ts` + `entries.tsx` loader + `vite-env.d.ts` + `.env.example`.
   - Shared: `navigation.ts` APP_MODULES (categoryId, requiresCrmContext, features) + `paths.ts` + `endpoints.ts` (URL thật — block SALE có thể chứa endpoints `/crm/...`, hợp lệ nếu cùng contract CRM) + `query-keys.ts` context-scoped.
   - Locales: namespace `<x>.json` vi+en parity; đăng ký `i18n.ts`; MFE cũ sạch (grep key cũ = 0).
   - Move-code: grep MFE cũ không còn feature/PATHS cũ; shared component move → `@hilo/ui` + **rebuild dist** trước khi typecheck consumer (dist stale = TS2305).
   - **CI deploy — hay quên nhất**: `.gitlab-ci.yml` phải có `trigger:<x>` block (changes `apps/<x>/**/*` + packages, APP_NAME/APP_DIR/HELM_VALUE_FILE) + helm values. Case #183: code xong hết mà checklist "CI/deploy" vẫn trống.
4. **Chạy gates thật** (không tin lời tuyên bố): typecheck MFE + mọi workspace chạm (shared/locales/shell + MFE cũ khi move code), vitest feature + endpoints, build MFE. Báo PASS/FAIL từng checklist item.

## Pitfalls

- **Verify i18n key tồn tại**: recursive flat bằng dict-accumulate (`out.update(flat(v, np))`) — generator `yield from` dễ quên → false MISSING hàng loạt. Nhớ top-level wrapper: file `{ "partner": {...} }` → key đầy đủ là `partner.status.ACTIVE`.
- **Duplicate JSON keys**: `json.load(f, object_pairs_hook=list)` + walk; `json.loads` âm thầm lấy giá trị cuối, không báo dup.
- **Mọi zod `message: '...'` phải grep thấy trong locales**: case #183 `codeInvalidFormat` dùng trong regex nhưng thiếu key → form hiện raw key. Quét schemas ↔ locales.
- **Permission placeholder**: issue bảo "verify BE bằng curl trước khi code" mà code vẫn còn `crm:authorization:***` placeholder → chưa xong, đánh block (B-item tương ứng FAIL).
- **Không tin script check key viết vội**: sai recursion trong script tạo kết quả sai — double-check script trước khi tin output âm tính.
- **Sentinel 'ALL' lọt vào API params**: inline `SelectItem value={ALL_SENTINEL}` nối thẳng `onValueChange → setStatus/setQ` → sentinel nằm cả URL lẫn request params gửi lên BE (`?status=ALL`). Filter modal thường map sentinel→'' đúng còn select inline thì không — so sánh CẢ HAI surface (toolbar inline vs filter modal) khi audit filter.
- **`...options` spread sau `enabled:` trong shared query hook**: `enabled: Boolean(membershipId) && (options?.enabled ?? true), ...options` → caller truyền `enabled` đè mất guard membership. Sửa: spread options TRƯỚC, set `enabled` cuối. Grep pattern `?? true),\n    ...options` trong mọi hook query dùng chung.
- **Move component nhưng MFE mới vẫn giữ bản local**: move StatusBadge sale→`packages/ui`, nhưng MFE mới (partner) tạo bản thứ 3 ở `src/shared/components/` → 2-3 implementation lệch style/API. Grep symbol bị move ở CẢ MFE cũ lẫn MFE mới, so nội dung 2 bản nếu nghi ngờ.
- **shared → features import ngược (FSD)**: `apps/<x>/src/shared/*` KHÔNG được import từ `features/*` (case #183: `apps/partner/src/shared/components/StatusBadge.tsx:12-14` import `features/partners/constants/partner.constants` → vòng features→shared→features, shared là layer dưới). Grep pattern `src/shared/… → features/` trong audit; fix thường = xoá file local.
- **Harvest sớm vào `@hilo/shared`**: constant mới chỉ 1 MFE dùng → để mfe-local `apps/<x>/src/shared/constants/` (rule ≥3 MFE, `packages/shared/AGENTS.md:38-40`). Audit: `grep -rln <CONST> apps/ packages/ --include=*.ts --include=*.tsx` đếm consumer trước khi chấp nhận (case #183: `CRM_PERMISSIONS` chỉ partner dùng nhưng đặt ở `packages/shared/src/constants/permissions.ts` = premature harvest).
- **Hardcoded chuỗi tiếng Việt — quét CẢ form placeholder, không chỉ label**: grep non-ASCII toàn components/ — placeholder ("VD: …", "-- Không chọn --", "Mã số thuế doanh nghiệp"), inline label ("Thêm nhân viên cho đại lý") phá English UI (case #183 pass 3: `PartnerFormModal.tsx:177,218,233,251,268,287,305,341` + `PartnerStaffModal.tsx:93` — pass 1 chỉ bắt được h2/title/header). Mọi UI string qua i18n, thêm cả vi+en.
- **Optional toolbar props bị bỏ → dead controls**: table prop-driven với callback optional mà page không truyền → toolbar vẫn render nhưng bấm không tác dụng (case #183: `PartnerDetailPage.tsx:226-238` truyền `PartnerListTable` thiếu `onStatusChange/onPartnerTypeChange/onTierChange` → 3 Select ALL no-op). Truyền wiring đầy đủ hoặc ẩn toolbar ở context không dùng.
- **Check placeholder trong tests, không chỉ constants**: test assert `permissionKeys: ['crm:authorization:***']` → suite "xanh" trong khi code vẫn bug; khi constants chứa placeholder, grep `***` cả thư mục test (placeholder bị "đóng băng" vào test).
- **App dir untracked: verify .gitignore trước** (B7-style): `git check-ignore apps/<x>/{dist,node_modules,.__mf__temp}` — không ignore thì `git add apps/<x>` cuốn dist vào commit.
- **Gán scope theo usage thật**: icon mới trong packages/icons (SVG + custom.ts + types.d.ts) có thể chỉ được dùng bởi shell (MenuIcon active-state), KHÔNG phải MFE đang review → grep toàn repo trước khi gán vào scope; không khớp → báo 'ngoài scope', đề xuất tách MR.
- **Dead code qua feature index**: API fn + query hook export `*` qua `features/<x>/index.ts` nhưng không page nào consume (`useMyPartnerQuery`, `deletePartnerApi`) — check từng export có usage thật không.
- **Locale leftover key = scope gap**: key i18n khai báo (`tabs.staff`) nhưng UI chưa có tab tương ứng → dấu hiệu scope chưa implement, đưa vào findings.

## References

- `references/new-mfe-onboarding-checklist.md` — checklist 7 tầng chi tiết + lệnh grep cụ thể + case #183 partner MFE (follow-up pass 2: mục đã fix + phát hiện mới kèm file:line; pass 3: audit convention-code — FSD reverse import, harvest sớm @hilo/shared, hardcoded vi string trong form, envelope contract 08-05).
- `scripts/locale-parity-check.py` — verify parity vi/en + duplicate keys cho namespace JSON (re-run: `python3 scripts/locale-parity-check.py vi/<ns>.json en/<ns>.json [common.json...]`).
