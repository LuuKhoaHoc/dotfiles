---
name: erp-admin-fe-workflow
description: Use when developing or verifying erp-admin FE code.
---

# erp-admin FE Workflow

Use when developing, reviewing, or verifying erp-admin FE code (MFE employee/hr/sale/...) — especially verification gates, UI state architecture decisions, and code-review feedback about duplication.

## Verification tooling (Windows / Hermes terminal)

`pnpm` KHÔNG chạy được trong Hermes terminal trên máy này (corepack shim trỏ vào nvm4w install chết: `Cannot find module 'C:\c\nvm4w\nodejs\node_modules\corepack\dist\pnpm.js'`; `corepack pnpm` của Hermes node cũng không chạy). **Không mất thời gian sửa pnpm** — chạy thẳng binary local từ `apps/<mfe>/`:

```bash
node ../../node_modules/typescript/bin/tsc -b            # typecheck (gate thật)
node ../../node_modules/vitest/vitest.mjs run <paths>    # test (vd src/features/requests src/shared/apis)
node ../../node_modules/eslint/bin/eslint.js <files> [--fix]
node ../../node_modules/vite/bin/vite.js build
```

Pitfalls:
- **ESLint exit code bị nuốt khi pipe**: `eslint ... 2>&1 | tail -2 && echo PASS` luôn in PASS (exit code của pipeline là của `tail`). Đọc dòng summary `✖ N problems (M errors, ...)` hoặc chạy không pipe. Sau `--fix` chạy lại cho sạch.
- **Patch tool lint báo TS6053 "File not found" kiểu `/c/...`** (MSYS path) = false positive của linter tích hợp; gate thật là `tsc -b`.
- Sau khi sửa code, chạy đủ 4 gate (tsc + vitest + eslint + build) rồi mới báo "verified".

## Verification sau pull lớn (shared clone, 2026-08-08)

- **`git fetch origin` (TẤT CẢ branches) trước khi tin `git status -sb`** — origin refs bị stale, ahead/behind marker nói dối tới khi fetch. Real case: clone hiện "clean, up-to-date" nhưng thực tế **behind 62 commits** (chỉ fetch `main` trước đó nên `origin/develop` ref cũ).
- Diff local-vs-`origin/main` có thể là **artifact của checkout cũ** biến mất sau pull (vd: công ty đóng 10,5%/0,5% + code `CONG_DOAN` chung trên develop cũ — sau pull thành 21,5%/2% + `KINH_PHI_CONG_DOAN` đúng chuẩn). Pull trước, phán xét sau; đừng sửa code trên nền cũ.
- **Sau pull lớn phải rebuild dist libs TRƯỚC typecheck**: `node node_modules/vite/bin/vite.js build && node node_modules/typescript/bin/tsc -p tsconfig.build.json` trong `packages/shared` rồi `packages/ui`. `tsc -b` KHÔNG regenerate dist (dist do vite build + tsc -p tsconfig.build.json tạo) — dist stale gây hàng loạt TS2305 "no exported member" ở feature không liên quan (vd employees) làm lu mờ lỗi thật.
- Small fix đang dang dở khi cần pull: `git stash push` → `git pull --ff-only` → `git stash pop` (pop 3-way merge sạch nếu vùng code không đổi).

## FE UI state architecture (user decision 2026-08-06, worked example: requests feature #153)

