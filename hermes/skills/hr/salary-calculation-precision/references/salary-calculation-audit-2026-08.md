# Salary calculation audit — 2026-08 (case numbers)

Audit thực chiến đợt hotfix trước trả lương 10/08. Các case số đã verify bằng vitest.

## Case số chuẩn (đã xác nhận HR/BA)

| Case | Giá trị | Kỳ vọng |
|---|---|---|
| NV-B1 | gross 6.000.000, P1 5.400.000 (90%), allowance 1.100.000 | previewGross clamp 6.000.000; thu nhập sau thuế 5.406.000 (6.000.000 − 594.000 − 0) |
| NV-B1 BHXH | P1 5.400.000 | BHXH NLĐ 567.000 (10,5%), đoàn phí 27.000 (0,5%), tổng NLĐ đóng 594.000 |
| Rate precision | gross 7.000.000, P1 5.682.000 → 81,171428571% | UI lưu "81,1714" → payload rate phải = 5.682.000/7.000.000 (full), không phải 0,811714 |
| BA case | gross 32.000.000, P1 17.600.000, P2 99%, 3 NPT | BHXH 1.848.000; income-after-insurance 30.152.000; net 30.134.400 |
| HR case | P1 5.310.000, 184h chuẩn = 23 ngày, 11 ngày làm, cơm 50.000/ngày × 3 NV | net 2.814.596/người (BE tính — FE chỉ render) |

## Lỗ hổng đã fix

1. **Percent drift 2dp** (fix #161): user nhập P1 amount → updateRow derive percent `formatPercentAmount` → cắt 2dp ("62,79") → engine tính ngược lệch 60đ (8.600.000 × (62,79069767% − 62,79%)). Fix: P1 = amount là nguồn sự thật; percent 4dp hiển thị; tooltip dùng raw percent string (`findRowPercentInput`).
2. **Payload rate cắt 4dp** (fix #162): percent "81,1714" → `rate = 0.811714` → BE round(gross × rate) lệch. Fix: `getInsuranceSalaryItems` derive `rate = amount/gross` full precision.
3. **Preview gross vượt lương thỏa thuận**: NV-B1: P1 + allowance = 6.500.000 > gross 6.000.000 → tooltip "Tổng thu nhập 6.500.000" sai. Fix: clamp `Math.min(gross, ...)` ở cả `applyCalculatedAmounts` và `calculateSalaryGradePreview` (guard `agreedSalary > 0`).
4. **UNION_EMP default sai**: default template lưu 1% (phải 0,5%); `SALARY_GRADE_CONFIG` company rates stale 10,5%/0,5% (phải 21,5%/2%). Sync cả default template + config.

## Rounding audit kết quả

- Tất cả số tiền nguyên (đồng): roundCurrency = Math.round ở mọi thành phần.
- Thuế: round từng bậc → tổng (không round tổng).
- P2/P3: round từng row % — tổng lệch ±1-2đ khi chia nhiều row % lẻ (chấp nhận).
- Số NPT: floor.
- OT: round sau khi nhân giờ × lương giờ (lương giờ = P1/176 có thể lẻ).

## Nguồn file

- `apps/hr/src/features/salary/utils/create-salary-grade-sections.ts` — applyCalculatedAmounts (UI engine)
- `apps/hr/src/features/salary/utils/salary-grade-calculation.ts` — calculateSalaryGradePreview (dormant) + roundCurrency + tax
- `apps/hr/src/features/salary/utils/salary-grade-template-utils.ts` — buildPayrollTemplateConfig + getSectionItems + getInsuranceSalaryItems (rate precision)
- Specs: create-salary-grade-sections.spec.ts (19 tests), salary-grade-template-utils.spec.ts (15 tests), salary-grade-calculation.spec.ts (9 tests)
