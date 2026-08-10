# Payroll calculation rules — confirmed by HR/BA (2026-08-08)

Khi cần verify "hệ thống tính lương có đúng như ví dụ HR/BA không": **payroll run math nằm ở BE** (FE chỉ render `PayrollEmployeeValues` trong `types/salary-fund.ts` — p1Actual, employeeInsurance, employeeUnion, mealSupport, withholdingTax, finalNetSalary... đều do BE trả). FE salary-grade builder chỉ tạo template config (rates) + preview full-month. Muốn verify con số thật → check saved template `configJson` + kết quả run qua BE API, không chứng minh được bằng code FE.

## Ví dụ chuẩn (BA + HR confirm, 3 NV dieud/hoaitt/phuongnh, số liệu giống nhau)

Input: P1 gốc (lương đóng BHXH) = 5.310.000; 1 ngày = 8h; 184h chuẩn = 23 ngày; phụ cấp cơm 50.000/ngày thực tế; 11 ngày làm (80h); gross 7.000.000; P2 mục tiêu = 10% × P1; không OT/phúc lợi/người phụ thuộc.

1. Tỷ lệ công = 80/184 = 43,48% → P1 thực tế = 5.310.000 × 80/184 = **2.308.696**
2. Phụ cấp cơm: gốc 23 × 50.000 = 1.150.000; thực tế **11 × 50.000 = 550.000**
3. Quỹ P2/P3 = 7.000.000 − 5.310.000 − 1.150.000 = 540.000; P2 = 531.000; P3 = 9.000
4. Gross thực tế = 2.308.696 + 550.000 + 531.000 + 9.000 = **3.398.696**
5. **BHXH/đoàn phí KHÔNG prorate — tính trên P1 GỐC đầy đủ**: BHXH = 5.310.000 × 10,5% = 557.550; đoàn phí = 5.310.000 × 0,5% = 26.550
6. Thuế: (3.398.696 − 550.000 − 557.550 − 15.500.000) < 0 → TNCN = 0
7. Thực nhận = 3.398.696 − 557.550 − 26.550 = **2.814.596**

## Rates chính thức (nguồn sự thật)

| Khoản | NLĐ đóng | NSDLĐ đóng |
|---|---|---|
| BHXH | 10,5% (8 + 1,5 + 1) | 21,5% (17,5 + 3 + 1) |
| Đoàn phí / Kinh phí công đoàn | **0,5%** | **2%** |

Base = P1 (lương đóng BHXH), dùng P1 gốc đầy đủ (không theo tỷ lệ công). Lưu ý: employee-side tên "Đoàn phí công đoàn" (code DOAN_PHI_CONG_DOAN), company-side "Kinh phí công đoàn" (code KINH_PHI_CONG_DOAN) — 2 code riêng biệt.

## 3 nguồn rate FE phải khớp nhau (trap đã gặp)

1. Builder row defaults trong `createInitialSections` (10,5 / 0,5 / 21,5 / 2)
2. `constants/default-payroll-template.ts` — UNION_EMP rate 0.005, UNION_COMP 0.02, BHXH split 8/1.5/1 + 17.5/3/1 (từng bị UNION_EMP = 0.01 = 1% — SAI)
3. `SALARY_GRADE_CONFIG` trong `salary-grade-calculation.ts` (0.105/0.005/0.215/0.02 — từng bị company 0.105/0.005 stale)

Khi HR báo "tính sai BHXH/công đoàn": check cả 3 nguồn + **saved template configJson** (template đã lưu có thể mang rate cũ — real case union 0% trong template lưu). `calculateSalaryGradePreview` (config-driven) dormant — chỉ spec callers.

## Lệch tiền class "percent precision drift" (đã fix 2026-08-08)

Triệu chứng: input P1 = 5.400.000, tooltip BHXH base 5.399.940 (60đ), net lệch 6đ (567.000 − 566.994), BHXH tooltip lệch ~20đ với base lẻ khác. Cơ chế: percent field bị cap 2dp (62,79069767% → "62,79") → engine derive ngược P1 từ percent string → lệch `gross × phần lẻ bị mất`. Fix hiện tại (option A): `socialInsuranceSalary` ưu tiên **amount user nhập** (trừ khi `syncSalaryGradeDefaults` — dùng grade rate), `formatPercentAmount` = 4dp, helperText dùng raw percent string. Chi tiết: skill `hr-salary-patterns` / `hr-salary-grade-patterns` (user-owned — đọc được, cần `hermes curator adopt` để sửa).

