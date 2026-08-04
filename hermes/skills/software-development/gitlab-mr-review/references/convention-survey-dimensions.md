# Convention Survey Dimensions

> Reference for `gitlab-mr-review` section 6 — Convention Alignment Check.
> Dimension definitions, common drift patterns, and reporting templates.

## Dimension Reference

### Dimension 1: DTO Alignment with Shared Types

Compare the MR's feature-local DTOs field-by-field against `packages/shared/src/types/*.types.ts`.

| Rating | Meaning | Example |
|--------|---------|---------|
| ✅ Aligned | Same field names, same types, same enum values | `id: string` → same in shared |
| ⚠️ Minor drift | Different field name but same semantics, or flattened vs nested | `requestCode` → `code`, `taxCode` → `taxId` |
| 🔴 Major drift | Different enum values, type change (string↔number), structural change (flat↔nested) | status `'exported'|'draft'` → `'PENDING'|'ISSUED'` |

**When drift is intentional:** If the MR's DTO matches the real backend API and the shared types are outdated, flag it as "shared types need updating" rather than "MR misaligned."

### Dimension 2: API Layer Separation

| Requirement | Wrong | Right |
|-------------|-------|-------|
| `apis/` functions are dumb HTTP only | `useQuery` inside `apis/invoice-requests.ts` | `apis/invoice-requests.ts` calls `apiClient.get/post`, returns `response.data` |
| React Query lives in `hooks/` | Mutation logic in component | `hooks/useFeatureQueries.ts` with `useQuery`/`useMutation` |
| Endpoints from `API_ENDPOINTS` | Hardcoded URL `'/crm/finance/invoice-requests'` | `API_ENDPOINTS.FINANCE.INVOICE_REQUESTS` |

### Dimension 3: URL State Pattern

Verify the MR uses the standard URL state hook:

```typescript
// Expected pattern — from @hilo/shared
const schema = createSharedListUrlStateSchema({
  status: z.enum(STATUSES).optional().catch(undefined),
  // ...
});
const { state, setState } = useUrlState(schema);
```

**Anti-patterns:**
- Manual `useSearchParams` parsing
- Filter state only in React state (lost on refresh/back)
- No Zod schema with `.catch()` for malformed URL params

### Dimension 4: i18n Key Naming (Flatten Convention)

Verify keys follow the AGENTS.md flatten convention:

| Surface | Convention Example | Anti-pattern |
|---------|-------------------|--------------|
| Field label | `invoiceRequest.code` | `features.invoices.fields.code` |
| Enum value | `invoiceRequest.status.PENDING` | `invoiceRequest.status.pending` (lowercase) |
| Action label | `invoiceRequest.actions.approve` | `features.invoices.actions.approve` (namespace mismatch) |
| Table header | Same key as field label | Different key per surface |

### Dimension 5: 4 UI States

Every async data consumer must handle all four:

| State | Implementation | Common Mistakes |
|-------|---------------|-----------------|
| **Idle/Empty** | `emptyMessage` prop on DataTable, or EmptyView component | No empty state at all |
| **Loading** | `isLoading` → Skeleton for list, Spinner for action | Using `isFetching` instead of `isLoading`, no skeleton |
| **Success** | Render directly from DTO | Creating adapter/mapper for display |
| **Error** | Error card + Retry button calling `refetch()` | Only toast.error, no screen-level recovery |

### Dimension 6: Mock Removal Completeness

When an MR migrates from mock to real API, check:

- [ ] Old `mocks/` folder deleted
- [ ] `use{Feature}DataSource` pattern removed (client-side mock filter in useMemo)
- [ ] `apis/` folder created with real HTTP functions
- [ ] React Query hooks created with query keys + cache invalidation
- [ ] Loading/error states actually connected to query (not hardcoded `isLoading: false`)

### Dimension 7: Canonical List Wiring (DataSource vs 3-Layer)

> **Repo fact (erp-admin, effective 2026-07-27):** the `use*DataSource` hooks + `DataSourceResult<TRow>` pattern is **DEPRECATED**. `docs/solutions/architecture-patterns/canonical-list-wiring-pattern-2026-07-27.md` supersedes `canonical-data-source-hook-pattern-2026-05-07.md`. The canonical model is the 3-Layer flow: `apis/` (dumb, raw `ApiResponse<PaginatedData<T>>`) → `hooks/useXxxQuery` (thin, forward params, query keys) + `hooks/useXxxUrlState` (Zod schema) → page component orchestrates (extract `data?.list`/`total`, pass props to table).

