---
name: erp-admin-frontend-patterns
description: Use when editing erp-admin FE - filter, state, verify.
---

# erp-admin Frontend Patterns

Class-level patterns for working on erp-admin (pnpm + Turbo MFE monorepo) FE code: table/filter UI, state architecture, and local verification. Covers `apps/employee` (requests/attendance), `apps/hr`, and shared `packages/ui` components. For GitLab issue/MR mechanics see `gitlab-issue-workflow` / `gitlab-issues` (user-owned — read-only).

## Verify FE changes without pnpm (Hermes git-bash)

`pnpm` shim is broken in the Hermes terminal (corepack → `C:\c\nvm4w\...\corepack\dist\pnpm.js` MODULE_NOT_FOUND; `corepack pnpm` also fails). Don't fight it — run the binaries straight from `node_modules`, from the app dir (verified 2026-08-06, issue #153):

```bash
cd apps/employee
node ../../node_modules/typescript/bin/tsc -b              # == pnpm --filter employee typecheck (checks project refs too)
node ../../node_modules/vitest/vitest.mjs run src/features/requests src/shared/apis
node ../../node_modules/eslint/bin/eslint.js src/features/requests src/shared/apis --fix
node ../../node_modules/vite/bin/vite.js build             # vite-only build; run AFTER tsc -b
```

⚠️ **`cmd 2>&1 | tail -N && echo PASS` masks eslint failures** — the pipeline's exit code is `tail`'s, not eslint's; eslint can print "N errors" while the chain still prints PASS. Run eslint unpiped, or read the `✖ N problems (M errors...)` line before reporting PASS.

Also: the `patch`/`write_file` tool's built-in linter reports bogus `TS6053 File not found` on every `.ts` file (MSYS path quirk) — labeled "Pre-existing lint errors". Ignore it; trust real `tsc -b`.

## Filter trigger placement — trigger is NOT anchored to the panel

`TableFiltersPanel` (packages/ui) is a **ResponsiveModal** — no anchor to a trigger element. The trigger button can live anywhere on the page (e.g. header next to the primary action) instead of the DataTable toolbar:

1. Lift `filterOpen` to the page (e.g. `RequestsOverview`); pass `filterOpen` + `onFilterOpenChange` into each table/shell (replaces internal `useState`).
2. Header gets an `actions?: ReactNode` slot rendered beside the primary button; page renders `EmployeeFilterTriggerButton` there, computing `activeFilterCount` from `filterValues` at page level.
3. Reset `filterOpen` on tab change (wrapper around `setStatus`) — the panel unmounts with the tab; a shared state that isn't reset reopens the old tab's panel on return.
4. Remove the trigger from DataTable `toolbarExtra`; keep `TableFiltersPanel` rendered inside the table/shell.

## Shared filter config — one source for every tab

Multiple tabs with the same filter set (search + request type + date range): don't hand-write `categories`/`sections` per table.

```ts
// features/<x>/constants/<x>-filters.ts
export const REQUEST_TYPE_FILTER_OPTIONS: readonly { value: string; labelKey: string }[] = [...];
export function getRequestsFilterCategories(t: (key: string) => string): TableFilterCategory[] { ... }
export function getRequestsFilterSections(t: (key: string) => string): TableFilterSection[] { ... }
// components: const categories = useMemo(() => getRequestsFilterCategories(t), [t]);
```

- Builders take `t` typed `(key: string) => string` (compatible with `useTranslations` t) and return `TableFilterCategory[]`/`TableFilterSection[]` from `@hilo/ui`.
- A tab missing a section (e.g. requestType select) → add it to the shared builder, don't copy code; add per-tab URL state keys (e.g. `approvalType`/`handledType` mirroring `myType`) + `requestType` in the params memo + `setFilters`.
- Lock the contract with a small unit test: `categories[0].sectionIds == sections.map(s => s.id)`, option values unique.

## KISS — when NOT to extract a cell component

