---
name: erp-admin-ui-mr-review
description: "Reviewing erp-admin UI MRs (shell sidebar, @hilo/ui, icons)."
---

# erp-admin UI MR Review

Repo-specific knowledge for reviewing UI refactor/feature MRs in the erp-admin monorepo (shell, @hilo/ui, @hilo/icons, @hilo/tokens). Complements `gitlab-mr-review` (mechanics) and `mr-local-verification` (local verification) — read those for the workflow; this skill carries the repo facts and the UI behavior-surface checklist.

## Behavior-surface diff for "no behavior change" claims (UI refactors)

UI refactors claiming "không đổi hành vi" need a behavior diff, not just a code diff. Old side: `git show origin/develop:<file>`; new side: `git show origin/<branch>:<file>`. Check:

- **Removed interactions** — gestures the old UI had: click-anywhere-to-collapse, `data-prevent-sidebar-toggle` escape hatches, hover-only paths.
- **Added visible features** — new buttons/sections (real case MR !585: sidebar-footer logout ADDED, duplicating the user-menu logout — scope creep vs. the claim; ask intent).
- **Lost transitions/animations** — Accordion → conditional render silently kills expand animation.
- **Constant deltas** — widths (`w-72` vs `18rem`), breakpoints (`max-w-xs` vs `max-w-[85vw]`), z-index, offsets.
- **Duplication introduced** — same action reachable from two places.
- **a11y regressions** — `aria-expanded` without `aria-controls`; keyboard users locked out of hover-only popovers.
- **New global side effects** — keydown listeners on `window` (shadcn sidebar's Cmd/Ctrl+B preventDefault can hijack rich editors).

Flag each delta as intended-or-not instead of trusting the MR checklist.

## Tokens: shadcn vars are GENERATED, not literal in CSS

- `git grep -n "sidebar" -- '*.css'` returns NOTHING even though `bg-sidebar`, `text-sidebar-foreground`, `bg-sidebar-primary`, `bg-sidebar-accent`, `border-sidebar-border` all work (Tailwind v4).
- Chain: `packages/tokens/tokens/shadcn.json` (light AND dark values) → `packages/tokens/build.ts` emits `@theme inline { --color-sidebar: var(--sidebar); ... }` into `declarations.css` → `apps/*/src/index.css` imports it.
- Pre-existing on develop (MR !585 did not touch tokens) — shadcn-based components can rely on these vars.
- Verify order when tokens look "missing": grep tokens pkg → both modes in shadcn.json → index.css import → check MR diff didn't touch tokens. Never report "missing token" from a CSS-only grep.

## @hilo/icons custom SVGs use HARDCODED fills

- Custom assets (`assets/customs/*.svg`) have literal `fill="#F57014"` etc. — `color="currentColor"` only affects paths using `currentColor`.
- Consequence: active-state text color does NOT recolor these icons; contrast fixes require recolored variants (the `*2` pattern: `employee2.svg` swaps dark fills for white/light).
- Review active states by comparing original vs variant SVG fills directly, and check the active-icon map covers every PARENT module with children (MR !585: Restaurant, Invoicing, Employee, Accounting, CustomDash — all five had `*2`).

## Test traps

- Vitest + zustand persist + axios-interceptor testing recipe (`vi.hoisted` localStorage before imports), eslint-plugin-react-hooks v7 `set-state-in-effect` disable placement, `vi.importActual` type-import fix, lint-staged commit-abort semantics, and the stash-verify pattern for pre-existing failures: `references/fe-test-and-lint-pitfalls.md`.
- `MenuIcon.test.tsx` mocks `@hilo/icons` with a hardcoded 34-name `vi.hoisted` list — adding an icon import to `MenuIcon.tsx` without extending the list breaks the suite.
- Fresh worktree: shell vitest fails `Failed to resolve entry for package "@hilo/icons"` even WITH `vi.mock` — mock factory still needs the package entry; fix = `pnpm build-infra` first (same missing-dist pattern as typecheck).
- **Pre-push hook false alarm on an existing clone (real case MR !596):** `git push` to a teammate's branch fails the pre-push hook (`pnpm -r --parallel run typecheck`) with TS2305 `has no exported member 'SidebarMenuSubButton'/'useSidebar'/'Accounting2'…` in `apps/shell` — the branch code is FINE (its GitLab pipeline passes); the local `packages/*/dist` is stale (dist not tracked in git, regenerated only by build-infra). Fix: `pnpm build-infra` (~10s, turbo cache), push again. Don't chase the TS errors or blame the branch — hook re-runs in ~20s once dist is fresh.
- **Stale dist in the MAIN clone after `git merge origin/develop` (real case issue #182, 2026-08-14):** same root cause, different trigger — merging newer develop into a local branch makes workspace-package dist stale even with no worktree involved. Signature: app typecheck fails TS2305 `has no exported member 'X'` in files the diff never touched, naming exports the freshly-merged develop added. Fix: `pnpm --filter @hilo/shared build` (or `pnpm build-infra`) and re-run. A `git stash push -u` → test → `git stash pop` round-trip has the same trap: after pop, previously-passing tests can fail because dist no longer matches the restored source — rebuild dist before trusting any post-stash/pop test run.
- Tests asserting literal Tailwind class strings (`toHaveClass('...hidden')`) prove class presence, not layout.

## Shared sidebar primitive (since MR !585)

- `packages/ui/src/components/ui/Sidebar.tsx` — shadcn-style: `SidebarProvider`/`useSidebar` context, `collapsible="icon"`, mobile Sheet branch via `useMediaQuery('(max-width: 767px)')`, ~20 exports.
- Depends on `Button` `variant="ghostnohover"` + `size="icon-sm"` (both exist).
- Shell usage: `SidebarProvider` (MainLayout) + `DesktopSidebar` (`Sidebar collapsible="icon"` with `md:!top-20 md:!h-[calc(100vh-5rem)]` offsets below the h-20 topbar).
- Known quirk (🟡 review finding, don't rediscover): the port's `setOpen` writes the `sidebar_state` cookie on every toggle but `useState(defaultOpen)` never reads it back (shadcn's original reads the cookie on init) → cookie is write-only dead code, state doesn't persist across reload. Flag as suggestion (remove cookie or wire the read).
- Future MFE sidebar work: reuse this before building anything new (repo search-before-code convention).

## Verifying shadcn-port props: check Radix types, don't guess

- When a ported primitive uses a non-standard-looking prop (`<AccordionItem asChild>`), verify against the installed Radix types instead of assuming it's a typecheck error: `grep -n "Item\|asChild" node_modules/@radix-ui/react-accordion/dist/index.d.ts` → `AccordionItemProps extends Omit<CollapsibleProps, ...>` and CollapsibleProps carries `asChild` → valid. The unified `radix-ui` package is a thin re-export (`import * as reactAccordion from '@radix-ui/react-accordion'`) — follow it to `node_modules/@radix-ui/*`.
- Not every shared component lives in `components/ui/`: `TableOptionMenu` is at `packages/ui/src/components/customs/TableOptionMenu.tsx` (props: `centered` default true, `className`, item `hidden`/`onSelect`). Grep the package for the real path before claiming a prop doesn't exist.
- `AccordionTrigger` with `asChild` (MR !585): when asChild, the default ArrowDown2 chevron and its class base are skipped — children fully own the trigger content.

## Shared-component className overrides: verify cn() before trusting visual claims

When an MR passes className overrides to a @hilo/ui component (`<Badge className="size-6 p-0 text-[13px] ... bg-sky-100 text-sky-700">` over base `px-2 py-0.5 text-xs font-medium bg-secondary text-secondary-foreground`), the overrides only win because `packages/ui/src/lib/utils.ts` `cn()` = clsx + `extendTailwindMerge` (custom `font-size` group extends `text-h1..text-footnote`). Recipe (real case MR !587 category-count badge circular):

1. **Variant exists** — confirm `variant="secondary"` in the component's cva variants before assuming TS would catch it.
2. **cn = tailwind-merge** — read `lib/utils.ts`; tailwind-merge makes later className beat base classes (`p-0` > `px-2 py-0.5`, `text-[13px]` > `text-xs`, `bg-sky-100` > `bg-secondary`, `text-sky-700` > `text-secondary-foreground`). WITHOUT tailwind-merge, conflict resolution is generated-CSS order — unpredictable; flag the visual claim as unverified.
3. **Geometric guarantee lives in the base** — `rounded-full` is in Badge's base class string, so `size-6 p-0` = perfect circle; check the base, not the override.
4. **First-consumer check** — `git grep -n '<override pattern>' <head> -- apps packages/ui/src` → 0 hits = new pattern, harmless; don't flag as convention drift.

## ConfirmActionDialog / shared-dialog standardization review (real case MR !594)

When an MR standardizes N custom dialogs onto a shared base (`ConfirmActionDialog` in `packages/ui/src/components/customs/`), the review recipe:

1. **Base diff must be additive-only** — new optional props (`children`, `confirmDisabled`) with defaults = existing consumers (employee/sale/shell/product) untouched; anything else = behavior-surface work on every consumer.
2. **Type-mapping semantics trap — map consumer action types to base types and compare BUTTON COLORS** (real case !594): consumer-local types (`deactivate`/`reactivate`, `OrganizationRowAction`) map to base types (`activate`/`deactivate`/`delete`/`blocked`); base renders `variant={type === 'delete' ? 'destructive' : 'default'}`. The old copies hand-rolled colors: reject flows used `bg-primitive-red-500` (red), but mapping reject → `'deactivate'` renders `variant=default` (PRIMARY BLUE) — a visible behavior change hidden behind the "không đổi hành vi nghiệp vụ" claim. For each type mapping, diff the old confirm-button className against what the base renders for that type; flag red→blue/destructive-semantics changes 🟡 (suggest `type='delete'` or a dedicated 'reject' type, or accept + document the decision). **Icon side-effect trap**: mapping reject → `type='delete'` fixes the color but ALSO swaps the icon to Trash (base 'delete' renders Trash) — semantically odd for "Từ chối" (old UI: Warning2); the clean fix is a dedicated `reject` type (Warning2 + destructive). Check BOTH color and icon for every mapped type.
3. **Close-button a11y regression**: base `DialogContent` has a built-in X with hardcoded sr-only `"Close"` (English); custom AlertDialog copies used localized `aria-label` (`t('...closeDialog')`). Migrating AlertDialog→base loses the localized screen-reader label in the Vietnamese UI. 🟢 (pre-existing base behavior, the MR widens its footprint).
4. **Dead-code check before reviewing effort**: `git grep -rn <DialogName> <head> -- apps` → 0 consumers on BOTH base and head = the refactor touched dead code — informational 🟢 ("refactor vô hại nhưng có thể xóa luôn"), not a risk finding.
5. **State-reset preservation**: dialogs with form children (reject-reason Textarea, OT payroll percent field) relied on a key-remount pattern (`dialogContentKey = \`${open}-${mode}-${record.id}\``) to reset inner state per open — verify the key survives the refactor (it may move onto a wrapper component). `confirmDisabled` must union every old `disabled` condition (reason empty, OT detail loading/error/`canConfirmApprove`).
6. **AC documentation obligations**: issues can require "document the decision in the issue when doing" (real case #176 AC #5: decision-dialog family standardize-or-keep) — check issue discussions; MR doing the work without the doc note = open AC item 🟡.
7. **`destructive` variant = `bg-destructive/90`** (90% opacity) vs old solid `bg-error-surface-default` — tiny delta, 🟢.

### Long inline async closures in JSX props (user preference, real case !594 round 2)

The user flags long logic bodies inlined in JSX props ("dồn xử lý 1 đống vào props") — e.g. ~25-line closure (user guard → mutations → toasts → state reset → close → catch) in `onConfirm={async (payrollPercent) => {...}}`. Treat as 🟡 suggestion: extract a named `const handleConfirm = async () => {...}` in the component body, pass `onConfirm={handleConfirm}`. Heuristics: (a) a prop value carrying 10+ lines of logic; (b) a sibling component in the SAME MR already uses the named-handler pattern — inconsistency within the MR strengthens the finding (real case: `LeaveRequestDecisionDialog` had named `handleConfirm`, `RequestManagementDecisionDialog` didn't); (c) fix stays KISS — named handler only, no custom hook; toasts stay in the component layer (HR AGENTS.md convention). Pre-existing pattern is still worth flagging when the MR rewrote that exact region.

## TableOptionMenu sync MRs (real case MR !595)

Row-action refactors (inline icon buttons → shared `TableOptionMenu`) — verified checklist:
- `TableOptionMenu` item props confirmed: `hidden`, `className`, `centered` (default true), `ariaLabel`, `triggerIcon` — `visibleItems` filtering happens inside the component.
- PermissionGuard → `hasRole` + `useAuthStore` is STRICTER (user null → item hidden vs PermissionGuard rendering children for anonymous) — correct direction, don't flag (see gitlab-mr-review §9 role-gate parity).
- Verify LIST/non-actionable branches are untouched by the diff (mode branch + `!isActionable → null` kept), and that the parent passes `mode={actionMode}` (the columns hook, not the component, decides PENDING vs LIST).
- Spec coverage recipe: role-matrix tests (HR_MANAGER sees approve+reject, HR sees approve only, EMPLOYEE sees viewDetail only, non-pending → empty) with `vi.hoisted` mutable user + mocked `TableOptionMenu` that applies `hidden` filtering — the right shape for these.
- Direct vitest run: `pnpm --filter <app> exec vitest` can fail on a deps-status check that insists on `pnpm install`; bypass via the binary directly: `cd apps/hr && ../../node_modules/.bin/vitest run <spec>` (app DIR name ≠ filter name — `--filter hr-dashboard` = `apps/hr`). If the main clone has no `packages/*/dist`, build them in the detached worktree with symlinked node_modules: `CI=true pnpm --filter @hilo/ui... build` (~2s) — specs using `importOriginal` on `@hilo/ui` need real dist. A spec NEW on the MR branch reports `No test files found` from the working tree (stale develop) — always run from a worktree at head_sha.

## Token-value MRs: verify VALUES, dark mode, and dist tracking (real case MR !597)

For 1-line `shadcn.json` token mapping changes:
- **Values live in `packages/tokens/tokens/tokens.json` under the `01 Style Tokens` namespace** — plain `grep hilo-surface-subtle packages/tokens/tokens/` finds nothing outside shadcn.json; traverse the JSON (python json walk) to read real hex values (`Greyscale.Surface.Default=#f8fafc`, `Subtle=#ffffff`).
- Check BOTH `light` and `dark` blocks of shadcn.json — a light-only change is usually intentional (dark `--sidebar` = `greyscaledarkmode-500` stays).
- Consumer chain: `git grep -n "bg-sidebar" <head> -- packages/ui/src apps/shell/src` → `Sidebar.tsx` desktop+mobile + `ShellSidebarContent`; token flow `--sidebar` → `declarations.css` `--color-sidebar: var(--sidebar)` → `bg-sidebar`.
- **`packages/tokens/dist` is NOT tracked in git** (`git ls-files` empty) — pipeline build-infra regenerates it; never demand a dist commit.
- Local verify: `CI=true pnpm --filter @hilo/tokens build` (fast, regenerates `dist/declarations.css`).

## Shell mobile topbar / bottom-nav conventions (chốt 2026-08-13, issue #186)

Review shell MRs touching mobile chrome (`Topbar.tsx`, `MobileBottomNav.tsx`, `ProfilePage`, user-menu components) against these conventions — each was a real regression or duplicate surface:

- **Bell noti**: mobile topbar KHÔNG render `NotificationBell`; nơi xem noti duy nhất trên mobile là trang `/profile` (qua `UserMenuMobileToolbar` hoặc trực tiếp trong `ProfilePage`). Đã từng vỡ: commit `0b0b5749f` gỡ bell khỏi mobile header (đúng ý) NHƯNG đồng thời gỡ luôn bell khỏi `UserMenuMobileToolbar` → mobile mất hết chỗ xem noti (badge đếm trên bottom nav vẫn còn = "có noti mà không xem được").
- **Avatar topbar mobile** → navigate `PATHS.PROFILE`, KHÔNG mở user-menu Sheet (drawer). Sheet mobile trùng nội dung `/profile` (header/status/đổi mật khẩu/số dư phép/logout) → redundant surface; MR thêm lại drawer cho avatar = 🟡 duplicate.
- **Bottom nav Home theo role**: SUPER_ADMIN/ADMIN/HR_MANAGER → `PATHS.HR` (KHÔNG `/apps` — `getFirstAllowedPath` trả `/apps` cho nhóm này → trùng item App Dashboard trên bottom nav); HR → `/hr`; EMPLOYEE → `/employee`.
- **`UserMenuAvatar` org name**: bắt buộc `whitespace-nowrap` + `truncate` + max-w hợp lý — wrap 2 dòng trên cửa sổ desktop hẹp là bug (real case ảnh chụp 2026-08-13, topbar grid `minmax(0,1fr)` ép cột phải).
- **Icon mở sidebar mobile** = `HambergerMenu` từ `@hilo/icons` (3 gạch ngang) — không đổi sang icon khác.
- **Profile destination pattern** (dùng cho review đề xuất UI): khi bottom nav đã có item destination (vd Profile), trigger topbar cho cùng nội dung phải navigate tới destination đó, không mở overlay trùng; page thắng drawer khi nội dung sẽ phình (noti/attendance/settings).

Chi tiết quyết định + recipe truy vết regression (git log -S): `references/shell-mobile-ux.md`

### Shell MR verified-implementation patterns (real case MR !598, all merged)

Review checklist items for shell mobile/desktop chrome MRs — each was verified as the correct fix in !598:

- **Portaled DropdownMenu hang on resize**: hiding the desktop trigger with CSS (`hidden md:flex`) does NOT unmount portaled `DropdownMenuContent` — crossing below `md` leaves the menu stuck open. Correct fix: `open={isDesktop && dropdownOpen}` + `useEffect(() => { if (!isDesktop) setDropdownOpen(false); }, [isDesktop])` where `isDesktop = useMediaQuery('(min-width: 48rem)')`. Flag MRs that only CSS-hide the trigger without state cleanup.
- **Dismiss page on viewport crossing**: `/profile` is the mobile user-menu surface; crossing to desktop dismisses it. Pattern: `window.matchMedia('(min-width: 48rem)')` + `addEventListener('change')` → `navigate(resolveProfileDismissTarget(from, fallback), { replace: true })`. Validate `from` (location.state) before using: `isInternalAppPath` (starts with `/`, rejects `//evil` protocol-relative) + `isProfilePath` guard (don't return to /profile), fallback `getFirstAllowedPath(user)` (null-safe → LOGIN). Deep-link straight to /profile on desktop intentionally stays (dismiss only fires on viewport CHANGE). Effect deps `[location.state, navigate, user]`.
- **`SidebarTrigger` accepts children**: `packages/ui/.../Sidebar.tsx` renders `{children ?? <TriggerIcon/>}` — a custom icon (e.g. `HambergerMenu` for the mobile hamburger requirement) is passed as children, not by replacing the component. Verify by reading the impl before claiming the icon can't change.
- **`from`-state preservation utils**: `buildProfileLinkState(pathname, search, existingState)` — when already on /profile, PRESERVE the existing `from` (else re-navigating profile→profile overwrites the return point); otherwise capture `pathname + search`. New utils must be pure + unit-tested (`profile-navigation.test.ts` 6 tests, `mobile-bottom-nav.test.ts` 3 tests — run via the worktree recipe).
- **Localized home-path change**: `getMobileBottomNavHomePath(user)` flips ONLY when `getFirstAllowedPath(user) === PATHS.APPS` → `PATHS.HR`; HR/EMPLOYEE roles unchanged; desktop logo/sidebar keep the shared helper untouched. A MR that edits the SHARED `getFirstAllowedPath` instead is scope creep (issue #186 Task 3 explicitly said keep the shared helper).
- **"Who renders X now" grep after surface removal**: after deleting a Sheet/drawer, verify the shared content component still has a live render path: `git grep -rn <ComponentName> <head> -- apps/shell/src | grep -v '<ComponentName>.tsx'` — empty result = the feature it carried (e.g. NotificationBell) silently vanished again.

## Locale-only label MRs (real case MR !596)

For MRs touching only `packages/locales/src/translations/{vi,en}/hr.json` (+ a small component diff for styling):

1. **Verify each issue bug against the branch, not the issue's list** — issue enumerations are approximate (issue #185 said "7 places" for formula spacing incl. `ctv`, but `ctv` was already correct pre-MR). Grep old strings on the branch ref: `git grep -nE "lũy tuyến|A1\+A2\+A3|A-B2" origin/<branch> -- 'packages/locales/src/translations/*/hr.json'` — regex alternation, escape `+`. Beware false-positive hits from substring matches (new "Trên 10 - 30 triệu" matches a search for "10 - 30 triệu").
2. **Prove no test breaks**: `git grep -nE "<old strings>" origin/<branch> -- '*.spec.*' '*.test.*'` → 0 hits = CI safe. MR Testing section may omit vitest entirely for label MRs — fine once the grep is clean.
3. **vi/en parity**: line-count deltas differ by design (VNĐ exists only in vi, "million"/"VND" only in en) — compare KEY sets, not raw counts; both files must change the same keys.
4. **JSON validity**: `git show origin/<branch>:<file> | python3 -m json.tool > /dev/null` per locale file.
5. **Same-family leftovers elsewhere**: after a "VND→VNĐ" sweep of payslip labels, grep the whole `vi/hr.json` for `VND` — leftovers in OTHER features (real case: `"grossSalary": "Lương Gross (VND)"` in the employee-contract form, placeholder beside it already "VNĐ") are out-of-scope 🟢 follow-up suggestions, NOT blockers; don't demand them in this MR.
6. **Case/capitalization consistency**: when normalizing "Trên"/"Over" into brackets 10/20/30, check the 35 bracket already in the file ("35% (over 100 million)" lowercase) — 🟢 micro-note, never blocking.
7. **Currency convention**: vi uses "VNĐ", en keeps "VND"/"million" — intentional, don't flag en as "missing the fix".
8. **Extra change beyond the linked issue** (real case: divider-removal commit riding on a 5-bug MR): diff the MR's commits against the issue's enumerated bug list and explicitly list anything beyond as 🟡 "confirm intent" — the author may have gotten it from a design/QC request not recorded in the issue. Disclosed-in-description ≠ in-scope; still confirm.
9. **"Removed X but sibling still there" trap**: MR says "remove divider line" but rows keep `border-t` (full-width top border per row) → the visual separator still exists. Frame as an intent question with both branches spelled out ("bỏ hẳn → bỏ luôn `border-t` khỏi class base; chỉ bỏ line inset trang trí → hiện trạng đúng"), never assume which.
10. **Dead-token check after removals**: after deleting the only consumer of a CSS var (real case: `--slip-line` span), `git grep -n "<token>" origin/<branch> -- apps packages` → definition-only hits = dead config; 🟢 cleanup note naming the defining file:line (real case: `payroll-company.ts` L129 var + L80 color).

## Status-label i18n sweep — two severity tiers, one root cause (real case issue #188)

When prod shows a raw i18n key (`features.timeOffManagement.statuses.canc`) or a bare status string (`canc`) in a badge, the same BE status value hits EVERY status surface in both MFEs — sweep before filing, with two severity tiers:

- **Tier 1 — raw i18n key (worst, no fallback)**: `t(\`<ns>.statuses.${status}\`)` interpolated with NO defaultValue → full key string in UI. Sites: `useLeaveRequestColumns.tsx`, `useChangeManagementColumns.tsx` + change-mgmt `ChangeManagementFiltersPanel` + `ChangeManagementChangeContentSection` (read-only Input).
- **Tier 2 — bare status value (degraded)**: `getStatusLabel(status, tCommon)` in `packages/shared/src/utils/status.ts` — normalizes (lowercase, `-`/space → `_`) then `tCommon(\`status.${key}\`, { defaultValue: status })` → missing leaf renders the raw value (`canc`), no key braces. Consumers: HR `useRequestManagementColumns`, employee `useRequestsColumns`/`useApprovalInboxColumns`/`useHandledRequestsColumns`, `ApprovalListSection` (HR+employee), dashboard summary cards, attendance-adjustment modal.

Sweep recipe:
1. `git grep 'statuses\.\${' origin/develop -- apps --include='*.ts*' | grep -v translations` — every Tier-1 call site; `git grep -rln 'getStatusLabel' origin/develop -- apps` — every Tier-2 consumer.
2. JSON-traverse BOTH en+vi of every namespace hit (dotted grep lies): `hr.json` `features.{timeOffManagement,changeManagement}.statuses`, `common.json` `status`, `employee.json` — compare leaves against `REQUEST_STATUS` (draft/pending/approved/rejected/cancelled) + feature extras (`auto_approved`, `waiting`, `applied`).
3. **Confirm BE canonical value with the user/BE** (real case: `cancelled` confirmed). Add BOTH leaves: canonical (fixes new data) + observed legacy (fixes stale prod data, keep as fallback; note in issue which is canonical).
4. File ONE umbrella issue per root cause (same BE value, same fix family) — label `priority::high` when prod-visible; include both MFE labels if the sweep crosses MFEs; list every affected file:line.

Worked example (issue #188, 2026-08): BE returns `canc` for cancelled leave requests — namespace/consumer matrix + per-screen severity in `references/status-label-i18n-sweep.md`.

### Time-off specifics (the original incident)

- HR time-off list badge: `useLeaveRequestColumns.tsx` renders `t(\`features.timeOffManagement.statuses.${row.original.status}\`)` — the locale namespace in `hr.json` (en+vi) carries ONLY: draft/pending/approved/rejected/applied/auto_approved/waiting. Any other BE status value renders the raw key (prod incident 2026-08-13: `...statuses.canc` on a cancelled leave request).
- **BE value vs FE constant drift**: BE sends `canc` for cancelled leave requests; FE constant `REQUEST_STATUS.CANCELLED = 'cancelled'` (`packages/shared/src/constants/status.ts`). Fix pattern: add BOTH keys to the locale (`canc` + `cancelled` = "Đã hủy"/"Cancelled") — one satisfies today's BE value, the other hardens against BE aligning to the FE constant; confirm the BE contract and note which value is canonical in the issue.
- Color badge is NOT part of the bug: `StatusBadge.getStatusStyles` normalizes (`trim().toUpperCase().replace(/[\s-]+/g, '_')`) → unknown values fall to neutral gray (CANCELLED maps to neutral too).
- Employee MFE has its own safe namespace (`leave.history.status.cancelled` en+vi) — the drift is HR-only.
- Diagnosis shortcut: the raw key string IS the BE status value — no API call needed to prove what the backend sent.

## Direct-fix on the author's branch (real case MR !596)

When the user asks to fix a small review finding DIRECTLY on the teammate's branch instead of filing a follow-up issue ("sửa trực tiếp trên gitlab/local giúp Quý luôn được không?" — preferred for 🟢/one-liner items):

1. `git switch -c <branch> origin/<branch>` (remote-only branch), apply the patch.
2. **`git add <specific path>` ONLY — never `git add -A`**: the user's unrelated local modifications (modified CONTEXT.md, untracked scratch/) must NOT ride along into a teammate's branch. Verify with `git status` + `git diff --stat` pre-commit that only the target file is staged.
3. Conventional commit message (`fix(hr): ...`; commit-msg hook enforces commitlint).
4. Push runs the pre-push typecheck hook (`pnpm -r --parallel run typecheck`, all 13 workspaces, ~20s) — stale local `packages/*/dist` fails it with TS2305 `@hilo/ui`/`@hilo/icons` missing exports (branch itself is fine); `pnpm build-infra` then push again (see Test traps above).
5. After push: verify the remote head (`git fetch origin <branch>` + `git log -1 origin/<branch>` + `git show origin/<branch>:<path>`), post a SHORT MR note tagging the author (commit sha + one-line what/why — don't let them discover a foreign commit silently), then `git switch` back to the user's original branch to restore their working context.
6. Lifecycle continues as normal: "approve + merge khi pipeline pass" → check pipeline at the new head sha → approve (`sha=` the new head) → merge (`should_remove_source_branch: true`) → close the linked issue.

## Multi-round re-review: develop-sync scope triage

When a re-review shows head moved AND `base_sha` changed (author merged develop or rebased — real case MR !587 round 3: base `b6e19bf7` → `6fff3e2c`), triage BEFORE reviewing the delta:

1. `git log <last-reviewed-sha>..<new-head> -- <the MR's changed file paths>` → entries must be ONLY MR commits. Any develop commit touching an MR file = sync conflict worth inspecting. Real case: raw `git log` showed ~14 develop commits (sidebar/hr/employee noise) but the path-filtered log showed exactly 2 MR commits → clean sync.
2. `git diff --stat <new-base> <new-head>` → file list must match the MR's changed-files count/scope (8 files stayed 8 files).
3. Review only the MR-only commits' diffs (`git show <commit>`); skip the develop noise entirely — the MR diff base...head is ground truth of what merges.
4. Re-check pipeline for the NEW head sha (`list_merge_request_pipelines` → status per sha), and treat a stale pipeline claim in the description ("đang chờ chạy" while the newer pipeline already shows success) as a 🟢 note, not a blocker.

## Hook-refactor diff traps (real case MR !599)

- **Query `enabled` hunk attribution**: a diff hunk changing `enabled: isAuthenticated` → `enabled: isAuthenticated && shouldMergeIntoStore` in a `useNotificationHydrate`-style hook looks like it disables the LIST query (would break filtered tabs) — but the hunk can belong to a SIBLING query (countQuery) in the same region. Before flagging a 🔴 "feature never fetches", read the FULL current file and attribute every `enabled:`/`queryKey`/`queryFn` hunk to its exact query (listQuery vs countQuery vs mutation). Real case: the conditional `enabled` was countQuery-only (badge count skipped in filtered mode — intentional), listQuery kept `enabled: isAuthenticated`.
- **Cache-write helpers across query keys**: hook refactors that add `setQueryData` cache mutation helpers (per-status list caches, optimistic remove/clear) — verify each helper's `queryKey` prefix matches the queries that render that surface, and that `invalidateQueries` uses a PREFIX that matches all variants (e.g. `['notifications','me']` prefix invalidates `['notifications','me','list',status]` too — array prefix matching, not exact-match).

## Feature CRUD review — common anti-patterns (2026-08-19, issue #200)

When reviewing a new CRUD feature (list + detail + create/update/clone/deactivate) in any MFE:

### 🔴 Pagination total mismatch with client-side gating

Server returns total count across ALL roles (system + template + custom). Client applies `filterRolesByGating()` to hide system/template for non-admin. Footer displays server `totalItems` but table shows only filtered subset — "trên tổng số 100" while user sees 50 roles.

**Fix options**: (a) use `filteredList.length` for footer total; (b) pass server-side filter params (`isSystem=false&isTemplate=false`) for non-admin; (c) add a separate `filteredTotal` from the server.

### 🟡 Raw query key arrays vs QUERY_KEYS constants

Mutations invalidate list queries using hardcoded arrays `['crm', membershipId, 'authorization', 'roles']` instead of `QUERY_KEYS.CRM.ROLES(membershipId)`. React Query prefix matching makes this work, but it violates repo convention and breaks silently if query key format changes. Always use the `QUERY_KEYS` constant.

### 🟡 Gating functions should have unit tests

`filterRolesByGating`, `canEditRole`, `canDeactivateRole` — test all 3 role types (system/template/custom) × 2 user types (admin/non-admin). The test file `role-permissions.test.ts` in issue #200 is the reference pattern.

## Pre-MR / pre-commit implementation review (uncommitted working tree)

When the user asks to review an issue implementation that agy/antigravity coded but NOTHING is committed yet (no MR to diff against):

- **Detect the state first**: branch carries the issue name but `git log --oneline -5` shows no new commits → everything is still in the working tree. `git status --short | wc -l` gives the total breadth; `?? apps/partner/` (untracked dir) = a whole new MFE workspace never staged. Don't hunt for an MR by issue iid when there are no commits — `list_merge_requests(search=<iid>)` returns [] or an unrelated MR.
- **Verify each review-feedback item (B1–B10 style) by direct grep/run, never by re-reading the walkthrough**: duplicate JSON key → count RAW occurrences (`open(f).read().count(key)`), because `json.load` silently keeps the LAST value so a parse-based check can never see a duplicate (real case #183: CRM-403-001/SYS-409-001 ×2 in common.json vi+en); missing locale keys → parse JSON + compare against the expected key list; wired handlers → grep callback names in the parent page; fetch gates → grep `enabled:` in modals; scratch dirs → `ls`; hardcoded strings → grep the literal; loose types → grep the field in the types file; permission placeholders → grep `:***`.
- **Re-review delta**: `session_search` the previous review of the same issue, re-run the SAME checks, and report unchanged items WITH evidence ("line 73–74 still `crm:authorization:***` — same as 14/08") instead of re-reviewing from scratch.
- **Mixed-scope working tree**: `git status` mixes the issue's files with OTHER in-progress work (hr/employee/shell...) — when committing, select issue-scope paths only, NEVER `git add -A`; warn the user which paths belong to the issue.
- Verify full battery (tests + typecheck × touched workspaces + build) on the CURRENT tree before reporting — same as MR verification, just no worktree needed.

## GitLab API outage (TLS cert expired / server unreachable) — review fallback path

When MCP GitLab fails with `certificate has expired` (gitlab.vppos.vn cert — real case 2026-08-13) AND glab/curl also fail TLS verification, the review can continue end-to-end:

- **API reads/writes**: `curl -sk -H "PRIVATE-TOKEN: $GITLAB_TOKEN" "https://gitlab.vppos.vn/api/v4/..."` — `-k` bypasses the dead cert; `GITLAB_TOKEN` is set in the shell env (never echo it). Covers issues (`/issues/<iid>`), MR metadata (`/merge_requests/<iid>`), changed files (`/merge_requests/<iid>/changes`), pipelines, and issue updates.
- **Fetch branches**: `git -c http.sslVerify=false fetch origin <branch> develop` — fetch-only bypass keeps the local clone review-ready while the server cert is broken. Never push with the bypass.
- **Post resolvable review threads without MCP**: `curl -sk -X POST /api/v4/projects/<id>/merge_requests/<iid>/discussions -H "Content-Type: application/json" -d '{"body": "<markdown>"}'` → returns a thread id; body-only threads are still resolvable (same semantics as `create_merge_request_thread` without position). Verify the response contains `notes`.
- **Issue description patches**: `PUT /issues/<iid>` with full `description`+`labels` works; the `update_issue_description_patch` search_replace format (`<<<<<<< SEARCH ... ======= ... >>>>>>> REPLACE`) also works via REST. **`add_labels` and `remove_labels` are SEPARATE fields** — adding `status::done` does NOT remove `status::review` (real case #187/#188: both labels coexisted until a second `remove_labels: "status::review"` call). Always issue both when flipping a status label.
- **CI impact triage — runner check before pipeline blame**: the same TLS root cause takes the project runner offline (`GET /projects/9/runners` → `online=False`) → pipelines stall with scan jobs `pending` and the manual `deploy:uat` gate never becomes playable (real case 2026-08-13: UAT deploy blocked). Before blaming pipeline config or rerunning, check runners; deploy resumes only after cert renewal + runner reconnect (replay the gate afterwards).
- **BE contract check for query-param capability**: settle "does BE accept X param form?" from the live OpenAPI instead of guessing: `curl -sk https://api-erp.vppos.vn/openapi.yaml` (1.5MB) then grep the endpoint's `parameters`/`enum`. Real case !599: `GET /notifications/me` `status` is `type: string, enum: [PENDING, DELIVERED, READ]` (single value) → comma-separated `PENDING,DELIVERED` NOT supported → the DELIVERED-only proxy stood (confirmed with PO). The endpoint itself 401s without a Bearer token, so the spec is the authoritative contract for read-only questions.
- **MR↔issue link repair when the author forgot the link** (real case #181/!590): add `**Issue / Ticket**: <work_items URL>` to the MR description via `PUT /merge_requests/<iid>` — GitLab auto-creates the "mentioned in merge request !N" system note on the issue; then set `status::done` on the issue manually (post-merge, per convention issues stay OPEN with status::done).
- Report the cert expiry to the user as infra (breaks MCP, glab, curl, and CI git ops) — it is NOT a code finding.

## UAT deploy drive: gate → bridges → children (verified 2026-08-13)

Deploying develop to UAT when asked ("deploy UAT giúp tôi"):

1. **Find the parent pipeline**: `GET /projects/9/pipelines?ref=develop&per_page=1` — take the LATEST (auto-canceled older ones are normal after a second merge lands; GitLab cancels superseded pipelines on the same ref).
2. **Gate**: wait until `deploy:uat` (stage `gate`) shows `status=manual` — it only becomes playable after the scan stage finishes (sonarqube `allow_failure: true`, trivy). Play: `POST /jobs/<id>/play`.
3. **Bridges, not jobs**: the `trigger:*` entries are bridges — read them via `GET /pipelines/<parent>/bridges` (NOT `/jobs`); each bridge has `downstream_pipeline.id`. **Changes-rules**: touching `packages/shared` or `packages/locales` fires ALL 7 MFE triggers (shell/hr/dashboard/employee/finance/product/sale); an app-only MR fires one. On develop, children AUTO-deploy (no manual `deploy:app` — that's the main/prod pipeline).
4. **Timing**: one shared runner, builds run in parallel but each takes ~15 min (observed: 5 builds ≈ 16 min); expect ~20-30 min total for all 7. Poll children `GET /pipelines/<child>` until `success`.
5. **Failure triage mid-deploy**: scan job failed with EMPTY trace = job never started (runner offline — check `GET /projects/9/runners` online flag; infra, not code) → retry via `POST /jobs/<id>/retry` after the runner returns. Sonarqube `EXECUTION FAILURE` at ~1.4s = SonarQube server unreachable — informational.
6. **User can cancel for bandwidth** (real case: BE gấp build) — children all become `canceled`; acknowledge, don't retry; re-deploy later = new parent pipeline on develop (the played gate won't re-fire children cleanly).
7. **UAT verify host**: `https://erp.hilo.com.vn/apps/<mfe>/` (NOT `*-uat-erp.vppos.vn`); brief 502 right after deploy = pod rollout, not an error.
