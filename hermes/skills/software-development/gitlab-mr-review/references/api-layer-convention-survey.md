# API-Layer Convention Survey — "Is this apis/ file dumb?"

Real case: MR !512 (`feat(product): connect product catalog to CRM API`) — `apps/product/src/features/product-catalog/apis/product-catalog.ts` ballooned to 791 lines of mappers + business logic + self-built error handling while the repo convention is ~10-15 lines per dumb HTTP function. The MR passed two prior review rounds without anyone flagging it.

## The reference pattern (HR, apps/hr/src/features/employees/apis/employee.ts)

```typescript
export async function getEmployeeDetail(id: string): Promise<ApiResponse<EmployeeDetailDto>> {
  const response = await apiClient.get<ApiResponse<EmployeeDetailDto>>(API_ENDPOINTS.HR.EMPLOYEES_BY_ID(id));
  return response.data;
}
```

Dumb = ONE call, return `response.data`. No try/catch, no mapping, no extra fetches, no fabricated responses. List endpoints use `buildSharedListQueryRequest` + `omitEmptySearchParam` from `@hilo/shared`. Error display uses `getApiErrorDisplayMessage` (`packages/shared/src/utils/form-errors.ts`).

## Dimension checklist — score each ✅/⚠️/🔴 with file:line

| # | Dimension | Violation smell (from product-catalog.ts case) |
|---|---|---|
| 1 | **No transforms in apis/** | `normalizeRateValue`, `normalizeNumberValue`, `parseTaxRatePercentage`, `normalizeDurationToFormValue`, `buildTaxRateOption`, `mapUiServiceTypeToCrmFields` (AGENTS.md: "Không transform trong apis/") |
| 2 | **No UI-model intermediate DTO** | `CatalogItemDto` with `sv`/`pkg`/`saleStatus`/`variant:'standard'` — a display model mapped from `CrmProductDto` (AGENTS.md: "Cấm adapter/mapper/toXUi/toXView/toXModel", "không tạo UI model trung gian") |
| 3 | **No business orchestration in apis/** | `syncDefaultCategoryTaxRate` (multi-step write: fetch all assignments → PUT unset default → PUT/POST set default), `buildProductPayload` (form→payload mapping with preserve logic) |
| 4 | **No self-built error system** | `parseApiError`/`buildErrorResponse`/`buildFallbackMeta` + try/catch on EVERY function → errors swallowed as `{success:false,data:null}` → `isError` never fires → ErrorState dead code → silent empty tables (see §9 "Error-swallowing API layer") |
| 5 | **No hardcoded user-facing strings** | `'Không thể tạo sản phẩm'` etc. inside apis/ — i18n violation + business strings in HTTP layer |
| 6 | **Reuse shared list-query helpers** | Custom `fetchAllPages`/`resolveTotalPages`/`resolveProductList` (handles 3 response shapes array/items/data — defensive coding for an unknown contract) instead of `buildSharedListQueryRequest` + server-side pagination |
| 7 | **No extra round-trips** | create/update category re-fetches ALL tax rates + ALL assignments to map the response; update/toggle product fetches detail first + pulls price history on every mutation response (N+1-ish churn per save) |
| 8 | **No duplicate logic across layers** | `normalizeDurationForForm` duplicated in `useProductCatalogCrud.ts:32` AND `apis/product-catalog.ts:121` — same normalization in 2 layers with different names = mapping sprawl symptom |
| 9 | **Dead files removed** | `mocks/product-catalog.mock.ts` left behind with 0 importers after mock→API migration (`git grep -rn "product-catalog.mock"` excluding the file itself = 0 hits) |
| 10 | **Query keys placement** | ⚠️ NOTE: `PRODUCT_CATALOG_QUERY_KEYS` in apis/ looks wrong but HR does the same (`EMPLOYEE_QUERY_KEYS` in `apis/employee.ts`) — **established pattern, NOT a violation**. Verify against the reference app before flagging (false-positive class, same as the i18n namespace-prefix case). |

## Survey workflow

1. Read root AGENTS.md "API functions: dumb" + "DTO-first display" + "Cấm layer mapping" sections.
2. Read `docs/solutions/architecture-patterns/shared-next-code-api-layer-2026-05-19.md` (dumb API + hook-with-select pattern) — and check `docs/solutions/erp-crm-connect-api-plan.md` when the MR is a mock→API migration (the plan names HR as reference).
3. Grep the shared helpers the MR SHOULD have imported but didn't: `getApiErrorDisplayMessage`, `buildSharedListQueryRequest`, `omitEmptySearchParam` — 0 hits in the feature = reuse failure.
4. Read the full apis/ file (these are the biggest files in the diff — budget for it), enumerate helper functions per dimension.
5. Cross-check each candidate violation against the HR reference implementation before flagging (query keys, QUERY_KEYS import, `pageSize: 1000` params blocks are all legitimate HR patterns).

## Verdict framing

A file this far off convention is a 🔴 "re-architecture" finding, not a nitpick list: propose the target shape (dumb apis + narrow DTOs + hooks with select + server pagination), name the HR reference files to copy from, and offer to split into a follow-up ticket if the MR is otherwise mergeable.
