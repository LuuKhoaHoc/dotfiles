---
name: connect-mock-to-api
description: Migrate frontend features from mock data to real APIs.
---

# Connect Mock Features to Real API

Guide for migrating browser-based mock data (localStorage, in-memory arrays) to real backend API calls using the established `apis/` → `hooks/` → UI pattern.

## When to Use

- A frontend feature uses mock data (detectable by `localStorage`, `getFromStorage`, `mock...` imports)
- Backend API endpoints exist (or are being built)
- Another feature in the same codebase already uses real APIs and serves as reference
- User says "connect API", "thay mock bằng real API", "implement API integration"

## Audit Phase

Before writing any code, run a comprehensive audit (use `delegate_task` for large codebases):

### 1. State Matrix

Per feature, record:

| Aspect | What to check |
|--------|---------------|
| **Data source** | localStorage key, in-memory array, or mock file path |
| **APIs layer** | Does `apis/{feature}.ts` exist? Does it use mock or `apiClient`? |
| **Hooks** | Do hooks call `apis/` functions directly? Do they use `useMemo` inline filter? |
| **DTO types** | App-local types or shared `@hilo/shared` types? |
| **Components** | What renders the data? DataTable, Dialog, Tabs? |
| **Mock storage** | Storage key name, seed data file, fallback functions |

### 2. DTO Compatibility

Compare current DTO fields against the API contract:

- Field names: `code` vs `requestCode`, `taxId` vs `taxCode`
- Enum values: `PENDING` vs `pending`, `APPROVED` vs `approved`
- Structure: flat vs nested (`target: {type, id, name}`)
- Types: `number` vs `decimal string`
- ⚠️ Flag any mismatch as a migration task

### 3. Reference Pattern

Find an existing feature using real APIs (e.g. HR salary-fund-management) and note:

- `apis/{feature}.ts` — uses `apiClient.get/post/patch/delete` with `API_ENDPOINTS`
- `hooks/use{Feature}Queries.ts` — query keys + `useQuery` + `enabled` guard
- `hooks/use{Feature}Mutations.ts` — `useMutation` + query invalidation
- URL state pattern — `useUrlState` schema

## Migration Strategy

```
Phase 1 — Infrastructure (Shared Package)
  ├── Add SALE/PRODUCT/FINANCE sections to API_ENDPOINTS
  └── Export needed types from @hilo/shared index.ts

Phase 2 — Per-Feature Connect
  ├── Create/rewrite apis/{feature}.ts with apiClient calls
  ├── Add VITE_USE_MOCK_API env flag (optional)
  ├── Update hooks → call real API instead of mock
  ├── Align DTOs with API contract
  └── Refactor DataSource hooks → React Query

Phase 3 — Cleanup (after stable)
  └── Delete mock-data.ts, storage helpers, VITE_USE_MOCK_API flag
```

### Per-Feature File Structure

```
features/{feature}/
├── apis/
│   └── {feature}.ts          # Dumb HTTP: apiClient calls, NO useQuery
├── types/
│   └── {feature}.types.ts    # Narrow DTOs per use case
├── hooks/
│   ├── use{Feature}Queries.ts  # Query keys + useQuery wrappers
│   ├── use{Feature}Mutations.ts # useMutation + cache invalidation
│   └── use{Feature}UrlState.ts  # URL state (existing, keep)
├── components/                 # Existing UI, refactor to call hooks
├── constants/                  # Existing, keep
├── mocks/                      # Optional fallback during migration
└── index.ts                    # Public API
```

### API Functions Pattern (reference)

```typescript
// apis/{feature}.ts
import { API_ENDPOINTS, apiClient, type ApiResponse, buildSharedListQueryRequest, omitEmptySearchParam } from '@hilo/shared';

export async function fetchItems(params: ListParams): Promise<ApiResponse<PaginatedData<ItemDto>>> {
  const response = await apiClient.get<ApiResponse<PaginatedData<ItemDto>>>(
    API_ENDPOINTS.SALE.ITEMS,
    { params: omitEmptySearchParam(buildSharedListQueryRequest(params)) },
  );
  return response.data;
}
```

### Hook Pattern (reference)

```typescript
// hooks/use{Feature}Queries.ts
export const FEATURE_QUERY_KEYS = {
  root: ['sale', 'feature'] as const,
  lists: () => [...FEATURE_QUERY_KEYS.root, 'list'] as const,
  list: (params: ListParams) => [...FEATURE_QUERY_KEYS.lists(), params] as const,
  details: () => [...FEATURE_QUERY_KEYS.root, 'detail'] as const,
  detail: (id: string) => [...FEATURE_QUERY_KEYS.details(), id] as const,
};

export function useFeatureListQuery(params: ListParams) {
  const orgId = useAuthStore((s) => s.user?.organizationId);
  return useQuery({
    queryKey: FEATURE_QUERY_KEYS.list({ ...params, orgId }),
    queryFn: () => fetchItems(params),
    enabled: !!orgId,
  });
}
```

## Mock Fallback Strategy

During migration, keep mock data as optional fallback:

```typescript
const USE_MOCK = import.meta.env.VITE_USE_MOCK_API === 'true';

export async function getItems(params) {
  if (USE_MOCK) return getItemsMock(params);
  return apiClient.get(...);
}
```

This allows:
- Parallel development (FE works on mock while BE builds API)
- Gradual per-function migration
- Easy rollback if API issues arise

## DTO Alignment Checklist

After audit, verify for each migrated feature:

- [ ] Field names match API contract exactly
- [ ] Enum values match (case, spelling, set of values)
- [ ] Nested structure matches (target object, line items array)
- [ ] Data types match (number vs string, Date vs ISO string)
- [ ] Pagination params match (page/pageSize vs page/limit)
- [ ] Error handling matches ApiResponse envelope

## Pitfalls

- ❌ Don't put `useQuery`/`useMutation` in `apis/` files — keep them dumb
- ❌ Don't reshape DTO in hook `select` — render directly from DTO in components
- ❌ Don't create adapter/mapper layers — components render DTO fields directly
- ❌ Don't force migrate all features at once — use VITE_USE_MOCK_API flag
- ✅ Always add toast on mutation success/error (per project convention)
- ✅ Verify `pnpm --filter {app} build` and typecheck after migration