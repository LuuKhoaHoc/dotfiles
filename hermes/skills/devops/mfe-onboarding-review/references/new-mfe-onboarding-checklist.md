# New MFE Onboarding Checklist — case #183 (partner MFE, 2026-08-14)

Worked example: `[CRM] MFE partner: Onboarding đại lý` (gitlab.vppos.vn, project id 9, repo `~/Projects/Hilo-Vppos/erp-admin`, branch `feat/183-partner-mfe`, toàn bộ diff ở working tree chưa commit).

## Checklist 7 tầng (kèm lệnh verify)

### 1. Workspace `apps/<x>/`
- `package.json`: name `partner`, deps `@hilo/{config,icons,locales,shared,tokens,ui}` workspace + react 19 + zustand + @tanstack/react-query + radix-ui; scripts `dev/build/lint/typecheck` — **thiếu script `test` dù có vitest.config** (case #183, nit).
- `vite.config.ts`: federation exposes `'./App': './src/mfe-entry.tsx'`, base `VITE_BASE_URL || '/apps/partner/'`, port 5007 (convention 5000+), `FEDERATION_SHARED_DEPENDENCIES` singleton.
- `vitest.config.ts`: aliases đủ (`@hilo/shared/*` subpaths + `@hilo/ui` → src/index.ts).
- `main.tsx`: `MfeStandaloneWrapper i18n={i18n} appSource="partner" basename="/apps/partner"` + StandaloneErrorBoundary + QueryClient.

### 2. Shell registry
- `apps/shell/src/registry/mfe-manifest.ts`: `{ id, federationName, envKey: 'VITE_PARTNER_REMOTE_URL', fallbackBase: '/apps/partner' }`.
- `apps/shell/src/registry/entries.tsx`: `partner: () => import('partner/App')`.
- `apps/shell/src/vite-env.d.ts`: `declare module 'partner/App'`.
- `.env.example`: `VITE_PARTNER_REMOTE_URL=http://localhost:5007/apps/partner`.

### 3. Shared
- `packages/shared/src/config/navigation.ts`: APP_MODULES thêm module `partner` (categoryId SALES, `requiresCrmContext: true`, features `partners`); **sale module phải bỏ feature partners** (grep `id: 'partners'` trong block sale = 0).
- `packages/shared/src/constants/paths.ts`: `PARTNERS: '/partners'` + `PARTNER_DETAIL: '/partners/:id'`; PATHS cũ (`SALE_PARTNERS`) xóa hẳn.
- `packages/shared/src/api/endpoints.ts`: `PARTNERS*` thêm vào **block SALE** với URL `/crm/partners...` — hợp lệ vì block SALE đã chứa CUSTOMERS/ORDERS cùng contract CRM. Đừng tưởng phải tạo block CRM riêng.
- `packages/shared/src/api/query-keys.ts`: `QUERY_KEYS.CRM.PARTNERS(membershipId, params?)` / `PARTNER_DETAIL` / `PARTNER_MY` — context-scoped, FE không tự đặt key literal.

### 4. Locales
- `packages/locales/src/translations/{vi,en}/partner.json` — **top-level wrapper `{ "partner": {...} }`** → `useTranslations('partner')` + `t('partner.status.ACTIVE')`.
- Parity check (vi/en 102 keys = nhau, diff rỗng; pass 3 xác nhận 106 keys, vẫn parity 100%):
  ```python
  def flat(o, p=''):
      out = {}
      for k, v in o.items():
          np = f'{p}.{k}' if p else k
          if isinstance(v, dict): out.update(flat(v, np))   # dict-accumulate, KHÔNG generator
          else: out[np] = v
      return out
  ```
- `i18n.ts`: import + đăng ký `partner` namespace cả vi/en.
- MFE cũ sạch: `grep -c '"partner\.' sale.json` = 0.

### 5. Move-code cleanup
- `grep -rln "features/partners\|SALE_PARTNERS\|SALE_PARTNER_DETAIL" apps/sale/src` = rỗng.
- Shared component move (StatusBadge: sale `src/shared/components/` → `packages/ui/src/components/customs/`): export qua `packages/ui/src/index.ts` + **`pnpm --filter @hilo/ui build` trước** khi typecheck sale/partner (dist stale = TS2305); sale import chuyển sang `@hilo/ui` (grep xác nhận).
- **MFE mới phải CONSUME component vừa promote — grep `apps/<x>/src/shared/` còn bản local không** (pass 3: partner vẫn giữ `apps/partner/src/shared/components/StatusBadge.tsx` + `shared/index.ts` re-export, dù @hilo/ui bản promoted đã cover `active/inactive/locked` trong DEFAULT_TONE_MAP).

### 6. CI deploy — hay quên nhất
- `.gitlab-ci.yml`: mỗi MFE có block `trigger:<x>` extends `.trigger_template` (rules `changes: apps/<x>/**/* + packages/**/* + ...`, variables APP_NAME/APP_DIR/HELM_VALUE_FILE). **Case #183: chưa có `trigger:partner` + chưa có helm values → checklist "CI/deploy image tag" FAIL** (pass 2: đã có — `APP_DIR: partner` không prefix `apps/`).

### 7. Issue checklist làm test suite
- `get_issue(full_response=true)` → đối chiếu từng B-item/acceptance:
  - B1 duplicate JSON keys: `json.load(f, object_pairs_hook=list)` + walk — hết dup = PASS.
  - B2 permission placeholder: grep `***` trong utils — còn `crm:authorization:***` duplicate = **FAIL (block)**, issue yêu cầu curl BE `/authorization/permissions` trước.
  - B3 validation keys: 8 key có trong `common.json errorCodes` = PASS — nhưng quét thêm mọi `message: '...'` trong schemas: `codeInvalidFormat` thiếu = FAIL mới.
  - B4 sub-tab handlers wired = PASS (grep callback không phải `() => {}`).
  - B5/B8: header key + toast key i18n = PASS.
  - B6 `enabled: open` trên query trong modal = PASS.
  - B9 type thu về `number` = PASS (chưa verify BE contract — note).
  - B10 `QUERY_KEYS.CRM.PARTNERS` thay literal = PASS.
- Gates: typecheck 5 workspace (partner, sale, @hilo/shared, @hilo/locales, shell) + vitest feature + endpoints + build MFE — chạy qua mise (xem `erp-admin-fe-workflow` Linux section).

## Findings UI tổng thể (case #183)

- 🔴 hardcoded tiếng Việt: `Liên hệ & Chính sách` (PartnerDetailInfoCard h2), `title='Ẩn'/'Hiện'` (TemporaryPasswordModal), `MST:` (header) — pass 2 xác nhận 3 chỗ này đã i18n xong.
- 🔵 `TIER_BG_MAP` duplicate y hệt ở `usePartnerListColumns.tsx` + `PartnerDetailHeader.tsx` → extract 1 nơi (pass 2: đã gom về constants).
- 🔵 `PARTNER_TIERS_OPTIONS` là function trả JSX đặt sau component (nên inline/component).
- 🔵 `TooltipProvider` trong từng row cell (nên root 1 lần).
- 🔵 `StatusBadge.DEFAULT_TONE_MAP` thiếu `inactive` → partner INACTIVE hiện tone neutral (pass 2: bản `@hilo/ui` đã có đủ, kèm `toneMap` prop).
- ✅ Kiến trúc chuẩn: DTO-first, URL-backed list state (`usePartnerListUrlState`), permission-gated actions, error/empty/loading đủ, temp-password flow sau activate/staff, lazy sub-partners theo tab (`enabled: Boolean(id && activeTab)`).
- ✅ **Envelope contract mới (2026-08-05) tuân thủ đúng**: `apis/partners.ts` trả `ApiResponse<PartnerListItemDto[]>` (array thẳng ở `data`, KHÔNG `{list,total}`), page đọc `meta.pagination.totalItems` (`PartnerListPage.tsx:155`) — partner là MFE đầu tiên theo contract này. Lưu ý doc `canonical-list-wiring-pattern-2026-07-27.md` vẫn vẽ shape `PaginatedData{list,total}` (CŨ) — khi audit list/detail MỚI, theo envelope 08-05, không bắt buộc khớp doc cũ.

## Follow-up pass 2 (2026-08-17) — verify sau fix

Gates chạy thật: `pnpm vitest run` (apps/partner) → **30/30 PASS**; `pnpm typecheck` (partner) → clean; parity vi/en partner.json **106 keys = nhau, dup=[]** (cả 4 file common/partner, qua `object_pairs_hook`).

### Đã RESOLVED so với pass 1
- Hardcoded tiếng Việt (Liên hệ & Chính sách, Ẩn/Hiện, MST:) → hết, dùng key i18n.
- `TIER_BG_MAP` duplicate trong pages → gom về `constants/partner.constants.ts` (cả columns lẫn header dùng chung).
- `StatusBadge.DEFAULT_TONE_MAP` thiếu `inactive` → bản `@hilo/ui` mới có đủ draft/fulfilling/completed/cancelled/active/inactive/prospect/locked; `toneMap` prop + toLowerCase lookup.
- B5 columnActions header, B8 toast copy i18n, B10 QUERY_KEYS, B7 scratch (git check-ignore pass cho dist/node_modules/.__mf__temp) → PASS.
- Schema ↔ locales: đủ 12 validation keys trong `errorCodes` vi+en (vượt mức 8 của checklist).

### VẪN FAIL / phát hiện mới (file:line)
- 🔴 **B2 chưa fix thật**: `packages/shared/src/constants/permissions.ts:16-17` vẫn `'crm:authorization:***'` — 2 key trùng giá trị → `hasPermission` membership vs assignment là một check (tautology), nhánh permission của `canCreateStaff` (partner-permissions.ts:73-78) chết, staff chỉ qua fallback role. **Test phản chiếu placeholder**: `partner-permissions.test.ts:99-107` — 2 test trùng nhau assert `permissionKeys: ['crm:authorization:***']` → suite xanh nhưng code sai (pitfall: grep `***` cả test, không chỉ constants).
- 🔴 **Sentinel leak**: `PartnerListPage.tsx:86-89` gửi thẳng `status: status || undefined`; `PartnerListTable.tsx:121,135,149` SelectItem value=`ALL_SENTINEL`('ALL') nối thẳng `onStatusChange/setStatus` → chọn "Tất cả" → URL `?status=ALL` → API nhận `status='ALL'`. Filter modal map đúng sentinel→'' (`PartnerFilterModal.tsx:158-161`), inline select thì KHÔNG.
- 🟡 **StatusBadge bản thứ 3**: `apps/partner/src/shared/components/StatusBadge.tsx` + `shared/index.ts:1`, import tại `usePartnerListColumns.tsx:11` + `PartnerDetailHeader.tsx:6` — lệch style với bản @hilo/ui (outline vs border-0 rounded-full). → xóa `apps/partner/src/shared/`, import từ `@hilo/ui`.
- 🟡 **`...options` đè guard enabled**: `usePartnerQueries.ts:21-22,36-37,50-51` (`enabled: Boolean(membershipId) && (options?.enabled ?? true)` rồi spread) — caller `PartnerFormModal.tsx:390`, `PartnerFilterModal.tsx:41`, `PartnerDetailPage.tsx:68` truyền `enabled` → bypass guard.
- 🟡 **Dead code**: `getMyPartnerApi`/`useMyPartnerQuery` (partners.ts:44, usePartnerQueries.ts:41-53) + `deletePartnerApi` (partners.ts:75) không page nào dùng.
- 🟡 `setTimeout` copy không cleanup (TemporaryPasswordModal.tsx:33); `phoneTooShort` message "10 characters" vs schema `min(8)` (partner.schema.ts:33); edit không clear được field (`''→undefined` bị bỏ payload, PartnerFormModal.tsx:127-135; tier 'none' gửi undefined không phải null); parent options chỉ 20 record đầu (PartnerFormModal.tsx:388-391, PartnerFilterModal.tsx:39-43) → nên dùng `AsyncPaginatedCombobox`.
- 🟡 **Icons Inventory2/workshop2 → 'ngoài scope'**: chỉ dùng bởi `apps/shell/src/components/topbar/MenuIcon.tsx:23,39,86,89` (active-state variants); partner module dùng icon `Workshop` đã có sẵn (navigation.ts:104) → tách khỏi MR này.
- 🟡 Working tree lẫn file ngoài scope (apps/hr/*, employee/*, apps-dashboard/icon-registry, useNotification + tests, docs, AGENTS.md, lockfile ~7300 dòng) → commit theo từng file, cấm `git add -A`.
- 🟡 Locale leftover: `tabs.staff` (chưa có tab staff UI), `messages.createError/editError/activateError/staffError`, `employeePickerPlaceholder` — key chưa consumer = scope gap.

### Phương pháp verify dùng được (pass 2)
- Enumerate app mới: `find . -path ./node_modules -prune -o -type f -print` (không lẫn dist/node_modules).
- Verify CI: `grep -n "APP_DIR:" .gitlab-ci.yml` — convention `APP_DIR: partner` (không prefix apps/); helm `values-<x>.yaml` image tag sẽ được CI thay.
- Env/port khớp: `.env.example` `VITE_PARTNER_REMOTE_URL=http://localhost:5007/apps/partner` ↔ vite port 5007 + base `/apps/partner/` ↔ shell manifest envKey.

## Pass 3 — convention audit convention-code (2026-08-17, working tree HIỆN TẠI)

Khác pass 2 (audit theo checklist issue/UI), pass 3 đối chiếu code với **AGENTS.md + docs/solutions** (conventions bắt buộc). Gates: `pnpm --filter partner exec vitest run src/features/partners` 30/30 PASS; typecheck partner + @hilo/shared PASS.

### Phát hiện MỚI (pass 2 chưa có)
- 🔴 **shared → features import ngược (FSD)**: `apps/partner/src/shared/components/StatusBadge.tsx:12-14` import `../../features/partners/constants/partner.constants` — shared layer phụ thuộc features = ngược hướng + vòng features→shared→features (`AGENTS.md:138` cấm deep-import qua feature boundaries). Hết hiệu lực khi xoá file local (fix kèm mục StatusBadge).
- 🔴 **Hardcoded tiếng Việt còn 9 chỗ mà pass 1-2 bỏ sót** (grep non-ASCII components/): `PartnerFormModal.tsx:177` `placeholder="VD: OBF-L1-001"`, `:218` "Tên đại lý hoặc tên đối tác", `:233` "Nhập ID nhân viên nội bộ (UUID)", `:251,268,305,341` ("0901234567", "daily@example.com", "Mã số thuế doanh nghiệp", "VD: 15"), `:287` `"-- Không chọn --"`, `PartnerStaffModal.tsx:93` "Thêm nhân viên cho đại lý " — pass 2 ghi "hardcoded → hết" chỉ đúng cho h2/title/header; placeholder + inline label form chưa i18n → phá English UI (`packages/locales/AGENTS.md:33-34`).
- 🟡 **Harvest sớm `CRM_PERMISSIONS` vào @hilo/shared**: `packages/shared/src/constants/permissions.ts` mới — grep xác nhận **chỉ partner consume** → vi phạm rule ≥3 MFE (`packages/shared/AGENTS.md:38-40`, MFE-first `AGENTS.md:242`); nên để `apps/partner/src/shared/constants/` tới khi sale dùng chung. (Bản thân việc phải có constant-permission thì đúng — chỉ sai chỗ đặt.)
- 🟡 **Dead toolbar sub-partners tab**: `PartnerDetailPage.tsx:226-238` truyền `PartnerListTable` thiếu `status/partnerType/tier` + `onStatusChange/onPartnerTypeChange/onTierChange` → toolbar mặc định render 3 Select ALL nhưng bấm no-op (`PartnerListTable.tsx:121-161` callback optional-chaining). Truyền wiring hoặc ẩn toolbar.
- 🟡 **Sub-list pagination không URL-backed**: `PartnerDetailPage.tsx:48-49` `subPage/subPageSize` = `useState` (list chính thì URL-backed) — fetch state không sống qua refresh/back (`AGENTS.md:134`); chấp nhận được nếu coi là UI state của tab, nhưng không nhất quán.
- 🟡 **i18n naming lệch flatten rule**: `partner.partnerName` cho DTO field `name` (`PartnerDetailInfoCard.tsx:31`, `usePartnerListColumns.tsx:57`, `PartnerFormModal.tsx:212`) — convention `{entity}.{fieldName}` = `partner.name` (`AGENTS.md:158-167`); `partner.name` hiện bị chiếm bởi module label → module dùng `modules.partner.name` (đã có), trả `partner.name` cho DTO field.
- 🟡 **Nit**: `DEFAULT_PARTNER_PAGE_SIZE || DEFAULT_LIST_VIEW_PAGE_SIZE` dead (`usePartnerListUrlState.ts:22`); `PATHS.PARTNER_DETAIL` defined nhưng không dùng (`usePartnerListColumns.tsx:42,156` build `${PATHS.PARTNERS}/${item.id}` tay); `navigation.ts:123` đổi icon product Invoicing→Inventory ngoài scope; `employee.json` chỉ EOF newline (bỏ khỏi commit).
- ✅ **Xác nhận tuân thủ**: API dumb + `ApiResponse<T>` đúng envelope 08-05 (xem mục trên); hooks ∈ `hooks/`; Const Object Enum 3 bước (`partner.constants.ts`); mutation+toast ở component layer; 4 UI states đủ (skeleton/error+retry/empty); i18n enum key flatten (`partner.status.ACTIVE`) dùng chung mọi surface.

### Bài học audit (dùng lại được)
- **Đừng tin pass trước claim "đã hết"** về hardcoded string — chạy lại `grep -rP '[\p{Han}\p{Vietnamese}]' apps/<x>/src` (hoặc grep "VD:\|-- Không chọn --\|Mã số" mẫu thực tế) trên working tree hiện tại.
- **So pattern với 2 reference**: hạ tầng so `apps/product` (cấu trúc FSD giống), feature CRUD so `apps/sale` customers (`useCustomerCreate/Edit/...` push-state-down + TanStack Form + form tách section) — partner lệch ở: page chứa ~100 dòng business (`PartnerListPage.tsx:54-152`, `PartnerDetailPage.tsx:47-122`), form useState+safeParse thủ công (`PartnerFormModal.tsx:71-154` — 425 dòng 1 khối), parent options Select tĩnh page-1 thay vì `AsyncPaginatedCombobox` (`@hilo/ui` AGENTS.md:37).