# Payroll slip brand config — giá trị chuẩn + mapping

Nguồn: session "per-company payroll slip branding" (issue vppos-team/erp-admin#131, MR !537 → develop).

## Brand config (apps/hr/src/features/salary/constants/payroll-company.ts)

`PAYROLL_COMPANY_BRANDS: Record<CompanyCode, PayrollCompanyBrand>`:

```ts
interface PayrollCompanyBrand {
  logoUrl: string;
  logoAlt: string;
  companyName: string;
  companyAddress: string;
  colors: {
    primary; accent; gradientStart; gradientEnd; border; light; periodBorder; periodText;
  };
}
```

### VPPOS (default)
- logo: `VpposLogoUrl`, alt `VPPOS`
- companyName: `CÔNG TY CỔ PHẦN CÔNG NGHỆ VPPOS`
- companyAddress: `BH4, Block B, Toà nhà Sky Center, Số 5B Phổ Quang, Phường Tân Sơn Hòa, TP. Hồ Chí Minh.`
- colors: primary `#FF9200`, accent `#FF9200`, gradientStart/End `#FF9200`, border `#ffd8a3`, light `#ffe3a9`, periodBorder `#d8dbe1`, periodText `#666b76`

### HILO (production)
- logo: `HiloLogoUrl`, alt `HILO`
- companyName: `CÔNG TY CỔ PHẦN DỊCH VỤ T-VAN HILO` (web chính thức hilo.com.vn)
- companyAddress: `Số 18 Đoàn Trần Nghiệp, Phường Hai Bà Trưng, Hà Nội` (trụ sở chính — pháp lý)
- colors (navy theo logo hilo): primary `#26429F`, accent `#F57014`, gradientStart `#26429F`, gradientEnd `#1E3578`, border `#C9D4F0`, light `#E8EDFB`, periodBorder `#d8dbe1`, periodText `#666b76`

## Neutral colors (chung cả 2 brand) — dùng chung HTML + PDF

`PAYROLL_SLIP_NEUTRAL_COLORS`: white `#ffffff`, ink `#30313d`, muted `#727682`, line `#e8e8ed`, panel `#f8f9fa`, blue `#4047ff`, panelBorder `#edf0f4`, divider `#e6e8eb`, titleBlue `#222a58`, amountText `#5b606b`, footerText `#a5a8b3`, addressText `#71737d`, noteText `#787c86`, rowLabelText `#666b76`, infoLabelText `#757a84`, infoValueText `#343640`, subsectionBackground `#f8fafc`, success `#16a34a`, primaryDeep `#2447aa`.

`payrollCompanyColors = { ...NEUTRAL, ...brand.colors }` — nguồn duy nhất cho HTML + PDF; PDF util KHÔNG giữ palette hardcode riêng (kể cả totalTone success/primaryDeep, subsectionBackground, info label/value — đều lấy từ đây).

## Export mức app

```ts
payrollCompanyBrand          // brand active theo VITE_COMPANY_CODE
payrollCompanyLogoUrl/Alt    // từ brand
payrollCompanyColors         // neutral spread brand.colors
payrollCompanyCssVars        // '--slip-*' cho Tailwind arbitrary values (đặt trên root section)
payrollCompanyName  = VITE_COMPANY_NAME?.trim()  || brand.companyName
payrollCompanyAddress = VITE_COMPANY_ADDRESS?.trim() || brand.companyAddress
```

Component dùng thẳng `payrollCompanyName/Address` (KHÔNG `?? t(...)` — dead code). Copyright: `© ${new Date().getFullYear()} ${companyName}. ${t('...payrollSlip.copyright')}` — key i18n `copyright` suffix-only (vi `MỌI QUYỀN ĐƯỢC BẢO LƯU.`, en `ALL RIGHTS RESERVED.`). Keys i18n `companyName`/`companyAddress` ĐÃ XÓA khỏi en+vi (legal identity không phải translation).

## Env plumbing (per-company, build-time)

- `VITE_COMPANY_CODE`: `.env.example` (default vppos) + typing `apps/hr/src/vite-env.d.ts` + `Dockerfile` ARG/ENV + `.gitlab/ci/base.gitlab-ci.yml` (main→`hilo`, develop→`vppos`, thêm `--build-arg` vào build_job) + `scripts/deploy-uat.sh` (vppos)
- `VITE_COMPANY_NAME` / `VITE_COMPANY_ADDRESS`: optional per-deploy override (ưu tiên hơn brand config); **chỉ wire qua Dockerfile ARG/ENV** — KHÔNG thêm build-arg vào CI vì CI không set giá trị (build-arg rỗng; reviewer chặn). Muốn dùng override: set biến CI/deploy trước khi build.

## Chốt quyết định (BA)

- Hilo dùng **trụ sở chính HN**, không theo chi nhánh/organizationId — vì nhiều chi nhánh mà phiếu lương branding theo công ty; địa chỉ pháp lý dùng chung toàn công ty.
- VPPOS address đổi sang `BH4, Block B, Sky Center…` (cùng tòa với chi nhánh HCM của Hilo).
- Màu HTML dùng Tailwind qua CSS vars (`--slip-*` trên root) — user yêu cầu bỏ inline style.
