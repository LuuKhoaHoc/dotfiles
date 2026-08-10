# Salary precision — case numbers & verified numbers (erp-admin, 2026-08)

## Case lệch 60đ (gốc rễ: percent 2dp)

- Gross 8.600.000, P1 nhập 5.400.000 → percent thật 62,79069767…%; format 2dp "62,79" → engine cũ tính P1 = 8.600.000 × 62,79% = 5.399.940 (lệch 60đ) → tooltip BHXH/đoàn phí sai base.
- Fix: P1 = amount nguồn sự thật (khi `insuranceSalaryAmountInput > 0` dùng thẳng amount); percent hiển thị 4dp; tooltip dùng raw percent string (`findRowPercentInput`).

## Case lệch do percent 4dp đi vào payload (lỗ hổng rate)

- Gross 7.000.000, P1 5.682.000 (NV-B6) → percent thật 81,171428571…% → UI lưu "81,1714" → payload `rate = 0.811714` → BE `round(7.000.000 × 0.811714)` = **5.681.998 (lệch 2đ)**.
- Gross 8.600.000, P1 5.310.000 → "61,7442" → BE 5.310.001 (lệch 1đ).
- Case may đúng: 8.600.000 × 0.627907 = 5.400.000,2 → round 5.400.000 ✓.
- Fix đã áp: `getInsuranceSalaryItems` (salary-grade-template-utils.ts) — row `LUONG_DONG_BHXH` → `rate = amount/gross` full precision (VD 0.8117142857142857). Spec test: `toBeCloseTo(amount/gross, 12)`, `not.toBe(0.811714)`, `Math.round(gross × rate) === amount`.

## Case NV bậc thấp — preview gross vượt lương thỏa thuận

- NV-B1: gross 6.000.000, P1 cố định 5.400.000 (90%), allowance meal 1.100.000 (50.000 × 22 ngày) → P1 + allowance = 6.500.000 > gross → bonusBalance âm → P2/P3 = 0 → previewGross cũ = 6.500.000 (tooltip "Tổng thu nhập 6.500.000" — HR báo sai).
- Fix: clamp `previewGrossSalary = min(gross, P1 + allowance + P2 + P3)` (cả `applyCalculatedAmounts` lẫn `calculateSalaryGradePreview`, bản sau guard `agreedSalary > 0`).
- Sau fix B1: tooltip 6.000.000; thu nhập sau thuế = 6.000.000 − 594.000 (567.000 BHXH + 27.000 đoàn phí) = 5.406.000; final net 5.406.000.
- B3+ (gross ≥ 8.000.000): P1 + allowance < gross → không đổi.

## Case BA đối chiếu (đã tái hiện đúng)

- Gross 32.000.000, P1 17.600.000 → BHXH 1.848.000, income-after-insurance 30.152.000; net 30.134.400 = P2 99% + 3 người phụ thuộc (thuế 0). Lưu ý `dependent-1` mặc định `quantity: '1'` trong factory (template mới tự trừ 6,2M).

## Chuẩn số (xác nhận HR/BA)

- BHXH NV 10,5% (0.105), đoàn phí NV 0,5% (0.005), BHXH công ty 21,5% (0.215), KPCĐ công ty 2% (0.02) — đều trên P1 (`socialInsuranceSalary`).
- Giảm trừ bản thân 15.500.000, NPT 6.200.000/người. 22 ngày công chuẩn × 8h; cơm 50.000/ngày.
- Row IDs: `insurance-salary-1` (P1, LUONG_DONG_BHXH), `company-union-1` (KINH_PHI_CONG_DOAN, mặc định '2'), `employee-union-1` (DOAN_PHI_CONG_DOAN, '0,5'); `calculatedPercents` chỉ chứa insurance-salary-1.
- Số THẬT khi trả lương do BE tính (`PayrollEmployeeValues` — p1Actual, employeeInsurance, employeeUnion, mealSupport, withholdingTax, finalNetSalary) — FE chỉ preview/seed template.

## Audit checklist trước đợt trả lương

1. `roundCurrency` phủ mọi số tiền (grep Math.round/floor/ceil + toFixed trong 2 engine).
2. Payload `buildPayrollTemplateConfig`: rate của LUONG_DONG_BHXH = amount/gross (không phải percent-cắt/100); amount luôn gửi kèm.
3. Preview clamp cả 2 engine; guard agreedSalary > 0 (intern/collaborator).
4. Vitest `src/features/salary` (13 files, 89 tests — gồm test rate precision) + eslint + `tsc -b --force`.
5. Đối chiếu BE round (từng bậc vs tổng) với 1–2 case chuẩn.
