# FE UI state management — research & worked example (erp-admin requests feature, issue #153, 2026-08-06)

## User decision

- Dùng **zustand** cho feature-local **transient UI state** (dialog open/close, filter panel open, selected rows) — "khởi nguyên cho việc dùng zustand global state quản lý UI state trong dự án".
- URL-backed list/filter state giữ trong URL (AGENTS.md convention).
- Kết hợp `memo` cho table components.

## Web research (2026-08-06) — React 19 best practice: props vs zustand

- **react.dev/learn/managing-state + sharing-state-between-components**: cách chính thức là lift state + props; context/library chỉ khi shared state phức tạp.
- **react.dev/learn/react-compiler/introduction** (React 19): compiler tự động memoize — "app only re-renders when necessary, fine-grained reactivity". Hướng chính thức giảm re-render là compiler/memo, không phải state library.
- **developerway.com/posts/react-state-management-2025** (TL;DR): local → useState; remote → React Query; shared → Context; shared phức tạp → external library (zustand). Cũng lưu ý: "đang tự build context-optimization thì cứ dùng zustand".
- **Zustand docs / tkdodo "Working with Zustand"**: re-render win chỉ khi atomic selectors + nhiều consumer + state đổi thường xuyên; pick whole state = re-render y hệt. Điểm kỹ thuật: `useStore` KHÔNG chặn parent-driven re-render — cái chặn được là memo/React Compiler.

## Vì sao zustand + memo bổ trợ nhau (insight từ implementation)

- `useUrlState().setState` (packages/shared/src/hooks/useUrlState.ts) KHÔNG stable: `useCallback` deps `[setSearchParams, state, schema]`; `state` (full parsed URL object) đổi mỗi khi URL params đổi → mọi setter bọc nó (setPage/setFilters/setStatus...) đổi identity theo URL change.
- Hệ quả: memo KHÔNG chặn được re-render do URL state (callbacks mới mỗi URL change) — và không nên chặn (dữ liệu đã đổi, table phải render).
- Memo chặn được: re-render do UI state chuyển động (mở dialog/filter panel) — lúc đó URL state không đổi → callbacks stable → memoized tables skip.
- Vậy: **store cô lập UI state (chỉ component subscribe mới re-render) + memo ngăn propagation từ composition root** = đúng combo.

## Pattern triển khai (requests feature)

- Store: `apps/employee/src/features/requests/stores/requests-ui-store.ts` — `create<RequestsUiStore>()((set) => ...)` (curried form, zustand v5 TS).
  - Actions ổn định (định nghĩa 1 lần) → selectors atomic: `useStore((s) => s.x)` mỗi slice riêng.
  - Test: `useRequestsUiStore.setState({...full reset...})` trong `beforeEach`.
- Composition root (RequestsOverview) giữ: URL state (`useRequestsUrlState`) + queries (React Query) + dialogs nhận props từ store. Bỏ hết `useState` cục bộ.
- Tables (`RequestsTable`, `ApprovalInboxTable`, `HandledRequestsTable`, `RequestsTableShell`) đọc `filterOpen`/`setFilterOpen` trực tiếp từ store — bỏ prop drilling 2 cấp.
- Memo: `function XComponent(...) {}` + `export const X = memo(XComponent)`.
- Stable props cho memoized tables:
  - Callbacks: `useCallback` + truyền thẳng (`onApplyFilters={setFilters}` — không bọc arrow).
  - Props object: `const filterValues = useMemo(() => ({ q, fromDate, toDate, type }), [...])`.
  - React Query data refs stable ✓; columns array tạo mới trong wrapper — chấp nhận (wrapper re-render là khi cần).
- Tab change reset: `closeFilter()` từ store trong tab handler (cùng chỗ với `setStatus`).

## DRY discipline (user correction cùng session)

- Bị user bắt xóa `RequestEmployeeCell` (1 file cho `employeeName || '-'`) — "Tạo sao phải tạo component RequestEmployeeCell á". Expression 1 dòng lặp 2 chỗ → để inline.
- Giữ lại `RequestTypeTimeCell` (~50 dòng lặp 3 column hooks) + `RequestsTableShell` (~150 dòng lặp 2 table) — duplication thật mới extract.

## Verification commands (Hermes terminal, Windows)

- `pnpm` broken: `Cannot find module 'C:\c\nvm4w\nodejs\node_modules\corepack\dist\pnpm.js'` (corepack shim → nvm4w chết); `corepack pnpm` của Hermes node cũng fail (chỉ in "Node.js v22.23.2").
- Workaround từ `apps/employee/`:
  - `node ../../node_modules/typescript/bin/tsc -b` (tsc -b — package.json typecheck script)
  - `node ../../node_modules/vitest/vitest.mjs run <paths>` (vitest v4)
  - `node ../../node_modules/eslint/bin/eslint.js <files> [--fix]`
  - `node ../../node_modules/vite/bin/vite.js build`
- ESLint pipe trap: `eslint ... | tail && echo PASS` luôn PASS — đọc summary `✖ N problems` hoặc chạy không pipe.
- Patch tool lint TS6053 `/c/...` false positive — ignore, gate thật là tsc -b.
- Chunk-size warning của vite build là bình thường (pre-existing).
