---
name: payroll-money-precision
description: "Salary money math: rounding + percent-precision trap."
---

# Payroll Money Precision (tiền bạc — sai số = đền tiền)

User rất nghiêm về sai số tiền trong salary/payroll: percent bị cắt precision đi vào payload → BE tính ngược → lệch tiền thật. Mọi thay đổi liên quan lương phải tuân thủ các rule này.

## Rounding conventions (chuẩn đã chốt)

- **Mọi số tiền round về ĐỒNG** — `roundCurrency = Math.round` (không có hào/xu): P1, BHXH/công đoàn (NLĐ + công ty), P2/P3 từng row, thuế TNCN, OT, final net.
- **Thuế luỹ tiến**: round TỪNG bậc riêng (`round(amountInBracket × rate)`) rồi cộng tổng — không round tổng.
- **OT**: `round(lương giờ × số giờ)` — round SAU khi nhân (lương giờ = P1/176 có thể lẻ).
- **Người phụ thuộc**: `Math.floor` (số nguyên).
- **Percent hiển thị 4dp** (`formatPercentAmount`) — chỉ display; engine tính từ raw percent string.

## PERCENT PRECISION TRAP (nguy hiểm nhất)

Khi user sửa P1 **amount** → `updateRow` derive percent = `formatPercentAmount(amount/gross×100)` → **"62,7907"** (cắt 4dp, mất precision 62,79069767...%). `getSectionItems` gửi `rate = percent/100` trong payload → **BE tính `round(gross × rate)` lệch tiền thật**:

- VD: gross 7.000.000, P1 5.682.000 → percent "81,1714" → BE: 7.000.000 × 0.811714 = **5.681.998** (lệch 2đ).
- Case 8.600.000/5.400.000: 62,7907% → 5.400.000,2 → may round đúng — đừng dựa vào may mắn.

**Fix chuẩn**: payload derive rate từ **amount/gross full precision** — `buildPayrollTemplateConfig` → `getInsuranceSalaryItems` (override `rate = amount/gross` cho `LUONG_DONG_BHXH`; amount vẫn gửi kèm). BE dùng rate hay amount đều ra đúng tiền. Spec test bắt buộc: assert `rate` toBeCloseTo full precision (12dp) + `round(gross × rate) === amount` (`salary-grade-template-utils.spec.ts`).

**Nguyên tắc**: amount là nguồn sự thật (UI lẫn payload); percent chỉ hiển thị.

## Preview gross clamp

`previewGrossSalary = min(gross, P1 + allowance + p2Total + p3Total)` — khi P1 + phụ cấp ≥ gross (NV bậc thấp: P1 cố định 5.400.000 + allowance ăn trưa 1.100.000 > gross 6.000.000), quỹ P2/P3 âm → không được hiển thị tổng thu nhập vượt lương thỏa thuận. Áp cả `applyCalculatedAmounts` (UI) lẫn `calculateSalaryGradePreview` (guard `agreedSalary > 0` cho intern/collaborator).

## Sai số chấp nhận được

- **P2/P3 nhiều row %** (VD 30/40/30): mỗi row `round(base × pct/100)` độc lập → Σ lệch ±vài đồng so với `round(base × Σpct/100)`. CHẤP NHẬN (tổng = Σ các khoản thật; template 1 row 100% = 0 lệch).
- **Preview FE chỉ là ước lượng** — số trả lương do BE tính (`PayrollEmployeeValues`). Nên đối chiếu round convention FE vs BE trước đợt trả lương (BE có thể round khác bước → lệch ±1đ/người).

## Verification

```bash
cd apps/hr && node ../../node_modules/vitest/vitest.mjs run src/features/salary
# 89 tests: gồm rate-precision spec + NV-B1 clamp spec
node ../../node_modules/eslint/bin/eslint.js <file> && node ../../node_modules/typescript/bin/tsc -b --force
```

## Pitfall khi làm việc song song

- `salary-grade-calculation.ts` (engine dormant) và `create-salary-grade-sections.ts` (engine UI) có thể bị IDE khác sửa song song — luôn `git diff` trước khi kết luận, đừng restore vội.
- Đừng ghi đè spec đã tồn tại: `ls *.spec.ts` đầy đủ (không `head -8`) trước khi tạo file mới.
