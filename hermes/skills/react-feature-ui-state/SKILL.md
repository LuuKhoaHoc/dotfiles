---
name: react-feature-ui-state
description: "React tabs/filters: zustand UI store, memo, filter config."
---

# React Feature UI State Patterns

Class-level patterns for list/tab/dialog features (validated on erp-admin Employee requests feature, #153). User-adopted convention: **zustand store for feature-local UI state** ("khởi nguyên" 2026-08-06).

## 1. State split — URL vs store vs local

| Kind | Owner | Notes |
|---|---|---|
| page/pageSize/q/filters/status tab | **URL** (`useUrlState` + schema) | Deep-link/back/refresh phải sống; NEVER mirror vào store (2 nguồn sự thật → bug sync) |
| Dialog open/close, filter panel open | **zustand store** (feature-local `stores/*-ui-store.ts`) | State dùng chung nhiều component, không nên ở URL |
| State 1 component dùng | `useState` | Không drill |

## 2. Zustand store rules (nếu dùng)

- **BẮT BUỘC reset khi unmount**: store sống lâu hơn page → dialog đang mở sẽ tự mở lại khi quay lại trang (regression thật từ useState → store). Pattern: action `resetXxxUi()` + `useEffect(() => resetXxxUi, [resetXxxUi])` trong page component. Test reset trong store test.
- Selector **atomic** (1 field/action mỗi `useStore(state => ...)` call); actions stable → an toàn trong deps useCallback. `useShallow` cho nhóm values.
- Zustand KHÔNG chặn re-render do parent gây ra — cái chặn được là `memo`/React Compiler, không phải store.

## 3. memo — khi nào thực sự có tác dụng

- `memo(Component)` + **props stable**: callbacks qua `useCallback` (pass thẳng setter: `onApplyFilters={setFilters}`, KHÔNG inline arrow `(x) => setFilters(x)`), object props qua `useMemo` (vd `filterValues`), data từ React Query cache (đã stable).
- Nếu URL-state hook trả setter không stable (deps chứa `state`), callbacks URL-bound đổi identity theo URL — chấp nhận được: URL đổi thì table phải render lại.
- Win thật: **UI state chuyển động** (dialog/filter toggle) không kéo memoized tables render lại. Memo ở wrapper tables (boundary) chứ không chỉ ở component con.

## 4. Filter panel đồng bộ nhiều tabs

- Builder dùng chung: `getRequestsFilterCategories(t)` / `getRequestsFilterSections(t)` + options constants (value + labelKey) trong 1 file — mọi tab dùng chung, không code lặp sections/categories per-tab.
- Panel dạng modal (ResponsiveModal — không anchor trigger) → trigger đặt được ở header; `filterOpen` phải ở component render cả trigger lẫn panel; reset khi đổi tab.

## 5. Thêm tab mới mirror tab có sẵn

1. URL state per-tab: schema keys `xxxPage/xxxPageSize/xxxQ/xxxFromDate/xxxToDate/xxxType` + `xxxParams` memo + setter nhánh per-tab. Đừng quên `initUrlStateDefaults` + setter filter reset page về 1.
2. Query hook `enabled: isXxxTab` + query keys riêng; mutation liên quan invalidate thêm key tab mới.
3. Tab config constants (enum values 1 chỗ; `z.enum(readonly array)` OK; type định nghĩa ở constants, không export từ hooks).
4. Table component + content switch trong Overview.

## Pitfalls

- **BE trả `""` cho date field**: `??` KHÔNG bắt empty string (`"" ?? x` = `""`) → dùng `||` chain (`approvedAt || rejectedAt || cancelledAt`) + fallback field con (`approvals[].decidedAt`) + `updatedAt`. Test fixture mô hình đúng case `rejectedAt: ''`.
- **KISS — ngưỡng tách component** (user correction "tại sao phải tạo component"): chỉ tách khi duplication vài chục dòng logic thật (cell ~50 dòng x3 bản → component chung); KHÔNG tách expression 1 dòng (`employeeName || '-'`) dù lặp 2 chỗ.
- **Check API layer + i18n keys TRƯỚC khi build UI**: endpoint/API fn/keys có thể ĐÃ tồn tại (grep trước — case cancel flow: chỉ thiếu mutation hook + action menu + dialog). Gửi body theo pattern hiện có (`{id, requestId, note?}`), không gửi actor/identity field (lấy từ auth context).
- **useMutation với hàm có param phụ**: bọc `mutationFn: ({ id, note }) => fn(id, note)` — truyền thẳng hàm 2 tham số đụng `MutationFunctionContext` (TS error).
- **File bị IDE/user sửa song song**: diff lạ so với bản mình viết có thể là THAY ĐỔI CHỦ Ý của user (case #153: user đổi columns layout; agent tưởng bị ghi đè → restore nhầm). Đọc kỹ (read_file/sed — head/grep có thể render artifact), đoán ý đồ, HỎI user trước khi khôi phục.

## Verification

- Chạy LẠI tests SAU `eslint --fix` (prettier reformat đổi file sau khi tests pass).
- Khi pnpm shim hỏng (Windows corepack chết): chạy trực tiếp `node node_modules/<bin>` (tsc -b, vitest.mjs run, eslint, vite build) từ cwd `apps/<app>`; commit/push `--no-verify` sau khi tự chạy đủ gates.
