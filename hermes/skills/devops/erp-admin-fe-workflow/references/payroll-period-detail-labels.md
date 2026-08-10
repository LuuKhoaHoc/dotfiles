# Payroll period detail — labels & i18n (bảng chi tiết kỳ lương)

Session 2026-08-10: HR yêu cầu đổi gấp content bảng chi tiết kỳ lương `PayrollPeriodDetailView` (header + sub-column, không đổi logic). Scope: text-only change.

## Component

- `apps/hr/src/features/salary/components/payroll-runs/PayrollPeriodDetailView.tsx`
- `PAYROLL_HEADERS` (grouped `{ key, children: {key,width}[] }`): `employeeContribution` (children: `socialInsurance` + `employeeUnionFee`), `companyContribution` (children: `socialInsurance` + `companyUnionFee`), `taxFreeAllowance` (8 cột phụ cấp).
- Header render: `t(\`features.salary.payrollDetail.table.${header.key}\`)` — children lookup cùng namespace `table`.
- `PAYROLL_DETAIL_VALUE_COLUMNS`: key data `employeeInsurance`/`employeeUnion`/`companyInsurance`/`companyUnion` — field từ API, không phải label.

## Thay đổi đã làm (HR-required terms, chốt 2026-08-10)

Keys trong `features.salary.payrollDetail.table` (cả `vi/hr.json` lẫn `en/hr.json`):

| Key | VI mới | EN mới |
|---|---|---|
| `employeeContribution` | Nhân viên nộp BHXH và đoàn phí công đoàn | Employee pays social insurance and union membership fee |
| `companyContribution` | Công ty nộp BHXH và kinh phí công đoàn | Company pays social insurance and union funding fee |
| `employeeUnionFee` (mới) | Đoàn phí công đoàn | Union membership fee |
| `companyUnionFee` (mới) | Kinh phí công đoàn | Union funding fee |
| `unionFee` (cũ, đã xóa) | Công đoàn | Union fee |

- Thuật ngữ chuẩn HR: **"nộp"** thay "đóng"; employee đóng **đoàn phí**, company đóng **kinh phí** công đoàn (2 khoản khác bản chất).
- **Pitfall chia sẻ key**: trước đây 2 group header dùng CHUNG children key `unionFee`; khi 2 nhóm cần text khác nhau → tách `employeeUnionFee`/`companyUnionFee` VÀ đổi `children` trong `PAYROLL_HEADERS`, grep consumer trước khi xóa key cũ.
- Đồng bộ: `features.salary.create.sections.employeeContribution/companyContribution` (salary grade builder) cùng text — đổi cả 2 block + cả 2 ngôn ngữ.
- `unionFee` còn tồn tại như DATA field (không phải label): `types/salary-fund.ts`, `utils/payroll-excel-export.ts` (`row.salary?.employeeContribution?.unionFee`) — KHÔNG đụng.

## Cách tìm & verify (đã chạy pass trên Windows)

```bash
# search_files lỗi IO trên apps/hr/src → dùng grep qua terminal
grep -rli "công đoàn\|congdoan" apps/hr/src packages/locales/src
python3 -m json.tool packages/locales/src/translations/{vi,en}/hr.json
node node_modules/prettier/bin/prettier.cjs --check <files>   # .bin shim không chạy qua node
node node_modules/eslint/bin/eslint.js apps/hr/src/.../PayrollPeriodDetailView.tsx
cd apps/hr && node ../../node_modules/typescript/bin/tsc -b    # exit 0
cd packages/locales && node ../../node_modules/vite/bin/vite.js build
```
