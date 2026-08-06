---
name: erp-admin-branding
description: Use when adding/swapping company logos or VITE_* env vars.
triggers:
  - adding or swapping company/organization logos (vppos/hilo) in any app
  - adding a new VITE_* build-time env var to erp-admin
  - payroll slip or PDF branding (logo, company name/address) work
  - changing per-company behavior keyed on the deployment target
---

# ERP Admin — Per-Company Branding & Build-time Env

Pattern cho branding theo công ty (vppos | hilo) trong Hilo ERP monorepo (`Projects/Hilo-Vppos/erp-admin`). Cùng 1 codebase build cho 2 công ty: **main (prod) = hilo**, **develop (UAT) = vppos** — nên chọn branding lúc BUILD (env), không phải runtime. Organization API hiện KHÔNG có field logo → logo phải bundle sẵn, chọn theo env.

## Core pattern (đã verify)

- **Giá trị string (company code) là constants trong `@hilo/shared`** — ví dụ `COMPANY_CODES = { VPPOS: 'vppos', HILO: 'hilo' } as const` + type `CompanyCode` trong `packages/shared/src/constants/common.ts`. **KHÔNG check magic string (`=== 'hilo'`) trực tiếp trong app code — user bắt buộc** (constants/index.ts re-export `export *` nên tự lộ ra từ `@hilo/shared`).
- **Đọc env ở APP source, không ở package**: `@hilo/shared`, `@hilo/icons` build ra dist và consume qua Module Federation; `import.meta.env` chỉ được Vite transform chắc chắn ở source của app (lib build có thể replace `import.meta.env` thành `{}`). Resolver nằm ở app: `import.meta.env.VITE_COMPANY_CODE?.toLowerCase() ?? COMPANY_CODES.VPPOS`.
- **Logo phải là asset bundle sẵn, KHÔNG phải URL remote**: PDF export vẽ qua canvas → remote URL dính CORS/taint (toDataURL ném lỗi). `@hilo/icons` lib build INLINE PNG thành base64 data URL (verify: `grep -c "data:image/png;base64" packages/icons/dist/index.js` = số logo, không có file asset riêng) → an toàn cho cả `<img>` lẫn `loadImage` canvas.
- **Khi thêm VITE_ var mới — checklist đầy đủ (user bắt buộc cả 2 mục đánh dấu ★)**:
  1. ★ `.env.example` — bổ sung kèm comment (giá trị mặc định vppos)
  2. ★ typing: `apps/<app>/src/vite-env.d.ts` — `interface ImportMetaEnv { readonly VITE_X?: string }`
  3. `Dockerfile` (builder stage): `ARG VITE_X` + `ENV VITE_X=$VITE_X`
  4. `.gitlab/ci/base.gitlab-ci.yml`: `export VITE_X="..."` theo branch (main→hilo, develop→vppos) + thêm `--build-arg VITE_X=$VITE_X` vào `build_job` docker build — **CHỈ thêm `--build-arg` khi CI thực sự set biến**; override không set trong CI (vd `VITE_COMPANY_NAME`/`VITE_COMPANY_ADDRESS`) thì bỏ khỏi CI build-arg (build-arg rỗng = vô nghĩa, reviewer chặn), chỉ giữ Dockerfile ARG/ENV cho build tay
  5. `scripts/deploy-uat.sh`: `--build-arg VITE_X="vppos"` cho app dùng nó
  6. Dùng trong code qua resolver (điểm 2 của pattern)

## Files thường chạm (vd payroll slip logo)

- `packages/icons/src/custom.ts` + `src/types.d.ts`: export `XxxLogoUrl` từ `./assets/logos/*.png` (types.d.ts là source của dist declarations — copy plugin tự đồng bộ)
- `packages/shared/src/constants/common.ts`: `COMPANY_CODES` + type
- App: resolver file (vd `apps/hr/src/features/salary/constants/payroll-company.ts`) + `vite-env.d.ts`
- Component dùng logo: HTML view (`<img src alt>`) + PDF util (`loadImage`)
- Deploy plumbing (mục 3–5 ở trên)

