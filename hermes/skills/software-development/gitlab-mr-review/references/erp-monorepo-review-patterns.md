# ERP Admin Monorepo Review Patterns

> Project: `vppos-team/erp-admin` (GitLab project_id: 9)
> Stack: pnpm + Turbo monorepo, Next.js, Micro-Frontends (Shell + HR + Employee + Sale + Finance)

## Branch Structure

- `develop` — integration branch, target for feature MRs
- `feat/*` — feature branches (naming: `feat/<module>-<short-description>`)
- `fix/*`, `refactor/*`, `release/*`, `feature/*`

## Review Verification (by workspace)

| Package | Workspace name | Test command | Typecheck command |
|---|---|---|---|
| Shared UI lib | `@hilo/ui` | `pnpm --filter @hilo/ui exec vitest run <test-file>` | `pnpm --filter @hilo/ui typecheck` |
| HR dashboard feature | `hr-dashboard` | `pnpm --filter hr-dashboard exec vitest run src/features/dashboard` | `pnpm --filter hr-dashboard typecheck` |
| HR app | `hr` | `pnpm --filter hr typecheck` | same |
| Locales | `@hilo/locales` | — | `pnpm --filter @hilo/locales typecheck` |

Full workspace names (verify from `packages/*/package.json` `name` field before running):
- `@hilo/ui` — `packages/ui`
- `@hilo/shared` — `packages/shared`
- `@hilo/icons` — `packages/icons`
- `@hilo/locales` — `packages/locales`
- `@hilo/tokens` — `packages/tokens`
- `@hilo/config` — `packages/config`
- `hr-dashboard` — `apps/hr` (the HR MFE dashboard sub-feature)
- `hr` — `apps/hr`
- `employee` — `apps/employee`
- `shell` — `apps/shell`
- `sale` — `apps/sale`
- `finance` — `apps/finance`

## Git Hooks (Lefthook)

- `pre-commit`: `pnpm dlx lint-staged` (eslint --fix + prettier --write on staged files)
- `commit-msg`: `pnpm dlx commitlint --edit {1}` (enforces conventional commits)
- `pre-push`: `pnpm -r --parallel run typecheck` (typechecks ALL workspace packages)

Commit message types allowed: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.

## EmptyView Component Pattern

### Icon Rendering Quirk
`EmptyView` wraps icon in a `bg-muted-foreground` container. The SVG gets `text-muted-foreground` by inheritance → invisible against same-color background.

**Fix:** EmptyView must handle icon contrast internally — use `[&_svg]:text-white` on the wrapper div instead of relying on consumers to add `text-white` to their icon className.

**Checklist when EmptyView icons are involved:**
- [ ] Does the icon inherit `text-muted-foreground` from the wrapper?
- [ ] If yes, is the icon color overridden (e.g. `text-white`, `text-current`)?
- [ ] Better approach: fix in EmptyView itself, not in each consumer.

## DateRangePicker Patterns

### Epoch Fallback
When the user clears the "from" date but keeps a "to" date, the component sets `from = new Date(1970, 0, 1)` (epoch start). This is paired with a `MIN_DASHBOARD_FROM_DATE = '1970-01-01'` string constant in the HR dashboard's `dashboard-request-params.ts`.

**Label states** (when `isEpochFrom === true`):
- `from` + `to` → "Đến dd/MM/yyyy" (hides epoch from, only shows to)
- `from` only → "Toàn bộ"
- `from` cleared via toolbar → resets `from` to epoch if `to` is still set

### Toolbar Header
Added in MR !505: a selection summary bar inside the popover showing:
- "Thời gian đã chọn:" title
- Individual "Từ:" / "Đến:" date badges with per-field clear buttons
- "Xóa tất cả" button that resets the entire range and moves calendar to current month

## Dashboard Data Contract

Cards are grouped into 3 groups: `EMPLOYEE`, `REQUEST`, `ATTENDANCE`.

Card group affects:
- Which column set renders in the detail list (employee/request/attendance columns)
- Whether `dateType` filter is shown (only REQUEST group cards)
- Available sort options

Card keys were renamed from legacy (e.g. `newHires` → `newEmployees`, `approvedRequests` → `requestStatus`). Legacy aliases (`CARD_KEY_ALIAS`) have been removed — assume backend contract matches the new keys.
