---
name: hilo-salary-engine
description: "Use when verifying Hilo ERP salary math (3P, tooltips)."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Hilo, ERP, salary, HR, payroll, P1, P2, P3, calculation]
    related_skills: ["hr-salary-patterns", "hr-salary-grade-patterns"]
---

# Hilo ERP Salary Engine — calculation invariants & verification

Use when checking/fixing salary-grade or payroll math in erp-admin `apps/hr` (tooltip numbers,
3P structure, table columns, percent drift). NOTE: `hr-salary-patterns` + `hr-salary-grade-patterns`
are the richer user-owned skills — if adopted (`hermes curator adopt`), merge this file's content
into them.

## Confirmed constants (HR/BA-validated — source of truth for any verify)

- BHXH NLĐ 10,5% (0.105), Đoàn phí NLĐ **0,5%** (0.005), BHXH công ty 21,5% (0.215),
  Kinh phí công đoàn công ty **2%** (0.02) — tất cả tính trên P1 (`socialInsuranceSalary`).
- Giảm trừ bản thân 15.500.000; người phụ thuộc 6.200.000/người; `dependent-1` mặc định
  `quantity: '1'` trong factory (template mới tự trừ 6,2tr — bẫy khi tái hiện case BA).
- 184 giờ chuẩn = 23 ngày; 1 ngày = 8h; cơm 50.000/ngày thực tế.
- Row IDs: `insurance-salary-1` (P1), `company-union-1` (KINH_PHI_CONG_DOAN, '2'),
  `employee-union-1` (DOAN_PHI_CONG_DOAN, '0,5'); `calculatedPercents` chỉ chứa `insurance-salary-1`.
- NV scale: P1 cố định 5.400.000 (B1–B5) / 5.682.000 (B6–B10); CV/TP/GĐ/TGĐ = 55% agreed.
- Allowance NV = 1.100.000/tháng (meal 50k × 22) — PDF scale gốc KHÔNG có phụ cấp (FE-added).

## Invariant: previewGrossSalary ≤ agreed salary (bug NV_B1, fixed 2026-08-09)

`previewGrossSalary = P1 + allowance + P2 + P3` KHÔNG được vượt lương thỏa thuận. NV bậc thấp:
P1 5.400.000 + allowance 1.100.000 = 6.500.000 > gross 6.000.000 → quỹ P2/P3 âm → P2/P3 = 0 →
preview cũ hiển thị 6.500.000 (HR báo tooltip "Thu nhập sau thuế" sai). Fix:
`Math.min(grossSalary, P1 + taxFreeAllowance + p2Total + p3Total)` ở CẢ HAI:
`applyCalculatedAmounts` (create-salary-grade-sections.ts) và `calculateSalaryGradePreview`
(salary-grade-calculation.ts — dormant, chỉ spec dùng; guard `agreedSalary > 0` cho
intern/collaborator vì agreed = 0).

## Invariant: P1 amount is source of truth, percent is display

Percent bị cắt 2dp (formatPercentAmount) → engine derive ngược từ percent string → lệch tiền
(60đ/20đ/6đ). Fix: khi `insuranceSalaryAmountInput > 0` dùng thẳng amount; percent hiển thị 4dp;
tooltip dùng raw percent string. DetailView đọc amount đã lưu — không bị drift.

## Invariant: payroll detail table column keys (payrollDetail.table)

Column key list DÙNG CHUNG giữa `PayrollPeriodDetailView.tsx` (`PAYROLL_LEAF_KEYS` +
`PAYROLL_HEADERS` widths) và `payroll-excel-export.ts`; header label =
`t('features.salary.payrollDetail.table.' + key)`. Typo key → label trùng lặp âm thầm (bug thật:
`actualWorkday` thiếu "s" render "Ngày công thực tế" 2 lần; fix → `actualWorkHours`).
Đổi tên key phải sửa ĐỦ: (1) key list cả 2 file, (2) locale vi+en, (3) `PayrollEmployeeValues`
type field (TS TS2322/TS2678 chỉ đúng chỗ), (4) value mapper case.

## Verification recipes

- **Repro tooltip params không cần DOM:** vitest spec với
  `translateWithParams = (key, options) => options ? \`${key}:${JSON.stringify(options)}\` : key`,
  assert `helperText` chứa e.g. `"previewGrossSalary":"6.000.000"`.
- **Full suite:** `node ../../node_modules/vitest/vitest.mjs run src/features/salary` (87 tests,
  13 files). ESLint + `tsc -b --force` cho app layer.
- **Locale JSON (Windows):** sửa bằng Python STRING replace (`s.replace(old, new, 1)`, ghi
  `newline=''`) — CẤM `json.dump` round-trip (CRLF→LF → diff ~260 dòng/file). Parity check:
  `check-locale-parity.py` cần `$(cygpath -w <path>)` từ MSYS bash.
- **Case số để tái kiểm:** (a) 60đ: gross 8.600.000, P1 nhập 5.400.000 → percent 62,79069767%,
  BHXH 567.000, đoàn phí 27.000; (b) BA: gross 32.000.000, P1 17.600.000 → BHXH 1.848.000,
  net 30.134.400 = P2 99% + 3 NPT; (c) HR: P1 5.310.000, 80/184h → P1 thực 2.308.696,
  net 2.814.596/người; (d) NV-B1: gross 6.000.000, P1 5.400.000, allowance 1.100.000 →
  preview 6.000.000, income-after-tax 5.406.000.

## Pitfalls

- P2/P3 tổng ≠ 100% chỉ WARNING khi save (không chặn) — data template gõ tay (99% là data lỗi,
  không phải bug code).
- Khi rebuild `@hilo/shared`/`@hilo/ui`: dist do `vite build` tạo (không phải tsc) — sau đổi shared
  phải vite build + `tsc -p tsconfig.build.json` trước khi typecheck app.
- IDE song song (antigravity) có thể sửa file giữa chừng — đọc lại file trước khi patch (đã từng
  tạo nested `<Link>` vì patch trên bản cũ).
