# Requests feature UI store + memoization (issue #153, 2026-08-06)

User decision: adopt zustand for feature-local transient UI state in erp-admin (first feature:
`apps/employee` requests overview), paired with `React.memo` on table components.

## Store shape (`features/requests/stores/requests-ui-store.ts`)

```ts
export const useRequestsUiStore = create<RequestsUiStore>()((set) => ({
  filterOpen: false, quickCreateOpen: false,
  detailDialogOpen: false, selectedRequestId: null, approvalDetailRequest: null,
  editDialogOpen: false, deleteDialogOpen: false, pendingDeleteRequest: null,
  cancelDialogOpen: false, pendingCancelRequest: null,
  decisionMode: null, decisionRequest: null,
  // actions: openFilter/closeFilter/setFilterOpen, openQuickCreate/closeQuickCreate,
  // openDetailView/openApprovalDetailView/closeDetailView, openEditView/closeEditView,
  // openDeleteConfirm/closeDeleteConfirm, openCancelConfirm/closeCancelConfirm,
  // openDecision/closeDecision
}));
```

- v5 curried `create<T>()((set) => ...)` for correct TS inference.
- Actions are plain `set({...})` — stable references, safe to select atomically.
- URL-backed state (page/pageSize/q/dates/type/status) deliberately NOT in the store.

## How components consume it

- Tables (`RequestsTable`, `ApprovalInboxTable`, `HandledRequestsTable`) and the shared
  `RequestsTableShell` read `filterOpen`/`setFilterOpen` directly from the store —
  **no `filterOpen`/`onFilterOpenChange` props anymore** (they existed for one intermediate
  step, then were removed when the store landed).
- `RequestsOverview` reads dialog slices + actions with one atomic selector each and renders
  the dialogs; all `useState` removed from it.
- Tab switch: `handleTabChange` calls `closeFilter()` + `setStatus(value)`.

## Memoization layer

- `export const X = memo(XComponent)` on: `RequestsTableShell`, `RequestsTable`,
  `ApprovalInboxTable`, `HandledRequestsTable`.
- `filterValues` memoized in Overview: `useMemo(() => ({ q, fromDate, toDate, type }), [...])`.
- Handlers passed to tables are `useCallback` over store actions
  (`handleApprove = useCallback((r) => openDecision('approve', r), [openDecision])`).
- `onApplyFilters={setFilters}` passed directly (no inline arrow).
- Result: dialog/filter toggles re-render only Overview + store subscribers; tables skip.
  URL changes still re-render everything — unavoidable and correct (see useUrlState pitfall
  in SKILL.md).

## Tests

- `stores/requests-ui-store.test.ts`: `beforeEach` resets all slices via
  `useRequestsUiStore.setState({ ... })`, then asserts open/close per dialog group with
  `toMatchObject`.
- Table tests dropped the removed `filterOpen`/`onFilterOpenChange` props.

## Verification evidence (2026-08-06)

`tsc -b` PASS · vitest 66/66 (`src/features/requests src/shared/apis`) · eslint 0 errors
(4 pre-existing warnings in `RegistrationInfoSection.test.tsx`) · vite build PASS —
run via node_modules binaries (pnpm shim dead in Hermes git-bash, see SKILL.md).
