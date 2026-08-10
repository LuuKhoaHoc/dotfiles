# Salary calculation precision audit — 2026-08-09 (trước release v1.0.2, deadline trả lương 10/08)

Ngữ cảnh: user lo "làm việc tiền bạc mà làm tròn theo % là đền tiền" → audit toàn bộ 2 engine salary grade
trong apps/hr. Kết luận + fix kèm theo.

## 2 engine

| Engine | File | Trạng thái |
|---|---|---|
| `applyCalculatedAmounts` | `utils/create-salary-grade-sections.ts` (~L950-1065) | Engine UI chính (spec 89 tests) |
| `calculateSalaryGradePreview` | `utils/salary-grade-calculation.ts` | Dormant (chỉ spec dùng — 9 tests) — nhưng phải giữ đúng chuẩn |

## Bảng round (mọi số tiền → đồng nguyên, `roundCurrency = Math.round`)

| Hạng mục | Công thức | Round |
|---|---|---|
| P1 (lương đóng BHXH) | amount user nhập (nguồn sự thật khi không sync grade) hoặc `round(gross × rate/100)` | đồng |
| BHXH/công đoàn NLĐ + công ty | `round(P1 × rate/100)` (10,5 / 0,5 / 21,5 / 2) | đồng |
| P2 base | `round(P1 × 0.10)` | đồng |
| Từng row P2/P3 (%) | `round(base × %/100)` — mỗi row độc lập | đồng |
| Thuế luỹ tiến | **từng bậc** `round(amount_in_bracket × rate)` → cộng tổng (KHÔNG round tổng) | đồng |
| OT | `round((P1/176) × giờ)` — round SAU khi nhân (lương giờ lẻ 30.681,81… OK) | đồng |
| NPT | `floor(quantity)` | số nguyên |
| Percent hiển thị | 4 chữ số thập phân — CHỈ display; engine dùng raw percent string | không ảnh hưởng tiền |

Case chuẩn đã chốt: NV-B1 gross 6.000.000 / P1 5.400.000 → BHXH 567.000, đoàn phí 27.000,
NLĐ đóng 594.000, sau thuế 5.406.000. Case BA: gross 32.000.000 / P1 17.600.000 → net 30.134.400 (P2 99% + 3 NPT).

## LỖ HỔNG NGUY HIỂM: percent cắt precision đi vào payload rate

Chuỗi lỗi:
1. User sửa P1 amount → `updateRow` (CreateSalaryGradeView ~L428-446) derive
   `percent = formatPercentAmount(amount/gross × 100)` → **cắt 4dp** → `row.percent = "62,7907"`.
2. `getSectionItems` (salary-grade-template-utils.ts) gửi payload:
   `rate = Number(row.percent.replace(',', '.'))/100` → `0.627907` (mất 0.0000006767…).
3. Nếu BE tính `P1 = round(gross × rate)` → lệch tiền:
   - gross 8.600.000, P1 5.310.000 → percent 61,7441860465% → "61,7442" → BE 5.310.001 (**lệch 1đ**)
   - gross 7.000.000, P1 5.682.000 (NV-B6) → 81,171428571% → "81,1714" → BE 5.681.998 (**lệch 2đ**)

Fix (đã áp, spec kèm): `getInsuranceSalaryItems` trong `salary-grade-template-utils.ts` — sau
`getSectionItems(sections, socialInsuranceSalary)`, tìm item `code === 'LUONG_DONG_BHXH'`, đọc
`gross-1` amount từ `agreedSalary` section, override `rate = amountNum / grossNum` (full precision).
Payload vẫn gửi kèm `amount` — BE dùng rate hay amount đều ra đúng tiền.

Spec pattern (salary-grade-template-utils.spec.ts):
```ts
expect(insuranceItem?.rate).toBeCloseTo(5_682_000 / 7_000_000, 12);
expect(insuranceItem?.rate).not.toBe(0.811714);
expect(Math.round(7_000_000 * (insuranceItem?.rate ?? 0))).toBe(5_682_000);
expect(insuranceItem?.amount).toBe('5682000');
```

## Preview gross clamp (NV bậc thấp)

- NV: P1 cố định 5.400.000 (90% × 6M) + allowance 1.100.000 (50k × 22 ngày) = 6.500.000 > gross 6.000.000
  → quỹ P2/P3 âm → p2Base/p3Base = 0 → previewGross cũ = 6.500.000 (tooltip "Tổng thu nhập" SAI).
- Fix: `previewGrossSalary = Math.min(grossSalary, P1 + allowance + p2Total + p3Total)` + guard
  `normalizedAgreedSalary > 0` (intern/collaborator agreed = 0 → giữ nguyên, không clamp về 0).
- Áp CẢ HAI engine (applyCalculatedAmounts + calculateSalaryGradePreview — agy sửa file sau, review OK).
- B1 → preview 6.000.000, sau thuế 5.406.000; B2 (7.000.000) → min(7M, 6.5M) = 6.500.000 (P1+allowance thực — đúng).

## Sai số chấp nhận được (không fix)

- P2/P3 chia nhiều row % lẻ (VD 30/40/30): Σ(row round riêng) lệch ±1-2đ so với round(base × Σ%).
  Template mặc định 1 row 100% → 0 lệch. Không fix (tổng = Σ các khoản thật — đúng nghiệp vụ).
- Preview FE chỉ là ước lượng — tiền thật do BE tính (PayrollEmployeeValues). Nên đối chiếu BE 1-2 case chuẩn.

## i18n key pitfall (cột lặp label)

- Cột 4 bảng kỳ lương hiển thị "Ngày công thực tế" lặp cột 2: key `actualWorkday` (thiếu "s", sai nghĩa)
  → i18n `payrollDetail.table.actualWorkday` = "Ngày công thực tế".
- Fix: đổi key `actualWorkHours` ở `PAYROLL_LEAF_KEYS` + `PAYROLL_HEADERS` (PayrollPeriodDetailView)
  + `payroll-excel-export.ts` (keys + switch case) + thêm key vi/en `payrollDetail.table.actualWorkHours`
  ("Giờ công thực tế" / "Actual work hours"). Cập nhật type `PayrollEmployeeValues` thêm `actualWorkHours`.
- Lesson: key i18n phải trùng tên field BE, đừng đặt key "gần giống" — label sẽ lặp/trùng cột khác.