## Full brand config — KHÔNG dừng ở logo (đã verify payroll slip)

Branding của một surface (vd phiếu lương) là **một object brand duy nhất**: logo + màu + tên/địa chỉ công ty pháp lý, để HTML view lẫn PDF export dùng chung 1 nguồn:

- `PAYROLL_COMPANY_BRANDS: Record<CompanyCode, PayrollCompanyBrand>` đặt trong resolver file. Mỗi brand: `logoUrl`, `logoAlt`, `companyName`, `companyAddress`, `colors { primary, accent, gradientStart, gradientEnd, border, light, periodBorder, periodText }`.
- Gộp palette: `PAYROLL_SLIP_NEUTRAL_COLORS` (màu neutral dùng chung: white/ink/line/panel/panelBorder/divider/titleBlue/amountText/footerText...) spread với `brand.colors` → 1 `payrollCompanyColors`. Cả HTML (`PAYSLIP_COLORS`) lẫn PDF (`PDF_COLORS`) đọc từ đây — **xoá object palette hardcode trùng lặp trong PDF util**, đừng để 2 nguồn màu lệch nhau.
- **Tên/địa chỉ công ty nằm TRONG brand config, KHÔNG phải i18n**: `payrollCompanyName = VITE_COMPANY_NAME?.trim() || brand.companyName` (address tương tự). Env override thắng, brand là mặc định. Component dùng thẳng biến — **KHÔNG viết `?? t('...companyName')`**: brand luôn có string nên fallback i18n là dead code (reviewer chặn). i18n keys `payrollSlip.companyName`/`companyAddress` đã XÓA khỏi en+vi — legal identity không phải translation.
- **Copyright dựng động**: `© ${new Date().getFullYear()} ${companyName}. ${t('...copyright')}` với key i18n `copyright` giờ là **suffix-only** (vi `MỌI QUYỀN ĐƯỢC BẢO LƯU.`, en `ALL RIGHTS RESERVED.`) — tuyệt đối không nhúng tên công ty vào chuỗi i18n.
- **Branding theo CÔNG TY, không theo organization**: organization API không có logo; Hilo có nhiều chi nhánh (trụ sở HN, Hải Phòng, 2× HCM) → phiếu lương dùng địa chỉ **trụ sở chính** của công ty (vd Hilo: Số 18 Đoàn Trần Nghiệp, Hai Bà Trưng, Hà Nội) cho MỌI nhân viên, KHÔNG theo unit/chi nhánh của từng người. Đừng làm runtime-per-organization trừ khi BE thêm org-profile endpoint (overkill cho nhu cầu hiện tại).
- Giá trị brand chuẩn (2 công ty) + mapping → `references/payroll-slip-brand-config.md`.

## Màu dynamic → Tailwind qua CSS vars (user bắt buộc, không inline style)

User thích Tailwind thay inline style kể cả khi màu dynamic brand. Pattern đã verify (payroll slip):

- Export `payrollCompanyCssVars` (object `'--slip-<name>': value` cho MỌI màu dùng trong view) từ resolver file, `as const satisfies Record<string, string>`.
- Đặt 1 lần trên root element: `style={payrollCompanyCssVars as CSSProperties}` — children kế thừa var, sub-component không cần truyền props.
- Tailwind arbitrary values: `text-[var(--slip-primary)]`, `bg-[var(--slip-panel)]`, `border-[var(--slip-period-border)]`; gradient `bg-linear-to-r from-[var(--slip-gradient-start)] to-[var(--slip-gradient-end)]` (Tailwind v4, repo đã dùng).
- Conditional color (ternary) → chuyển vào `cn(...)` với class strings, không dùng style prop.
- **CSS var đặt trong MFE là ĐÚNG**: `--slip-*` là business branding theo công ty, không phải design token hệ thống → không đưa vào `packages/tokens` (chỉ harvest brand config lên `@hilo/shared` khi ≥3 MFE cần).
- Lý do dev cũ dùng inline style: màu là runtime constants (không phải theme token) + gradient + print stability — CSS vars giải quyết được nên chuyển.
- ⚠️ Khi dịch inline style → class: KHÔNG đổi layout ngầm (vd giữ nguyên `left-8`, đừng viết thành `left-0`).

