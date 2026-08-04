# Release description format (erp-admin) — "như các release cũ"

User yêu cầu "format vẫn như các release cũ" → dùng đúng cấu trúc này (thống nhất từ ít nhất release 2026-07-31 → 2026-08-04). Cùng description được dùng cho CẢ GitLab Release record lẫn MR release (`chore(release): release YYYY-MM-DD`).

## Template

```markdown
# Release YYYY-MM-DD

## Phạm vi chính theo BA

### <Module / Feature group>
- **Tên tính năng**: mô tả ngắn theo góc nhìn nghiệp vụ, kèm MR ref — !XXX.
- (mỗi bullet: bold tên + mô tả + nguồn)

### CRM (Sale / Finance / Product) — code đẩy lên main, **module ẩn trên prod**
- ...
- **⚠️ CRM modules (sale/product/finance) bị `enabled: false`** trong `packages/shared/src/config/navigation.ts` trên release branch — ẩn khỏi launcher/apps trên prod như mọi lần vì CRM chưa hoàn thiện; code vẫn nằm trong main, sẽ bật lại khi CRM sẵn sàng.

## MR trong phạm vi release

- !XXX — <title đầy đủ của MR>
- (liệt kê đầy đủ, kèm issue ref trong title nếu có)

## Issue snapshot

- Issue đóng trong window release: #a, #b, ...
- Các issue chưa đưa vào release lần này: <issue + lý do cụ thể (MR còn mở / conflict / chưa merge trong window)>.

## Verification

- [x] Release branch tạo từ `main`.
- [x] Đã merge `origin/develop` vào release branch.
- [x] Commit `xxxxxxx` — disable CRM modules (sale/product/finance) cho prod.
- [x] Typecheck toàn monorepo pass (13/14 workspace) qua pre-push hook.
- [x] Tag `release/YYYY-MM-DD` đã push (annotated, trỏ commit `xxxxxxxx` — HEAD release branch gồm fix build).  ← thêm fix build + SHA nếu có
- [x] `pnpm build` full pass (N/N tasks) sau fix build.  ← chỉ khi có fix build trong release
- [ ] Review MR.
- [ ] Pipeline release pass.
- [ ] Merge vào `main`.
- [ ] Sync `main` về `develop` sau deploy.

## Related MRs

- !XXX, !YYY, ...
```

## Quy tắc

1. Fix build trực tiếp (commit không qua MR, vd align call site với API shape mới sau refactor) → thêm bullet trong mục module tương ứng với `commit <sha>`; KHÔNG thêm vào "Related MRs" (chỉ MR thật).
2. Window release: từ `released_at` của release trước (không phải nửa đêm). MR lọc theo `merged_at`; loại MR release trước và commit image-tag-only.
3. Verification checklist dùng checkbox; mục chưa xong giữ `[ ]`, sau deploy cập nhật trực tiếp description (idempotent, không append note).
4. Fix build / retag xảy ra SAU khi MR release đã tạo → phải `update_merge_request` đồng bộ description MR cho khớp release record.
