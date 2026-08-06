---
name: erp-admin-mfe-implementation
description: Use when implementing erp-admin issues in a worktree.
---

# erp-admin MFE Implementation (worktree flow)

Implement một issue trong erp-admin (pnpm + Turbo + MFE/FSD monorepo) trong worktree riêng, theo đúng gates của repo.

## Trigger
- User yêu cầu "implement issue #N" / "tách worktree implement" / thêm server-side sorting hoặc filter vào list view.

## Worktree setup

1. Main clone có thể đang có WIP của session khác — KHÔNG đụng vào; check `git status -sb` trước.
2. `git fetch origin` → `git worktree add <path> -b feat/<iid>-<slug> origin/develop` (base LUÔN fresh từ origin/develop).
3. Worktree mới không có node_modules: `pnpm install` → **`pnpm build-infra`** (turbo build `packages/*`) TRƯỚC khi typecheck — nếu không, LSP/tsc báo loạn `Cannot find module '@hilo/*'` + `implicitly has 'any'` (cascade từ package chưa build, KHÔNG phải lỗi thật).
4. Trước khi push: nếu `[behind N]` → `git commit` trước (rebase từ chối khi còn unstaged) → `git rebase origin/develop` (sạch = không conflict) → chạy lại typecheck → `git push -u origin <branch>` (pre-push hook chạy typecheck toàn workspace).
5. MR: template `.gitlab/merge_request_templates/feature.md`, `**Issue / Ticket**: #<iid>` (KHÔNG `Closes #<iid>` — strict UAT lifecycle), verify `detailed_merge_status: mergeable`.

## Verification gates (thứ tự + bằng chứng tường minh)

- tests → typecheck → eslint → build. **Chạy LẠI tests SAU `eslint --fix`** (prettier reformat đổi file sau khi tests đã pass).
- Báo cáo kèm số liệu thật: `Test Files  N passed`, `tsc --noEmit` exit 0, `✓ built in Xs` (pnpm --filter sale build), eslint "No issues found".
- i18n key mới: check tồn tại ở CẢ `en` lẫn `vi` trước khi dùng trong code (vd `customer.filter.channelAll` từng missing cả 2); thêm key giữ `indent=2` + `ensure_ascii=False`, rồi `pnpm exec prettier --check` trên file JSON.

## TanStack DataTable server-side sorting (đã implement ở @hilo/ui DataTable)

- `onSortingChange` của TanStack nhận **Updater** (`SortingState | (prev) => next`), KHÔNG phải state trần. Shared component (DataTable) phải normalize trước khi gọi consumer:
  ```ts
  onSortingChange: (updater) => {
    const next = typeof updater === 'function' ? updater(controlledSorting ?? internalSorting) : updater;
    handleSortingChangeProp ? handleSortingChangeProp(next) : setInternalSorting(next);
  }
  ```
  URL-state setters chỉ nhận plain `SortingState` — viết test trước; test `toHaveBeenCalledWith([{ id, desc }])` bắt đúng bug này (nhận `[Function]`).
- Column **id** (không phải accessorKey) là sort key gửi lên BE → id phải trùng tên field BE (`createdAtInfo` → `createdAt`). Action column cần `enableSorting: false` (accessorKey column mặc định sortable).
- Opt-in props (`sortable`/`sorting`/`onSortingChange`/`manualSorting`, default off) để backward compatible với mọi DataTable consumer khác.
- Wire sort/order: URL state schema (`sort: z.string()`, `order: z.enum(['asc','desc'])`) + `setSorting(SortingState)` map sang `{sort, order}` + reset `page: 1`; thêm `params.sort`/`params.order` vào deps `normalizedParams` (React Query key) của list query.

## Pitfalls

- Đừng "sửa luôn" các vi phạm audit khác cùng lúc — chỉ làm scope của issue; vi phạm khác thuộc issue riêng (vd #137 refactor umbrella) để tránh conflict + diff khó review.
- BE `sort` thường là string tự do (không enum trong OpenAPI) — chọn field sortable khớp field thật (code/name/taxCode/address/createdAt), không bịa.
