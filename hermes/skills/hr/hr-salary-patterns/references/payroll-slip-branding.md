# Payroll slip per-company branding (logo, colors, company info)

Session 2026-08-05: BA request — payslip must show the deploying company's branding, not hardcoded VPPOS (prod ran for Hilo). Solution: build-time env `VITE_COMPANY_CODE` picks a brand config; everything else (logo, palette, company name/address) derives from it.

## Design (single source of truth)

`apps/hr/src/features/salary/constants/payroll-company.ts` is the ONLY branding source:

- `PayrollCompanyBrand { logoUrl, logoAlt, companyName, companyAddress, colors: PayrollSlipBrandColors }` — legal name/address are baked INTO each brand, not i18n.
- `PAYROLL_COMPANY_BRANDS: Record<CompanyCode, PayrollCompanyBrand>` — vppos (legacy values) + hilo.
- `payrollCompanyBrand` = `PAYROLL_COMPANY_BRANDS[companyCode] ?? VPPOS` — companyCode from `VITE_COMPANY_CODE` (default vppos).
- `PAYROLL_SLIP_NEUTRAL_COLORS` (ink/panel/line/...) + `payrollCompanyColors` = neutral ∪ brand colors.
- `payrollCompanyName` / `payrollCompanyAddress` = `VITE_COMPANY_NAME` / `VITE_COMPANY_ADDRESS` (trim) `|| brand.companyName / brand.companyAddress` — env only for special-deployment overrides; the brand config is the source (no i18n fallback in component).
- Copyright composed dynamically: `` `© ${new Date().getFullYear()} ${companyName}. ${t('...copyright')}` `` — i18n `copyright` value is now just the suffix ("MỌI QUYỀN ĐƯỢC BẢO LƯU." / "ALL RIGHTS RESERVED."), company name removed from it.
- Old `PAYSLIP_COLORS` (constants/payroll-slip.ts) deleted → HTML view and `PDF_COLORS` in payroll-slip-pdf-export.ts both read `payrollCompanyColors` (PDF maps neutral aliases: `text←ink`, brand `primary`/`accent`/`border`/`light`/`periodBorder`/`periodText`).

Hilo palette from logo: primary `#26429F` (navy), accent `#F57014` (orange), gradient `#26429F→#1E3578`, border `#C9D4F0`, light `#E8EDFB`. Semantic split: headers/banners/sections → `primary`; only the wallet icon → `accent`.

## Brand data (current values)

- VPPOS: name `CÔNG TY CỔ PHẦN CÔNG NGHỆ VPPOS`; address `BH4, Block B, Toà nhà Sky Center, Số 5B Phổ Quang, Phường Tân Sơn Hòa, TP. Hồ Chí Minh.` (user-corrected in session — was `A04.9, Tầng 4, Block A`).
- HILO: name `CÔNG TY CỔ PHẦN DỊCH VỤ T-VAN HILO` (hoạt động từ 2014); address `Số 18 Đoàn Trần Nghiệp, Phường Hai Bà Trưng, Hà Nội` (trụ sở chính). Both sourced from official web `hilo.com.vn/pages/lien-he` via web_search — **never guess legal company info; search the official domain** and cross-check name + HQ + branch addresses before baking into a brand.

## Env plumbing chain — EVERY new VITE_ var touches 5 places

1. `apps/hr/src/vite-env.d.ts` — `ImportMetaEnv` interface (VITE_COMPANY_CODE/NAME/ADDRESS).
2. `Dockerfile` — `ARG VITE_X` + `ENV VITE_X=$VITE_X` in builder stage.
3. `.gitlab/ci/base.gitlab-ci.yml` `build_job` — branch-based `export VITE_COMPANY_CODE="hilo"` (main) / `"vppos"` (develop) + `--build-arg VITE_X=$VITE_X` in the docker build block.
4. `scripts/deploy-uat.sh` — manual `--build-arg` per app image (only the app that reads the var strictly needs it; hr-dashboard for branding).
5. `.env.example` — **user explicitly requires this** (corrected in session: "Bổ sung vào .env.example nữa").

## Constants, not magic strings (user correction)

"cần lưu biến constants trong packages/shared chứ không check với magic string" — company-code strings live in `@hilo/shared/src/constants/common.ts`:

```ts
export const COMPANY_CODES = { VPPOS: 'vppos', HILO: 'hilo' } as const;
export type CompanyCode = (typeof COMPANY_CODES)[keyof typeof COMPANY_CODES];
```

App code compares against `COMPANY_CODES.HILO`, never the literal. Rebuild `@hilo/shared` after changing it (apps consume dist).

## Pitfalls

- **`import.meta.env` only works in app-layer source.** `@hilo/icons` / `@hilo/shared` are pre-built libs consumed via dist + Module Federation singleton — env reads in them are replaced at lib build and silently lose values. Constants may live in shared; env reads MUST live in `apps/*` source (payroll-company.ts is in apps/hr for this reason).
- **PNG assets in `@hilo/icons` lib build are inlined as base64 data URLs** (both logos appear as `data:image/png;base64,...` in `dist/index.js`, no `dist/assets/` folder). This is a feature for the PDF export: canvas `toDataURL()` would taint on remote-URL images without CORS — bundled data URLs are safe. Do NOT switch to remote logo URLs without adding `crossOrigin='anonymous'` + server CORS.
- **Logo with solid black background**: BA's `logo-hilo.png` was black-backed; on a white payslip it renders as a black block. Remove background with PIL before committing: pixel transparent when luminance < ~0.22 AND saturation < ~0.32 (feather alpha by distance to threshold) — preserves navy/orange/white brand colors. Verify visually with vision_analyze on a white composite (`bg.alpha_composite(img)`).
- **eslint --fix reformats imports** — after running `--fix`, re-read the file before patching; a patch built against the pre-fix text fails (happened with the payroll-company import collapsing to one line).
- **read_file can report normal UTF-8 source as "Binary file"** (payroll-slip.ts, .gitlab-ci.yml) — fall back to `cat` via terminal; content is fine.
- i18n JSON edits: Python `json` module only (load→modify→dump, `ensure_ascii=False`, `indent=2`); never sed. Validate with `python3 -m json.tool`.

## Verification

```bash
pnpm --filter @hilo/icons build        # after touching icons assets/exports
pnpm --filter @hilo/shared build       # after touching shared constants
pnpm --filter hr-dashboard typecheck
pnpm exec eslint <changed files>       # prettier may need --fix first
pnpm --filter hr-dashboard build       # also rebuilds @hilo/locales (i18n changed)
```

Verify bundle: `grep -c "data:image/png;base64" apps/hr/dist/assets/App-*.js` (expect 2 = both logos inlined).
