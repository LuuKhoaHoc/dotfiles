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

- `MenuIcon.test.tsx` mocks `@hilo/icons` with a hardcoded 34-name `vi.hoisted` list — adding an icon import to `MenuIcon.tsx` without extending the list breaks the suite.
- Fresh worktree: shell vitest fails `Failed to resolve entry for package "@hilo/icons"` even WITH `vi.mock` — mock factory still needs the package entry; fix = `pnpm build-infra` first (same missing-dist pattern as typecheck).
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

## Multi-round re-review: develop-sync scope triage

When a re-review shows head moved AND `base_sha` changed (author merged develop or rebased — real case MR !587 round 3: base `b6e19bf7` → `6fff3e2c`), triage BEFORE reviewing the delta:

1. `git log <last-reviewed-sha>..<new-head> -- <the MR's changed file paths>` → entries must be ONLY MR commits. Any develop commit touching an MR file = sync conflict worth inspecting. Real case: raw `git log` showed ~14 develop commits (sidebar/hr/employee noise) but the path-filtered log showed exactly 2 MR commits → clean sync.
2. `git diff --stat <new-base> <new-head>` → file list must match the MR's changed-files count/scope (8 files stayed 8 files).
3. Review only the MR-only commits' diffs (`git show <commit>`); skip the develop noise entirely — the MR diff base...head is ground truth of what merges.
4. Re-check pipeline for the NEW head sha (`list_merge_request_pipelines` → status per sha), and treat a stale pipeline claim in the description ("đang chờ chạy" while the newer pipeline already shows success) as a 🟢 note, not a blocker.
