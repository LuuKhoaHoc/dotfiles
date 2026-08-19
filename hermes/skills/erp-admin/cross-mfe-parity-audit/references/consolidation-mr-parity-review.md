# Consolidation MR Parity Review

Checklist dùng khi review MR **consolidation**: gộp N implementation local (VD StatusBadge ở finance/hr/employee) vào 1 shared component (`@hilo/ui`), kèm claim "không đổi hành vi nghiệp vụ". Verify parity old-vs-new key-by-key — đừng tin checklist trong MR description.

Real case: MR !620 (2026-08-18, branch `refactor/consolidate-status-badge`) — tìm được regression `draft` mà checklist của tác giả bỏ sót, qua đúng các bước dưới.

## Checklist

1. **Key-by-key mapping diff** — với MỖI implementation cũ:
   ```bash
   git show origin/develop:apps/hr/src/shared/components/StatusBadge/StatusBadge.tsx   # impl cũ
   git show origin/<branch>:apps/hr/src/shared/constants/status-tone.ts                 # map mới
   ```
   Lập bảng: mọi key trong switch/map cũ phải có trong map mới (hoặc cố ý bỏ). **Key thiếu = regression tone âm thầm**. Real case: `draft` có case riêng ở cả HR lẫn employee cũ, nhưng `HR_STATUS_TONE_MAP` mới thiếu hẳn key → rơi default NEUTRAL. (Employee map thì có `draft: NEUTRAL` — thiếu nhất quán giữa 2 map cũng đáng flag.)

2. **Special styles mà tone map không biểu diễn được** — quét từng `case` cũ trả về class KHÔNG phải `STATUS_TONE_*`:
   - Real case: draft cũ = `bg-surface-subtle text-text-body border border-primary` (outline viền primary). Tone map chỉ có 5 tone → style này chết âm thầm.
   - Fix: truyền `className` tại call site (VD `useChangeManagementColumns.tsx:175`) hoặc xác nhận chủ ý với design. Flag là 🔴 vì mâu thuẫn claim "không đổi visual".

3. **Normalization drift** — cũ: `status.trim().toUpperCase().replace(/[\s-]+/g,'_')`; shared mới: `status.toLowerCase()` không trim, không normalize space/hyphen. Status có space/hyphen (`'needs supplement'`, `'on-leave'`) giờ rơi NEUTRAL. Informational, trừ khi BE thật sự trả dạng đó (thì blocking).

4. **Case-lookup có thể CẢI THIỆN coverage** — cũ exact-match để status lowercase thành gray; mới `toneMap[status.toLowerCase()]` fallback tô màu luôn. Đó là improvement, đừng flag là bug.

5. **Typography/token drift** — so base class cũ vs shared default:
   - Real case finance: cũ `text-caption font-caption-bold h-6 ... sm:text-sm` → mới `text-xs font-medium` (mất `h-6`, mất `sm:text-sm` → cỡ chữ desktop nhỏ 1 bậc).
   - Real case HR/employee: mất `tracking-wide`.
   - Nhỏ, gom vào 🟡 "xác nhận chủ ý thống nhất".

6. **Dead code removal safety**: `git grep -n <symbol-bi-xoa> origin/develop` → zero consumer ⇒ an toàn. Real case: `getStatusBadgeClassName` + type `LeaveStatus` đều không ai dùng ở develop → xóa OK.

7. **Blast radius của prop change trên component canonical** — MR sửa cả `@hilo/ui` (VD thêm `children` fallback) thì grep TOÀN BỘ consumer ngoài phạm vi MR:
   ```bash
   git grep -C4 "<StatusBadge" origin/develop -- apps | grep -B4 -A2 -i "children"
   ```
   Không consumer nào truyền children ⇒ an toàn. (Lưu ý: children cũ rơi vào `...props` → Badge render children + `{label ?? status}` = DOUBLE render; `{children ?? label ?? status}` mới sửa luôn cái đó — ghi nhận là fix, không phải regression.)

8. **Verify "typecheck pass" claim** — chạy thật ở worktree sạch: `pnpm install` → `pnpm build-infra` → typecheck từng app. Lỗi `Cannot find module '@hilo/*'` = build-order (packages chưa build), KHÔNG phải code bug. (Chi tiết: skill `mr-local-verification`.)

9. **Grep nhánh mới cho import đường cũ**:
   ```bash
   git grep -n "import.*StatusBadge" origin/<branch> -- apps | grep -v "@hilo/ui"
   ```
   Real case: 27/27 consumer import từ `@hilo/ui` + đủ `toneMap` — sạch.

## Post-review round 2

- `head_sha` đổi = có push mới; verify TỪNG item flag ở head mới (đừng tin message commit fix).
- Commit fix nhỏ gọn (`git show <sha> --stat`): real case fix commit chỉ chạm đúng 2 file tone-map = đúng scope, không creep.
- Trả lời bằng bảng per-issue (✅ FIXED + file:line / còn mở), tag tác giả.
- Sau khi fix pass + pipeline success + user duyệt → approve → merge (`should_remove_source_branch: true`), KHÔNG dùng merge_when_pipeline_succeeds.