- **Zustand cho feature-local transient UI state**: dialog open/close, filter panel open, selected rows. Store mỗi feature tại `features/<f>/stores/<f>-ui-store.ts`, `create<Store>()((set) => ...)` (curried form, zustand v5 — zustand đã có sẵn `^5.0.11` trong deps của apps/employee + packages/shared).
- **URL-backed list/filter state (page/pageSize/q/date/type/tab) BẮT BUỘC giữ trong URL** (AGENTS.md: URL query params là source of truth, sống qua refresh/back/deep-link) — KHÔNG nhân đôi vào store (2 nguồn sự thật = bug sync). Hook `useRequestsUrlState` là nơi tập trung.
- Consumer đọc **atomic selectors riêng lẻ** (`useStore(s => s.x)`), không pick whole state.
- Table components đọc UI state trực tiếp từ store (bỏ prop drilling), dialogs nhận props từ composition root.
- Test store: reset state trong `beforeEach` qua `useStore.setState({...})`.
- **Store sống lâu hơn page — bắt buộc reset khi unmount** (real case #153, 2026-08-06): zustand state tồn tại sau khi component unmount → dialog đang mở mà điều hướng đi rồi quay lại VẪN MỞ (regression so với `useState`). Pattern: action `resetRequestsUi()` (set toàn bộ field về default) + `useEffect(() => resetRequestsUi, [resetRequestsUi])` cleanup trong composition root; test reset action.

## Memo — khi nào thực sự ăn

- `memo()` đặt ở **component wrapper** (boundary), kèm: callbacks stable (`useCallback` + truyền thẳng hàm, không bọc `(f) => fn(f)`), props object `useMemo` (inline object đổi identity mỗi render → memo vô dụng).
- **`useUrlState().setState` KHÔNG stable** (deps `[setSearchParams, state, schema]`, `state` đổi mỗi khi URL đổi) → mọi callback bọc nó đổi theo URL change → memo KHÔNG chặn được re-render do URL state (và không nên chặn — dữ liệu đã đổi).
- Memo chặn được: re-render do **UI state chuyển động** (mở dialog/filter) vì lúc đó URL state không đổi → callbacks stable. Đây chính là lý do **zustand + memo bổ trợ nhau**: store cô lập UI state, memo ngăn propagation.

## DRY extraction discipline (user correction cùng session)

- KHÔNG tách component/file cho expression 1 dòng (user bắt bỏ `RequestEmployeeCell` = `employeeName || '-'`) — over-engineering.
- Chỉ extract khi duplication thật: cell ~50 dòng lặp ở 3 column hooks → 1 component dùng chung (`RequestTypeTimeCell`); table shell ~150 dòng giống nhau 2 table → `RequestsTableShell` + memo.

## BE contract quirks khi map FE (2026-08-06)

- **Optional date/time field BE trả `""` (empty string), KHÔNG phải null** — real case: `approvedAt: ""` / `rejectedAt: ""` trong request list response. Chain `??` KHÔNG bắt được `""` (`"" ?? x` = `""` → UI hiển thị trống). Khi map fallback ngày dùng `||` hoặc lọc empty string: `item.approvedAt || item.rejectedAt || item.cancelledAt` (+ fallback `approvals[].decidedAt` khi request-level date rỗng; kèm test cho cả 3 nhánh — worked example: `resolveReviewedDate` trong apps/hr request-management adapter).
- Body generic action request (`RequestActionRequest { actorEmployeeId, id, legacyId, legacyNote, note, requestId }`, dùng chung approve/reject/cancel — vd `me/requests/{id}/cancel`): FE chỉ gửi `{ id, requestId, note? }`, bỏ `actorEmployeeId`/`legacy*` (identity từ auth context, đúng pattern approve/reject đã có). API function cũ gửi body `{}` có thể đã lỗi thời — check contract trước khi tin.

## Concurrent IDE edits (antigravity/open-code chạy song song trên cùng worktree)

- File trên disk có thể bị **CHỦ Ý thay đổi** bởi IDE/người dùng giữa lúc agent viết và đọc lại — cảnh báo `file was modified since last read` KHÔNG có nghĩa file hỏng.
- Khi phát hiện file khác bản mình đã viết (mất column/test, nội dung đổi thiết kế): **KHÔNG vội 'restore' bản cũ** — kiểm tra với user trước. Real case 2026-08-06: `useHandledRequestsColumns.tsx` bị IDE đổi sang design giống `useApprovalInboxColumns`, agent tưởng bị ghi đè hỏng và restore lại bản cũ → user out-of-band sửa "tôi đang muốn UI nó giống useApprovalInboxColumns". Tín hiệu phụ: test vừa 'restore' fail vì UI đã đổi = UI bị đổi CHỦ Ý, không phải file hỏng.
- Output terminal có thể bị render artifact (vd `head -30`/`grep -c` hiện nội dung lẫn lộn, count 0 dù pattern có trong file) trong khi file thật vẫn nguyên — trước khi kết luận "file hỏng/corrupt", verify lại bằng `read_file` (có line number) hoặc `sed -n 'a,bp'`, và `grep -c` TỪNG pattern riêng.

## Payroll money safety — percent precision → payload (2026-08-09, "đền tiền" lesson)

- **Percent hiển thị bị cắt precision KHÔNG được làm nguồn tính tiền ngược**: UI derive percent từ amount rồi format 4dp (`62,79069767%` → `"62,7907"`) lưu vào `row.percent`; nếu payload gửi `rate = row.percent/100`, BE tính `P1 = round(gross × rate)` sẽ lệch tiền (VD gross 7.000.000 × 81,1714% = 5.681.998 thay vì 5.682.000). **Fix**: payload derive lại `rate = amount/gross` full precision (`getInsuranceSalaryItems` trong `salary-grade-template-utils.ts` — override rate của `LUONG_DONG_BHXH`; gửi kèm cả `amount` để BE dùng amount hay rate đều đúng). Test: `buildPayrollTemplateConfig` → `Math.round(7_000_000 × rate) === 5_682_000` + `rate` toBeCloseTo(amount/gross, 12).
- Mọi số tiền engine `roundCurrency = Math.round` (đồng nguyên): thuế luỹ tiến từng bậc round riêng, OT round sau khi nhân, NPT floor. Sai số chấp nhận duy nhất: P2/P3 nhiều row % lẻ → Σ(row round) lệch ±1-2đ.
- **Preview gross clamp**: `min(gross, P1 + allowance + P2 + P3)` — NV bậc thấp P1 cố định 5.400.000 + allowance 1.100.000 > gross 6.000.000 → quỹ P2/P3 âm → clamp; guard `agreedSalary > 0` (intern/collaborator). Áp cả 2 engine (`applyCalculatedAmounts` + `calculateSalaryGradePreview`).
- i18n key cột phải đúng field BE: `actualWorkday` (thiếu "s") → label "Ngày công thực tế" lặp cột 2; đổi `actualWorkHours` + thêm key vi/en `payrollDetail.table`.
- Audit đầy đủ + case số: `references/salary-calculation-precision-2026-08-09.md`.

## Shell sidebar — Accordion & UX pitfalls (2026-08-09)

- Repo có `@hilo/ui` Accordion (Radix + `animate-accordion-up/down`) — áp được vào sidebar expandable menu: `type="single" collapsible` + `value={expandedModuleId ?? ''}` / `onValueChange` (thay state thủ công + chevron rotate); NavLink/Popover có thể là children trực tiếp của `Accordion` Root (Radix không ép children là Item).
- **Pitfall**: class mặc định `[&[data-state=open]>svg]:rotate-180` quay **MỌI svg con trực tiếp** của Trigger — gồm cả icon menu (bị lật ngược). Phải sửa thành `[&[data-state=open]>svg:last-child]:rotate-180` (chỉ chevron). Sửa `packages/ui` → **rebuild dist** (`vite build` + `tsc -p tsconfig.build.json`) vì shell consume dist.
- Mobile Sheet: giảm khoảng trống giữa header và items bằng `min-h-12 py-2` cho header mobile (desktop giữ `min-h-16`); logo → `Link to={getFirstAllowedPath(user)}` (home theo roles, giống MobileBottomNav); click vùng trống sidebar → toggle collapse: `onClick` trên root div, skip khi `target.closest('a,button,[role="button"],input,[data-prevent-sidebar-toggle]')`.

## References

- `references/salary-calculation-precision-2026-08-09.md` — audit đầy đủ: từng điểm round trong 2 engine salary, case số (NV-B1, NV-B6), payload rate fix, preview gross clamp, spec pattern.
- `references/fe-ui-state-management.md` — web research (react.dev React Compiler, developerway 2025, zustand selector conditions) + rationale đầy đủ + worked example.
- `references/payroll-calculation-rules.md` — payroll math đã HR/BA confirm (rates NLĐ/NSDLĐ, ví dụ chuẩn), percent precision drift fix (option A), data-vs-code bug khi net lệch + repro recipe, hướng multi-company payslip/title runtime.