User correction 2026-08-06 (requests feature, "tại sao phải tạo component RequestEmployeeCell"): don't create a component file for a one-line cell (`employeeName || '-'` duplicated twice). Extract only when duplication is substantial (a ~50-line typeAndTime cell repeated 3× → `RequestTypeTimeCell` is worth it). Rule of thumb: lines × copies — 1-line × 2 = inline; 50-line × 3 = extract.

## Zustand — ADOPTED for feature-local UI state (user decision 2026-08-06)

Zustand (`^5.0.11`, already a dep) was previously restricted to global app state (`packages/shared/src/{auth,theme,websocket}`). **User overrode that decision** ("khởi nguyên cho việc dùng zustand global state quản lý UI state trong dự án hiện tại"): feature-local **transient UI state now goes in a feature zustand store** — `features/<x>/stores/<feature>-ui-store.ts`, `create<Store>()((set) => ...)` (v5 curried form). Worked example: `features/requests/stores/requests-ui-store.ts` (filter-panel open + all dialog states), issue #153.

Hard boundaries that still hold:
- **URL-backed list/filter/search state stays in the URL** (`useRequestsUrlState`). NEVER mirror it into the store — two sources of truth → sync bugs, deep-link/back break. The store owns only state that must not live in the URL (dialogs, panel open, pending request objects).
- Store actions are stable references → **select atomically** (`useStore((s) => s.action)` per slice); don't destructure whole state.
- **Pair the store with `React.memo` on table wrappers + shared shells** (`function XComponent(...)` + `export const X = memo(XComponent)`). That combo is what stops re-renders: a dialog/filter toggle re-renders only store subscribers; memoized tables skip.
- **Pitfall — `useUrlState.setState` is NOT referentially stable** (`packages/shared/src/hooks/useUrlState.ts`: `useCallback` deps include `state`). Page callbacks derived from it (`setPage`, `setFilters`, …) get a new identity on every URL change → memo does NOT skip URL-driven re-renders (fine and necessary — data derives from the URL). Memo's win is the non-URL UI-state path (dialog/filter toggles). Do NOT "fix" useUrlState by dropping `state` from its deps — it's a shared cross-workspace hook.
- Memoize `filterValues` objects at the page (`useMemo`) and pass stable `useCallback` handlers; inline arrow props (`onApplyFilters={(f) => ...}`) defeat memo — pass the stable hook function directly.
- Store tests: reset every slice in `beforeEach` via `useStore.setState({ ...all initial values... })`.

## Feature flow may already be half-built — grep before implementing

Before building any request action flow (cancel/withdraw, submit, approve…): grep the feature for the API function, endpoint constant, mutation hooks, i18n keys. erp-admin often ships the transport layer + locale keys long before any UI (worked example 2026-08-06: `cancelMyOrganizationRequest` + `requests.cancel.*` + `actionMenu.cancelRequest` all existed; only the action-menu item, mutation hook, and confirm dialog were missing). Implement = wire the missing UI onto the existing contract, don't re-create it:
- Body convention for `RequestActionRequest` endpoints (`/me/requests/{id}/cancel`): send `{ id, requestId, note? }` — omit `actorEmployeeId`/`legacyId`/`legacyNote` (identity from auth context, matches approve/reject payloads).
- Cancel applies to `REQUEST_STATUS.PENDING` rows (thu hồi đơn đã gửi): add a red `actionMenu.cancelRequest` item in the columns hook next to the DRAFT block; DRAFT keeps edit/delete/submit.
- `ConfirmActionDialogType` has NO `'cancel'` variant — use `type="deactivate"` (warning-orange) for cancel/withdraw confirms.
- `useMutation` `mutationFn` with an optional second arg (e.g. `note?`) collides with React Query's `MutationFunctionContext` — wrap it: `mutationFn: ({ id, note }) => cancelMyOrganizationRequest(id, note)`.
- New confirm dialogs belong in the feature UI store (see Zustand section above), not local `useState`.

## Worked example

4-tab filter sync + filter-button relocation in `apps/employee` requests (issue #153, 2026-08-06): `references/employee-requests-filter-sync.md`. Zustand UI-store + memo layer for the same feature: `references/requests-ui-store-pattern.md`.
