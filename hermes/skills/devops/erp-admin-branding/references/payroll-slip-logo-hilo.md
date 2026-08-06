# Payroll slip logo theo công ty — session detail (2026-08)

Task: phiếu lương (PayrollEmployeeSlipView) hardcode logo vppos; prod (hilo) cần logo hilo.
Giải pháp: `VITE_COMPANY_CODE` build-time env, chọn giữa 2 asset bundle. User corrections ghi nhận trong session:
1. magic string `'hilo'` → constants trong `@hilo/shared` (KHÔNG check inline)
2. phải bổ sung `.env.example` khi thêm VITE_ var

## Files đã sửa (11)

| File | Thay đổi |
|---|---|
| `packages/icons/src/assets/logos/hilo-logo.png` | MỚI (copy từ `Projects/Hilo-Vppos/Documents/ERP/logo-hilo.png`, đã tách nền đen bằng PIL) |
| `packages/icons/src/custom.ts` | `export { default as HiloLogoUrl } from './assets/logos/hilo-logo.png';` |
| `packages/icons/src/types.d.ts` | `export declare const HiloLogoUrl: string;` |
| `packages/shared/src/constants/common.ts` | `COMPANY_CODES` + `CompanyCode` type |
| `apps/hr/src/features/salary/constants/payroll-company.ts` | MỚI: resolver logo + alt |
| `apps/hr/src/vite-env.d.ts` | `ImportMetaEnv { readonly VITE_COMPANY_CODE?: string }` |
| `apps/hr/.../PayrollEmployeeSlipView.tsx` | `<img src={payrollCompanyLogoUrl} alt={payrollCompanyLogoAlt}>` |
| `apps/hr/.../payroll-slip-pdf-export.ts` | `loadImage(payrollCompanyLogoUrl)` |
| `Dockerfile` | `ARG VITE_COMPANY_CODE` + `ENV` |
| `.gitlab/ci/base.gitlab-ci.yml` | main→`export VITE_COMPANY_CODE="hilo"`, develop→`"vppos"`, + `--build-arg VITE_COMPANY_CODE=$VITE_COMPANY_CODE` |
| `scripts/deploy-uat.sh` | `--build-arg VITE_COMPANY_CODE="vppos"` (shell + hr-dashboard) |
| `.env.example` | section "Company Code (branding)" — `VITE_COMPANY_CODE=vppos` |

## Code mẫu

Resolver (`apps/hr/src/features/salary/constants/payroll-company.ts`):
```ts
import { HiloLogoUrl, VpposLogoUrl } from '@hilo/icons';
import { COMPANY_CODES } from '@hilo/shared';

const companyCode = import.meta.env.VITE_COMPANY_CODE?.toLowerCase() ?? COMPANY_CODES.VPPOS;

export const payrollCompanyLogoUrl =
  companyCode === COMPANY_CODES.HILO ? HiloLogoUrl : VpposLogoUrl;

export const payrollCompanyLogoAlt =
  companyCode === COMPANY_CODES.HILO ? 'HILO' : 'VPPOS';
```

Constants (`packages/shared/src/constants/common.ts`, cạnh `getCompanyEmailDomains`):
```ts
export const COMPANY_CODES = {
  VPPOS: 'vppos',
  HILO: 'hilo',
} as const;

export type CompanyCode = (typeof COMPANY_CODES)[keyof typeof COMPANY_CODES];
```

## Env mapping deploy

- **main (prod, CI)**: `erp.hilo.com.vn` → `VITE_COMPANY_CODE=hilo`
- **develop (UAT, CI)**: `erp.vppos.vn` → `VITE_COMPANY_CODE=vppos`
- **deploy-uat.sh (manual)**: vppos
- Default trong code (env thiếu): `COMPANY_CODES.VPPOS`

## Script tách nền đen (PIL, đã chạy OK)

```python
from PIL import Image

img = Image.open(SRC).convert("RGBA")
pixels = img.load()
for y in range(h):
    for x in range(w):
        r, g, b, a = pixels[x, y]
        if a == 0: continue
        mx, mn = max(r, g, b), min(r, g, b)
        sat = 0 if mx == 0 else (mx - mn) / mx
        lum = (r + g + b) / 3 / 255
        if lum < 0.22 and sat < 0.32:  # feather theo khoảng cách ngưỡng
            t = min((0.22 - lum) / 0.22, (0.32 - sat) / 0.32)
            pixels[x, y] = (r, g, b, max(0, int(255 * (1 - t))))
img.save(DST)
```

Ngưỡng `lum<0.22 & sat<0.32` giữ được chữ navy (sat cao) + cam + GROUP xám; chỉ xóa nền đen.
Verify: composite lên nền trắng (`bg.alpha_composite(img)`) + `vision_analyze` → nền sạch, chữ nguyên vẹn.

## Verification outputs (session thật)

- `pnpm --filter @hilo/icons build` ✓ (dist/index.js 559 kB, "Copied src/types.d.ts → dist/index.d.ts")
- `pnpm --filter @hilo/shared build` ✓
- `pnpm --filter hr-dashboard typecheck` ✓ (`tsc --noEmit` sạch)
- `pnpm exec eslint <5 files>` → "No issues found" exit 0
- `pnpm --filter hr-dashboard build` ✓ 9.68s (chunk-size warning pre-existing)
- Grep: `grep -c "data:image/png;base64" apps/hr/dist/assets/App-*.js` → 2 (cả 2 logo inline base64, không file asset riêng)
- `grep HiloLogoUrl packages/icons/dist/index.d.ts` → `export declare const HiloLogoUrl: string;`

## Ghi chú khác

- `apps/hr/src/vite-env.d.ts` ban đầu chỉ có `/// <reference types="vite/client" />` — thêm interface `ImportMetaEnv` merge được với vite/client.
- Shell (`apps/shell/src/vite-env.d.ts`) có sẵn pattern `readonly VITE_COMPANY_EMAIL_DOMAINS?: string` — làm theo.
- Còn tồn đọng (issue tiềm năng): `companyName`/`companyAddress` i18n hardcode VPPOS trong `packages/locales/src/translations/{vi,en}/hr.json` (`features.salary.payrollSlip.*`) — nếu làm env-driven, nhớ sửa cả 2 ngôn ngữ + thêm vào checklist VITE_ var.
