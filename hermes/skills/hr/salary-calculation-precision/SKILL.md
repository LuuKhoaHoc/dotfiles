---
name: salary-calculation-precision
description: Audit salary-grade money math and payload rate precision.
triggers:
  - kiểm tra sai số/độ chính xác tính toán lương (BHXH, công đoàn, thuế, P2/P3, preview gross)
  - sửa payload template config (rate/percent) gửi BE trong HR MFE
  - làm tròn tiền lương, percent hiển thị vs tính toán
---

# Salary Calculation Precision (HR MFE)

Quy tắc đảm bảo tính toán bậc lương không lệch tiền — đã audit thực chiến 2026-08 (đợt hotfix trước trả lương 10/08). Chi tiết case số: `references/salary-calculation-audit-2026-08.md`.

## Quy tắc làm tròn (bất biến)

- Mọi số tiền round về ĐỒNG qua `roundCurrency = Math.round` — KHÔNG có hào/xu ở bất kỳ con số nào (P1, BHXH/công đoàn NLĐ+công ty, từng row P2/P3 %, thuế, OT).
- Thuế luỹ tiến (`calculateProgressivePersonalIncomeTax`): round TỪNG bậc rồi cộng tổng — chuẩn thuế (không round tổng cuối).
- Số người phụ thuộc: `Math.floor` (số nguyên).
- OT: `round(lương giờ × số giờ)` — round SAU khi nhân, không round lương giờ trước.
- Percent hiển thị (`formatPercentAmount` 4dp) CHỈ là display — engine tính từ raw percent string; kết quả amount luôn round.

## ⚠️ Lỗ hổng đền tiền đã gặp: payload rate precision

UI cắt percent 4dp (62,79069767% → `"62,7907"`) lưu vào `row.percent`. `getSectionItems` gửi `rate = percent/100` cho BE → BE tính ngược `P1 = round(gross × rate)` **LỆCH TIỀN** (VD 7.000.000 × 81,1714% = 5.681.998 thay vì 5.682.000).

**Fix chuẩn**: trong `buildPayrollTemplateConfig`, helper `getInsuranceSalaryItems` derive lại `rate = amount / gross` (full precision) cho row code `LUONG_DONG_BHXH` — BE dùng rate hay amount đều ra đúng số tiền. Luôn có spec test: `Math.round(gross × rate) === amount` + `rate` KHÔNG bằng giá trị cắt.

Nguyên tắc: **bất kỳ % nào đi vào payload đều phải derive lại từ amount nguồn sự thật** (hoặc lưu raw full precision), không bao giờ dùng percent đã format.

## Preview gross clamp

`previewGrossSalary = Math.min(gross, P1 + allowance + p2Total + p3Total)` — ngăn "Tổng thu nhập" vượt lương thỏa thuận khi P1 + phụ cấp ≥ gross (NV bậc thấp: P1 cố định 5.400.000 + allowance 1.100.000 > gross 6.000.000). Guard `agreedSalary > 0`: template đặc biệt (intern/collaborator, gross = 0) KHÔNG clamp về 0. Áp dụng CẢ 2 engine: `applyCalculatedAmounts` (UI) + `calculateSalaryGradePreview` (preview).

## Sai số nhỏ chấp nhận được

- P2/P3 nhiều row % (VD 30/40/30): mỗi row round riêng → tổng lệch ±1-2đ so với `round(base × Σpct)` — đúng nghiệp vụ (tổng = Σ các khoản thật). Template 1 row 100% = 0 lệch.
- Preview FE là ước lượng — số trả lương thật do BE tính (`PayrollEmployeeValues`); trước đợt lương đối chiếu BE với 1-2 case chuẩn.

## Pitfalls khi sửa (đã trả giá)

- **i18n JSON**: sửa bằng python **string-replace chính xác** (`open(p,'w',newline='')` giữ CRLF). CẤM `json.load`+`json.dump` round-trip — reformat cả file (261 dòng diff) vì đổi newline.
- **Không ghi đè spec tồn tại**: kiểm tra đầy đủ trước khi tạo file mới (ls KHÔNG cắt bằng `head` — danh sách dài hơn tưởng). `write_file` lên file có sẵn THAY THẾ — mất tests cũ (suite 87 → 76). Khôi phục `git checkout` + patch thêm vào cuối file cũ.
- **File bị IDE khác sửa song song** (antigravity): warning "modified since last read" → RE-READ file trước khi patch tiếp (patch mù tạo Link lồng nhau / import trùng).
- Payload cũng gửi `amount` kèm `rate` — không tự ý bỏ rate; derive lại cho khớp amount.

## Verification

```bash
cd apps/hr
node ../../node_modules/vitest/vitest.mjs run src/features/salary   # 89 tests (2026-08)
node ../../node_modules/eslint/bin/eslint.js <file>
node ../../node_modules/typescript/bin/tsc -b --force
```