## Pitfalls

- **Logo nền đen đặc** (file từ BA thường là PNG nền đen/trắng đặc) → phải tách nền TRƯỚC khi bundle, nếu không thành khối đen vuông trên phiếu lương nền trắng. Dùng PIL HSV heuristic (pixel lum thấp + sat thấp → alpha giảm dần, feather theo khoảng cách ngưỡng) rồi composite lên nền trắng + `vision_analyze` để verify. Script đầy đủ: `references/payroll-slip-logo-hilo.md`.
- **Build package trước khi typecheck/build app**: app consume dist (`@hilo/shared`, `@hilo/icons`) → chạy `pnpm --filter @hilo/icons build && pnpm --filter @hilo/shared build` trước, rồi `pnpm --filter hr-dashboard typecheck` + build app (build app mới bắt lỗi bundling PNG).
- `read_file` có thể báo "Binary file - cannot display as text" cho file UTF-8 hợp lệ (vd `features/salary/constants/payroll-slip.ts`, `.gitlab-ci.yml`) → dùng `terminal cat` thay thế.
- Inline `python3 -c` phức tạp (multi-line/quotes) trong terminal có thể bị lifecycle guard chặn ("embedded null byte") → write_file script ra /tmp rồi `python3 /tmp/script.py`.
- **SỬA locale JSON = TEXT-LEVEL replace, KHÔNG json.load+dump**: `json.dump` reorder key + làm MẤT duplicate keys → diff 200+ dòng ngoài scope (đã vướng ở payroll branding, reviewer chặn). Cách đúng: `git checkout develop -- <file>` → Python đọc text, replace chuỗi chính xác / xóa đúng dòng (không parse JSON) → validate `python3 -m json.tool` + kiểm tra `git diff --stat` chỉ vài dòng. Mọi thay đổi key i18n sửa cả `vi` lẫn `en`.
- i18n `features.salary.payrollSlip.companyName`/`companyAddress` từng hardcode VPPOS → **đã XÓA khỏi locale** (dead code sau khi brand config là nguồn duy nhất). Key `copyright` là suffix-only (vi `MỌI QUYỀN ĐƯỢC BẢO LƯU.`, en `ALL RIGHTS RESERVED.`) — copyright ghép động `© ${năm} ${companyName}. ${t(suffix)}`.

## Verification

- `pnpm --filter @hilo/icons build && pnpm --filter @hilo/shared build` → `pnpm --filter hr-dashboard typecheck` → `pnpm exec eslint <files changed>` → `pnpm --filter hr-dashboard build` (đủ bắt mọi lỗi).
- Grep bundle app xác nhận logo mới đã vào: `grep -c "data:image/png;base64" apps/hr/dist/assets/*.js`.
- **pnpm treo deps-status check khi không TTY** (`ERR_PNPM_ABORTED_REMOVE_MODULES_DIR_NO_TTY`) → chạy `CI=true pnpm ...` hoặc gọi eslint thẳng `./node_modules/.bin/eslint` thay `pnpm exec eslint`.
- **Test brand matrix** (chạy build với env rồi grep bundle): `CI=true VITE_COMPANY_CODE=hilo pnpm --filter hr-dashboard build` → grep `CÔNG TY CỔ PHẦN DỊCH VỤ T-VAN HILO`; `VITE_COMPANY_CODE=unknown` → fallback VPPOS (grep tên VPPOS); thêm `VITE_COMPANY_NAME/ADDRESS="..."` → grep giá trị override.

Session detail (danh sách file, code resolver, script PIL, mapping env deploy): `references/payroll-slip-logo-hilo.md`.
