# Shell mobile topbar / navigation — decisions & regression-archaeology recipe

Context: issue #186 (mobile UX shell) + #187 (noti filter), 2026-08-13. Facts verified from `develop` at 3356be031.

## File map (shell)

| Surface | File | Ghi chú |
|---|---|---|
| Mobile topbar (h-16) | `apps/shell/src/layout/Topbar.tsx` | hamburger + search + avatar; KHÔNG bell |
| Desktop topbar (h-20) | same file | logo + search + lang + bell + user menu |
| Bottom nav 5 items | `apps/shell/src/layout/MobileBottomNav.tsx` | Apps, Requests, Home(homePath), Time-off, Profile(+noti badge) |
| Profile page | `apps/shell/src/pages/Profile.tsx` | toolbar(lang+bell) + header + status + features(logout...) |
| User menu | `apps/shell/src/components/topbar/TopbarUserMenu.tsx` | mobile = Sheet (drawer), desktop = DropdownMenu |
| Bell mobile trigger | `apps/shell/src/components/topbar/NotificationBell.tsx` | has desktop dropdown + mobile sheet branches (`shell-topbar-mobile-only`) |
| Org name | `apps/shell/src/components/topbar/user-menu/UserMenuAvatar.tsx` | org name `hidden lg:block`, cần truncate |

## Decisions (chốt 2026-08-13, ghi trong #186 Task 2)

- **Chọn page `/profile`, bỏ drawer user menu mobile.** Lý do: bottom nav đã có item Profile (kèm badge noti) → drawer là surface thứ 2 cùng nội dung = duplicate; page scale tốt hơn (noti/attendance/settings phình to); thumb-reach của bottom nav tốt hơn avatar trên topbar; back/refresh/deep-link chỉ page có. Không làm hybrid "drawer quick-action + page" (KISS).
- Drawer cũ chứa đúng nội dung `/profile` (UserMenuMobileToolbar, UserMenuHeader, UserMenuStatus, UserMenuFeatures) → bỏ drawer không mất chức năng.
- Topbar mobile: bell ẩn (chỉ `/profile` có); avatar → navigate `/profile`; nút mở sidebar = `HambergerMenu` (3 gạch ngang).
- Bottom nav Home: admin group (SUPER_ADMIN/ADMIN/HR_MANAGER) → `/hr`, vì `getFirstAllowedPath` trả `/apps` cho nhóm này → trùng item App Dashboard (vị trí 1). Chỉ HR mới có dashboard thực sự hiện tại.

## Regression-archaeology recipe: "feature X biến mất sau khi Y sửa"

Reconstruct lịch sử của một UI surface khi user báo "cái X mất rồi, chỉ muốn ẩn chỗ A thôi":

```bash
# 1. Ai chạm symbol gần đây (pickaxe — tìm commit thêm/xóa symbol)
git log --all --oneline -S "NotificationBell" -- apps/shell/src
git log --all --oneline -S "MobileNotificationTrigger" -- apps/shell/src

# 2. Xem state trước commit nghi vấn (^ = parent)
git show 0b0b5749f^:apps/shell/src/components/topbar/user-menu/UserMenuMobileToolbar.tsx

# 3. Nơi symbol từng được dùng tại từng commit
git grep -l "MobileNotificationTrigger" 3356be031^ -- apps/shell/src   # → chỉ file định nghĩa = dead code khi xóa
```

Case thật: user nhờ Quý "chỉ ẩn bell trên topbar mobile" → commit `0b0b5749f` xóa `<NotificationBell />` khỏi mobile header NHƯNG cũng xóa bell khỏi `UserMenuMobileToolbar` (nơi render bell trên `/profile`) → mobile mất toàn bộ chỗ xem noti. Commit `3356be031` chỉ xóa `MobileNotificationTrigger` (dead code, không nơi dùng). Kết luận regression nằm ở commit đầu, không phải commit xóa dead code.

Lesson: khi user nói "chỉ ẩn ở chỗ A", verify diff KHÔNG đụng chỗ B (cùng commit có thể gỡ nhiều nơi hơn yêu cầu). Với "tính năng mất", tìm commit xóa bằng `git log -S` trước khi đổ lỗi cho commit gần nhất.

## BE notification API contract (2026-08-13, file api-1.json từ BE)

- `GET /api/v1/notifications/me` — status filter `PENDING|DELIVERED|READ` + page/pageSize (mặc định 20); unread = PENDING + DELIVERED
- `GET /api/v1/notifications/me/unread-count` — badge count
- `POST /api/v1/notifications/read-all` — trả `count` rows updated
- `POST /api/v1/notifications/{id}/read` + `/{id}/ack` — idempotent

FE: `ListMyNotificationsParams.status` đã có type nhưng `useNotificationHydrate` chưa truyền; query key `['notifications','me']` chưa include status → cache riêng từng tab khi thêm filter (issue #187). Mẹo đọc OpenAPI JSON ~2MB: `grep -n "notification" file.json | grep /api/v1` để tìm path, rồi `sed -n '<line>,<line+N>p'` — không đọc cả file.