**⚠️ Critical pitfall — do NOT judge by `apps/hr/AGENTS.md` alone.** It still documents the DataSource wiring as canonical ("apis/ → hooks/use*DataSource.ts → DataSourceResult<TRow>") because it was not updated when the pattern was deprecated. A reviewer following the AGENTS.md hierarchy can wrongly mark 3-layer code as "non-canonical" or wrongly accept new DataSource code. **Always cross-check `docs/solutions/architecture-patterns/`** for the newest pattern before scoring list-wiring compliance.

Evaluate:

| Item | Canonical (3-Layer) | Deprecated / anti-pattern |
|------|--------------------|---------------------------|
| `useXxxDataSource` hooks | Do not create new ones; migrate when touching the feature | Threading new params through existing DataSource hooks (extending the deprecated layer) |
| `DataSourceResult<TRow>` import | Not used in new code | Imported from `@hilo/shared` in new/changed code |
| Page layer | Page extracts `data?.list` / `data?.total` | Extra indirection layer between query and page |
| Pagination math | `computeTotalPages(totalCount, pageSize)` + `safePage(page, totalPages)` from `@hilo/shared` (`packages/shared/src/utils/pagination.ts`) | Inline `Math.max(1, Math.ceil(totalCount/pageSize))`; app-local `getPaginationRange` from `@hr/shared/utils/pagination` (duplicate) |

**Fairness nuance:** an MR that only *extends existing* DataSource hooks (no new `use*DataSource` created) is a grey area — it violates the "migrate when touching" guidance but does NOT violate the hard "do not create new DataSource hooks" rule. Score it ⚠️ and recommend migration in a separate MR, unless the MR is small enough to migrate inline. A feature still on **mock data with client-side filter/pagination** (`OFFBOARDING_RECORDS_MOCK` + `.filter` in a `useMemo`) is a separate 🔴 against the server-side/URL-state convention, distinct from the DataSource deprecation.

### Dimension 8: Feature Structure (FSD)

Expected directory layout:

```
features/{feature}/
├── apis/              # Dumb HTTP functions
├── components/        # UI components + sub-dirs (dialogs/, sections/)
├── constants/         # Feature constants, label keys, filter options
├── hooks/             # React Query hooks + URL state + columns + filters panel
├── types/             # Narrow DTOs per use case
├── mocks/             # ❌ Should not exist if connected to real API
└── index.ts           # Public API boundary (named exports only)
```

## Reporting Templates

### Summary Table

```markdown
| Category | Rating | Details |
|---|---|---|
| **AGENTS.md compliance** | ✅ Excellent | DTO-first, i18n flatten, URL state, mutation+toast, 4 UI states |
| **API layer structure** | ✅ Follows reference | Dumb HTTP in apis/, React Query in hooks/ |
| **DTO alignment** | ⚠️ Minor drift | Field names differ from shared types (intentional — shared types outdated) |
| **Mock removal** | ✅ Complete | All mock files deleted, no DataSource pattern |
| **Feature structure** | ✅ Clean | FSD with all expected directories |
| **Shared infra reuse** | ✅ Strong | apiClient, PATHS, useUrlState, formatDate, DataTable, Button |
```

### Dimension Score Key

| Score | Meaning |
|-------|---------|
| ✅ Excellent | Follows convention completely |
| ⚠️ Needs Discussion | Minor deviation that should be documented or justified |
| 🔴 Issue | Violates established convention; needs fix before merge |

## Common Drift Patterns

| Pattern | Detection | Action |
|---------|-----------|--------|
| Shared DTO outdated but MR correct | MR DTO matches real API but not `packages/shared` types | Flag shared types as needing update; MR is fine |
| Feature creates new `mocks/` alongside real API | Both `apis/` and `mocks/` folders exist | Recommend either complete migration or env-flag fallback (`USE_MOCK_API`) |
| URL state uses manual params | `useSearchParams` instead of `useUrlState` | Recommend migration to shared pattern for URL persistence |
| i18n keys follow namespace pattern instead of flatten | `features.invoices.fields.code` instead of `invoiceRequest.code` | Flag against AGENTS.md flatten convention |
| Query keys defined in apis/ file | `CUSTOMER_QUERY_KEYS` in `apis/customers.ts` | Should move to `hooks/useCustomerQueries.ts` |
