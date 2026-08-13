# Shell Mobile Navigation & Notification Anatomy

Verified from code 2026-08-13 (issue #186 — mobile noti/UX fixes). Source: `apps/shell/src`, `packages/shared/src`.

## Notification bell — where it renders

- `NotificationBell` (`apps/shell/src/components/topbar/NotificationBell.tsx`) carries BOTH variants in one component: desktop `DropdownMenu` inside `shell-topbar-desktop-flex`, mobile `Sheet` inside `shell-topbar-mobile-only` (CSS classes defined in `apps/shell/src/index.css`).
- Render sites: desktop topbar only (`Topbar.tsx`). The MOBILE bell entry point is `UserMenuMobileToolbar.tsx` — its right-side block (`<NotificationBell />` in `shell-topbar-mobile-only`) is rendered in two places: `ProfilePage` (`/profile`) and the mobile user-menu Sheet.
- `MobileBottomNav` Profile item shows the unread badge (`useNotificationStore`) but is NOT a bell.

## Bell regression (issue #186)

- Chốt cũ: ẩn bell trên topbar mobile CHỈ, vì `/profile` đã có bell.
- `0b0b5749f` (Quý, 2026-08-10, "center topbar search and simplify mobile header"): removed `<NotificationBell />` from the mobile header (intended) AND removed the bell block from `UserMenuMobileToolbar` (collateral) → mobile lost every bell entry point.
- `3356be031` (Quý): deleted `MobileNotificationTrigger.tsx` — at deletion it had zero usages outside its own file (dead code; NOT the regression).
- Restore reference: `git show 0b0b5749f^:apps/shell/src/components/topbar/user-menu/UserMenuMobileToolbar.tsx`.

## Mobile avatar / user menu

- `TopbarUserMenu`: mobile = `Sheet` drawer (avatar trigger, `shell-topbar-mobile-only`), desktop = `DropdownMenu`.
- Mobile sheet content (toolbar + header + status + features: profile dialog / reset password / leave balance / logout) is fully duplicated by `ProfilePage` → drawer is redundant; issue #186 Task 2 direction: mobile avatar click → navigate `PATHS.PROFILE`, drop the mobile Sheet.

## Home path resolution

- `getFirstAllowedPath` (`packages/shared/src/utils/rbac.ts`): SUPER_ADMIN/ADMIN/HR_MANAGER → `PATHS.APPS`; HR → `PATHS.HR`; EMPLOYEE → `PATHS.EMPLOYEE`; fallback EMPLOYEE.
- `MobileBottomNav` 5 items: APPS (Element3), EMPLOYEE_REQUESTS (NoteText), home = `getFirstAllowedPath(user)` (Home2), EMPLOYEE_TIME_OFF_MANAGEMENT (Timer1), PROFILE (User + badge). Admin home == APPS → items 1 and 3 duplicate `/apps` (issue #186 Task 3: admin home → `/hr`).

## PATHS (packages/shared/src/constants/paths.ts)

| Key | Value |
|---|---|
| APPS | /apps |
| PROFILE | /profile |
| HR | /hr |
| EMPLOYEE | /employee |
| EMPLOYEE_REQUESTS | /employee/requests |
| EMPLOYEE_TIME_OFF_MANAGEMENT | /employee/time-off-management |
