---
name: erp-admin-fe-patterns
description: "Refactor erp-admin FE list UIs: filter lift, duplication."
---

# ERP Admin FE Patterns

Patterns learned while extending list/table UIs in the erp-admin monorepo (apps/employee, apps/hr, ...). Load alongside `gitlab-mr-review` (review mechanics).

## Moving a table filter trigger to the page header (lift state)

`TableFiltersPanel` (@hilo/ui) is a **ResponsiveModal** — portal-based, NOT anchored to its trigger. The `EmployeeFilterTriggerButton` can therefore live anywhere (e.g. next to the page's primary action) without breaking the panel.

Worked example: RequestsOverview handled-request tab, 2026-08-06 (filter button moved from table toolbar into `RequestsHeader` next to "Tạo đơn").

> **Superseded (same day, user decision):** the prop-threading steps below were the intermediate
> design. The user then adopted **zustand for feature-local UI state** — the final pattern reads
> `filterOpen`/`setFilterOpen` from a feature UI store (`features/<x>/stores/<feature>-ui-store.ts`)
> directly inside the tables/shell (no `filterOpen`/`onFilterOpenChange` props), with `React.memo`
> on the table wrappers. See `erp-admin-frontend-patterns` (Zustand section) for the full pattern.
> The prop-lift steps below still apply when the feature has no store yet.

1. Lift `filterOpen` state to the page component (`RequestsOverview`).
2. Render the trigger in the header via an `actions?: ReactNode` slot on the header component (rendered before the create button).
3. Thread `filterOpen` + `onFilterOpenChange` down through every table component into the shared table shell; the shell keeps `<TableFiltersPanel>` but drops its own `useState` and the `toolbarExtra` trigger (also delete the now-dead local `activeFilterCount`).
4. Compute `activeFilterCount` at the page level from the tab-aware filter values: `(q?.trim() ? 1 : 0) + (type && type !== 'all' ? 1 : 0) + (fromDate || toDate ? 1 : 0)`. Tabs without a type filter already resolve `type = 'all'` in URL state, so one expression works for all tabs.
5. Reset `filterOpen` when the active tab changes — wrap the tab `onValueChange` handler (panel must not stay open across tab switches).
6. Update table render tests with the new required props (`filterOpen={false}`, `onFilterOpenChange={vi.fn()}`).

## Filter trigger placement — toolbarExtra is for QUICK filters only

User-confirmed rule (2026-08-10): `toolbarExtra` on DataTable must ONLY carry quick filters (Selects, search shortcuts). The button that opens `TableFiltersPanel`/`*FilterModal` belongs on the list page's **Header** (next to the primary action) — never inside `toolbarExtra`. `TableFiltersPanel` is a portal-based ResponsiveModal, so the trigger can live anywhere without breaking the panel.

Audit technique (find violations across MFEs):
- `rg -n "setFilterOpen\(true\)" apps/*/src` → every trigger site; check the enclosing JSX is a header component (rendered via an `onOpenFilter`/`onSetFilterOpen`/`onFilter` header prop), not a table's toolbar.
- `rg -n "toolbarExtra" apps/*/src` → every toolbar slot; contents must be quick filters only.
- `rg -n "FilterTriggerButton" apps/*/src` → employee MFE's shared trigger component.

Full audit inventory (correct + violating spots per MFE, 2026-08-10): `references/filter-trigger-placement-audit.md`.

## Duplication extraction threshold (user preference 2026-08-06)

Extract shared components when duplication is SUBSTANTIAL — never for trivial one-liners:

- ✅ Extract a ~50-line cell duplicated in 3 column hooks → one shared cell component (worked example: `RequestTypeTimeCell` used by `useRequestsColumns`, `useApprovalInboxColumns`, `useHandledRequestsColumns`).
- ✅ Extract a ~90% identical ~180-line table → thin wrapper (public props unchanged) + shared shell component (worked example: `RequestsTableShell` behind `ApprovalInboxTable`/`HandledRequestsTable`). Keeping the public props identical means existing table tests keep passing untouched.
- ❌ Do NOT create a component for a 1-line cell (`employeeName || '-'`) duplicated twice — user correction: "Tại sao phải tạo component RequestEmployeeCell á". Keep trivial fallback expressions inline.

Rule of thumb: extract when the duplicated block carries real logic (branching, formatting, ~10+ lines); inline when it is a trivial fallback.

## Fragile Array.find with OR fallbacks

Antipattern: `[...approvals].reverse().find((a) => a.status === status || a.decidedAt || a.decisionNote || a.decidedByName)` — the ORs make the predicate nearly always true, so it silently returns the last item even when its status differs from the final request status (wrong approver/note rendered in multi-step approval chains).

Fix — exact match first, then fall back to the latest:

```ts
const approvals = request.approvals ?? [];
const decided =
  [...approvals].reverse().find((a) => a.status === status) ?? approvals[approvals.length - 1];
```

## Verification without pnpm (Hermes terminal on Windows)

Symptom: `pnpm ...` fails with `Cannot find module 'C:\c\nvm4w\nodejs\node_modules\corepack\dist\pnpm.js'` — the nvm-windows corepack shim on PATH points at a dead node install (`corepack pnpm` from the Hermes node is also broken). The user's IDE/terminal runs pnpm fine; only the Hermes terminal shim is dead. Fix — run the repo-local binaries directly with the Hermes-bundled node (v22), which works because pnpm hoists binaries into the repo-root `node_modules/.bin`:

```bash
cd apps/<workspace>
node ../../node_modules/typescript/bin/tsc -b          # typecheck (project refs: also checks packages/* changes)
node ../../node_modules/vitest/vitest.mjs run <paths>  # e.g. src/features/requests src/shared/apis
node ../../node_modules/eslint/bin/eslint.js <paths> [--fix]
node ../../node_modules/vite/bin/vite.js build         # vite build only — run tsc -b separately first
```

**Pitfall — piping eslint masks its exit code:** `eslint ... 2>&1 | tail -2 && echo PASS` prints PASS even when eslint reported errors, because the pipeline's exit code is `tail`'s (0). After a piped run, confirm the tail output actually says `0 errors`, or run eslint unpiped to get the real exit code.

Also: always re-verify after `eslint --fix` (formatting-only edits can still be the last edit before the final green run).

## rg / search_files on this Windows host

- `search_files` (ripgrep-backed) can fail with `IO error ... cannot find the path specified` even for paths that exist (`C:\...`, `~/...`, `/c/...` forms all failed) — the tool resolves paths in a context that can't see this filesystem. Fallback: run ripgrep via terminal.
- Bare `rg` in git-bash can resolve to GNU grep (symptom: `grep: unknown option -- glob`) despite `which rg`/`type rg` showing the real binary. Use the FULL path to the WinGet-installed ripgrep binary and the long `--glob` form:

```bash
RG=/c/Users/<user>/AppData/Local/Microsoft/WinGet/Packages/BurntSushi.ripgrep*/rg
"$RG" -l "pattern" apps/ --glob '!**/node_modules/**' | sort   # -l/-n/-A work; -g short flag also breaks
```

Note: `-g '!**/node_modules/**'` was rejected; `--glob` long form works.
