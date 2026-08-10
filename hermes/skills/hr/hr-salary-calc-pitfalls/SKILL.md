---
name: hr-salary-calc-pitfalls
description: "HR salary calc pitfalls: preview gross clamp, columns, i18n."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [HR, Salary, erp-admin, Pitfalls]
    related_skills: ["hr-salary-patterns", "hr-salary-grade-patterns"]
---

# HR Salary Calculation Pitfalls (erp-admin apps/hr)

Bổ sung cho `hr-salary-patterns` (user-owned). Các pitfall phát hiện khi fix đợt lương 08/2026 — đọc TRƯỚC khi sửa logic tính lương.

## previewGrossSalary phải clamp ≤ lương thỏa thuận

`previewGrossSalary = P1 + phụ cấp + P2 + P3` — khi P1 + phụ cấp ≥ gross (NV bậc thấp: P1 cố định 5.400.000 + phụ cấp ăn trưa 1.100.000 > gross 6.000.000 của NV-B1), quỹ P2/P3 âm → không clamp thì tooltip "Tổng thu nhập" hiển thị 6.500.000 (sai) và thuế preview tính trên base sai.

```ts
const previewGrossSalary = Math.min(grossSalary, socialInsuranceSalary + taxFreeAllowance + p2Total + p3Total);
```

Áp ở CẢ 2 engine (phải đồng bộ):
- `applyCalculatedAmounts` — `utils/create-salary-grade-sections.ts`
- `calculateSalaryGradePreview` — `utils/salary-grade-calculation.ts` (thêm guard `agreedSalary > 0` — intern/collaborator agreedSalary = 0 không được clamp về 0)

Test case chuẩn (grade NV-B1: gross 6.000.000, P1 5.400.000, allowance 1.100.000): previewGross "6.000.000", thu nhập sau thuế = 6.000.000 − 594.000 (BHXH 567.000 + đoàn phí 27.000) = **5.406.000**. Allowance NV 1.100.000 = 50.000 × 22 ngày — nếu P1+allowance > gross thì là vấn đề DATA scale, báo BA chốt, không tự sửa scale.

## Tái hiện số trong tooltip (repro pattern)

Không cần render UI: viết test tạm `__repro-*.test.ts` với translate mock nhận options:

```ts
const translate = (key: string, options?: Record<string, unknown>) =>
  options ? `${key}:${JSON.stringify(options)}` : key;
```

In `helperText` của row → chứa params thật (`previewGrossSalary`, `employeeContribution`, `totalTax`...). Xóa file repro sau khi xong. Lưu ý: salaryGrade object phải đủ `allowanceBreakdown` (8 keys — housing/transportation/phone/meal/parking/internetDevice/uniform/otherPolicy) nếu không TS error `SalaryGradeScaleItem`.

## Cột attendance trong bảng kỳ lương (PayrollPeriodDetailView)

Cột "Giờ công thực tế" dùng key `actualWorkHours` (kind `hour`) — key `actualWorkday` (thiếu "s") trỏ i18n "Ngày công thực tế" → **cột lặp label** với cột ngày công. Khi label cột bị lặp: tìm key path i18n của từng cột trước (python find value → path) rồi sửa key, không sửa label.

Đổi key cột phải đồng bộ 4 chỗ: `PAYROLL_LEAF_KEYS` (kind) + `PAYROLL_HEADERS` (width) trong view; `PAYROLL_*_KEYS` + switch case trong `utils/payroll-excel-export.ts`; i18n `features.salary.payrollDetail.table.<key>` (vi + en); type `PayrollEmployeeValues` trong `types/salary-fund.ts` nếu thiếu field.

## Locale JSON — cấm json round-trip

File locale CRLF — `json.load` + `json.dump` đổi newline → diff nhiễu hàng trăm dòng/file. Sửa key bằng string replace trực tiếp:

```python
s = open(p, encoding='utf-8').read()
assert old in s
open(p, 'w', encoding='utf-8', newline='').write(s.replace(old, new, 1))
```

Verify `python3 -m json.tool` cả 2 ngôn ngữ. Dùng `scripts/check-locale-parity.py` (trong skill hr-salary-grade-patterns — chạy qua `cygpath -w` trên Windows).