## Data-vs-code bug: net lệch do template lưu SAI (2026-08-08)

Case BA: gross 32.000.000, P1 17.600.000 → BHXH = 1.848.000 (đúng 10,5%), đoàn phí 0%, net hệ thống 30.134.400 vs kỳ vọng 30.152.000 (= gross − BHXH). Tái hiện chính xác 30.134.400 với **P2 (competency) = 99%** (previewGross thiếu 17.600 = p2Base 1.760.000 × 1%) + **3 người phụ thuộc** (giảm trừ 34,1M → thuế 0). Với P2 100% + 3 dependent → 30.152.000 đúng kỳ vọng.

Kết luận: **không phải bug code** — P2 99% được GÕ TAY: không code path nào derive percent P2 (git history: default luôn 100 từ commit đầu; `updateRow` chỉ có branch insurance; `getInvalidPercentTotalSections` chỉ WARNING tổng ≠ 100, không chặn save). Hydration copy nguyên trạng configJson → template "dính" giá trị sai mãi. Xử lý: BA/HR mở template sửa data (P2 → 100%, kiểm tra dependent), hoặc thêm guard chặn save khi tổng P2/P3 ≠ 100 (chờ BA chốt có cho phép % lẻ không).

Lưu ý khi so kỳ vọng: BA hay tính `gross − BHXH` bỏ qua TNCN (thuế ≠ 0 khi thu nhập sau giảm trừ 15,5M dương — vd 32M − 1.848.000 − 15.500.000 = 14.652.000 → thuế 5% = 732.600) và bỏ qua đoàn phí. `dependent-1` default quantity = 1 (6,2M) trong `createInitialSections` — mọi template official mới đều tự trừ 1 người phụ thuộc; flag nếu BA giả định "không có người phụ thuộc".

## Reproduction recipe (verify số lệch BA báo)

1. Viết throwaway `apps/hr/src/features/salary/utils/__repro-<case>.test.ts`: `createInitialSections(translate)` → map sections set gross-1, insurance-salary-1 (amount + percent), employee-union-1 percent, competency-1 percent, dependent-1 quantity → `applyCalculatedAmounts(sections, undefined, translate)` → `console.log(JSON.stringify(calculated.map(s => ({id: s.id, rows: s.rows.map(r => ({id: r.id, amount: r.amount, percent: r.percent}))})), null, 1))`.
2. Chạy `node ../../node_modules/vitest/vitest.mjs run <file>` (từ apps/hr), đọc dump, thử các candidate config cho tới khi khớp số BA.
3. **XÓA file repro sau khi xong** (đừng để lọt vào MR — dùng xong rm ngay).

## Multi-company payslip + title bảng lương (BA 2026-08-08 — hướng runtime)

- Title kỳ lương hardcode "Hệ thống HILO" trong i18n `vi/hr.json` (`"Quản lý kỳ lương - {{period}} - Hệ thống HILO"`) → sai khi xem dữ liệu công ty khác (VPPOS); filename Excel export thừa hưởng luôn.
- Payslip brand chọn build-time `VITE_COMPANY_CODE` (prod = hilo) → mọi công ty thành viên ra phiếu Hilo — sai với multi-tenant prod.
- Chưa có nguồn công ty runtime: auth `User` không có companyCode; `PayrollPeriod`/`PayrollRun` không có company field; không có endpoint company/tenant trong `API_ENDPOINTS`; tên công ty ở header shell không nằm trong FE code (BE trả).
- Hướng đã thống nhất với user: **BE thêm `companyCode`/`companyName` vào payroll period + employee response** → FE chọn `PAYROLL_COMPANY_BRANDS[companyCode] ?? vppos` runtime (bỏ phụ thuộc build-time env cho branding); title dùng companyName của period (fallback env/brand). Mở rộng `PAYROLL_COMPANY_BRANDS` theo từng công ty thành viên (logo + thông tin pháp lý từ web chính thức — không đoán). Giữ logo dạng data-URL inline (canvas PDF không bị CORS taint).
