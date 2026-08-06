# Worktree Implementation Flow (issue → MR) — erp-admin

Worked example: #143 (server-side sorting for customer list), 2026-08-05. Flow từ lúc user yêu cầu "tách worktree implement issue":

## 1. Setup worktree

- `git worktree list` + `git status -sb` ở main clone trước: main clone **SHARED với các session khác** — có thể đang ở branch khác + WIP chưa commit (real case: finance types #141 đang làm dở trong main clone) → KHÔNG đụng, không commit vào main clone.
- `git fetch origin --prune` → `git worktree add ~/Projects/Hilo-Vppos/erp-admin-<iid> -b feat/<iid>-<slug> origin/develop` — base LUÔN là origin/develop mới nhất.
- `pnpm install` (background, dùng chung pnpm store nên nhanh) → `pnpm build-infra` (build `packages/*` để MFE typecheck resolve được workspace packages).

## 2. Implement

- Đọc pattern feature hiện tại trước khi code (URL state → query params → query key chain — xem pitfall "page là hop cuối" trong `mfe-feature-audit`).
- **DataTable server-side sorting** (kỹ thuật từ #143, áp dụng chung cho mọi table trong erp-admin):
  - Thêm props opt-in vào `@hilo/ui` DataTable: `sortable` (header sort button + arrow indicator), `sorting`/`onSortingChange` (controlled), `manualSorting` (server-side; mặc định off → backward compatible).
  - TanStack `onSortingChange` nhận **Updater** (`SortingState | (prev) => next`) → normalize về plain `SortingState` TRƯỚC khi gọi consumer prop; prop type public = `(sorting: SortingState) => void` (không phải `OnChangeFn`).
  - Header render: `sortable && header.column.getCanSort()` → button wrap header + ArrowUp2/ArrowDown2 theo `getIsSorted()`; column nào không sort được (action...) set `enableSorting: false`; column id phải TRÙNG BE sort field (vd `createdAt`, không phải `createdAtInfo`).
  - URL state: `sort: z.string().catch('')` + `order: z.enum(['asc','desc'])` + `setSorting(SortingState)` → `setState({ sort, order, page: 1 })`.

## 3. Verify (thứ tự, mỗi gate chạy xong ghi exit code)

1. `pnpm --filter sale typecheck` (`tsc --noEmit`)
2. `eslint --fix` các file thay đổi rồi re-check
3. `pnpm --filter @hilo/ui test` + `pnpm --filter sale exec vitest run src/features/customers`
4. **`pnpm --filter sale build` (`tsc -b`) — PITFALL quan trọng**: khi sửa `packages/ui` (vd DataTable), sale build resolve `@hilo/ui` từ **dist** chứ không phải source → `tsc --noEmit` typecheck có thể PASS nhưng `tsc -b` build FAIL với type cũ (real case: `OnChangeFn` vs plain callback). Fix: `pnpm --filter @hilo/ui build` TRƯỚC khi build lại sale. Luôn chạy build cuối, đừng tin typecheck đơn lẻ khi đã đụng packages.

## 4. Rebase + conflict (repo busy)

- develop tiến liên tục: image-tag commits tự động (`chore(sale): update image tag ... [skip ci]`) + feature khác merge giữa chừng (real case: #137 refactor umbrella merge khi đang làm #143, đụng 3 file + **đổi architecture** — table chuyển từ hook-in-table sang props-driven).
- `git fetch` → `git rebase origin/develop` → resolve conflict theo **architecture MỚI NHẤT của develop** (đừng bảo vệ code cũ của mình; #137 đã chuyển CustomerListTable sang props-driven nên wire sort qua props mới thay vì quay lại gọi hook trong table).
- Commit fix bị "dropping ... patch contents already upstream" khi resolution đã chứa nội dung tương đương — bình thường, không panic.
- Rebase rewrite history → `git push --force-with-lease`.
- GitLab `detailed_merge_status: conflict` ngay sau push thường là **transient** (đang tính lại diff) → poll 10-15s × vài lần; chỉ tin khi `has_conflicts: False` + `mergeable`.

## 5. Merge (ship)

- Check CI: `GET /projects/9/merge_requests/<iid>/pipelines` — phải có pipeline `success` (cả 2 pipeline cũ của MR cũng được tính).
- Gắn milestone release tuần hiện tại (vd `v1.0.0`, id=2) cho CẢ issue + MR trước khi merge.
- `PUT /projects/9/merge_requests/<iid>/merge` body `{"merge_when_pipeline_succeeds": true, "should_remove_source_branch": true}` → poll `state=merged` (lấy `merge_commit_sha`).
- Verify UAT lifecycle: issue vẫn `opened` (KHÔNG "Closes #" trong MR description) + `GET /issues/<iid>/related_merge_requests` hiện MR merged.
