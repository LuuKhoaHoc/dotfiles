---
name: salary-money-precision
description: Use when salary money math is off or calc logic changes.
triggers:
  - BA/HR reports salary amounts off by a few đồng or nghìn (lệch tiền lương/BHXH/công đoàn/thuế)
  - editing salary-grade calculation engine (applyCalculatedAmounts, calculateSalaryGradePreview, buildPayrollTemplateConfig)
  - pre-payroll audit of money rounding / percent handling
  - percent precision questions (2dp/4dp drift, percent → amount)
---

# Salary Money Precision

User rule (nghiêm túc): "Làm việc liên quan đến tiền bạc mà làm tròn theo số % là đền tiền" — audit tính toán lương phải chạm tới **payload FE→BE** (rate/amount BE nhận), không chỉ màn hình. Detail + case số: `references/precision-cases.md`.

## Rounding conventions (erp-admin apps/hr salary)

- Mọi số tiền: `roundCurrency = Math.round` (đồng nguyên). Thuế luỹ tiến: **từng bậc round riêng** rồi cộng (`calculateProgressivePersonalIncomeTax`). OT: round SAU khi nhân (`P1/(22×8) × giờ`). Người phụ thuộc: `Math.floor`.
- P1 (`socialInsuranceSalary`): amount user nhập là **nguồn sự thật** (percent chỉ hiển thị). Fallback: `round(gross × rate/100)`.
- Preview gross clamp: `previewGrossSalary = min(gross, P1 + allowance + P2 + P3)` — cả 2 engine (`applyCalculatedAmounts`, `calculateSalaryGradePreview` — engine sau guard `agreedSalary > 0` vì intern/collaborator có agreed = 0). Khi P1 + phụ cấp ≥ gross (NV bậc thấp: P1 cố định 5.400.000 + allowance 1.100.000 > gross 6.000.000) quỹ P2/P3 âm → clamp về gross, không hiển thị "Tổng thu nhập" vượt lương thỏa thuận.

## ⚠️ Lỗ hổng số 1: percent cắt precision đi vào payload

- `formatPercentAmount` cắt 4dp → `row.percent = "81,1714"` (mất 81,17142857…). `getSectionItems` gửi `rate = percent/100` → **BE tính `round(gross × rate)` LỆCH TIỀN** (VD 7.000.000 × 0.811714 → 5.681.998 thay vì 5.682.000; có case may đúng, có case lệch 1–2đ).
- **Fix chuẩn**: `getInsuranceSalaryItems` (salary-grade-template-utils.ts) — với row `LUONG_DONG_BHXH`, override `rate = amount/gross` full precision ngay trong `buildPayrollTemplateConfig`. BE dùng rate hay amount đều ra đúng tiền. Spec test bắt invariant: `Math.round(gross × rate) === amount` và `rate` NOT toBe(percent-cắt/100).
- Khi audit lệch tiền: kiểm tra payload thật gửi BE (rate? amount?), KHÔNG chỉ tooltip/màn hình. Template chia nhiều row % (30/40/30) → mỗi row round riêng → Σ lệch ±1–2đ (chấp nhận; 1 row 100% = 0 lệch).

## Debug pattern cho "lệch tiền"

1. Tái hiện bằng spec test tạm (repro) với grade thật + `syncSalaryGradeDefaults` → in helperText/amounts (tooltip chứa `previewGrossSalary`, `employeeContribution`, `totalTax`).
2. So với chuẩn: BHXH 10,5%/21,5%, đoàn phí 0,5%, KPCĐ 2% (trên P1); giảm trừ 15,5M + 6,2M/NPT; 22 ngày × 8h.
3. Phân biệt: bug code (drift/round/clamp) vs data template (P2 99%, NPT count, allowance) vs BE (số thật `PayrollEmployeeValues` do BE trả — FE chỉ preview).
4. Sau fix: vitest `src/features/salary` + eslint + `tsc -b --force`; thêm spec test cho đúng case lệch.

## Pitfalls

- **Spec overwrite**: `write_file` file spec "mới" nhưng file ĐÃ TỒN TẠI ở HEAD (danh sách `ls | head` cắt) → mất test cũ. Kiểm tra `git show HEAD:<path>` trước khi tạo mới; nếu tồn tại → `git checkout --` khôi phục rồi thêm test vào cuối.
- **File bị sửa song song** (antigravity IDE): patch báo "modified since last read" → đọc lại file trước khi patch (đã từng tạo nested `<Link>` trong `<Link>` vì không đọc bản mới).
- **Locale JSON**: string-replace đúng chuỗi + `newline=''` — KHÔNG json round-trip (phá CRLF, diff 261 dòng/file).
- Spec cũ có thể fail sẵn trên HEAD (VD `pageSize: 10` vs `DEFAULT_PAGE_SIZE=100`) — xác nhận `git diff` rỗng trước khi đổ lỗi cho thay đổi của mình; sync spec nếu contract không đổi.
