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

## References

- `references/fe-ui-state-management.md` — web research (react.dev React Compiler, developerway 2025, zustand selector conditions) + rationale đầy đủ + worked example.
