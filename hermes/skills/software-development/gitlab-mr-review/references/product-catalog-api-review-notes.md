# Product Catalog → CRM API review (MR 512)

Findings from reviewing the local-checkout diff of `feat(product): connect product catalog to CRM API`
(merge-base `2e576316`, tip `3fd33d04`, 18 files). Focus: API migration of `apps/product` product-catalog to `/crm/*` endpoints.

## Mechanics used (local-checkout review)

- `git diff --stat <merge-base> <tip>` + `git diff --name-only` to scope, then read full files (not just hunks).
- **Dead-code proof = repo-wide consumer grep**, not assumption:
  - `grep -rn "product-catalog.mock\|PRODUCT_PACKAGE_ROWS\|PRODUCT_CATEGORY_ROWS\|PRODUCT_ANALYTICS"` → the 334-line `mocks/product-catalog.mock.ts` is imported by NOTHING (only self-references). Fully dead.
  - Same grep for `productAnalytics`/`customTaxRates` in the app → computed in `getProductCatalogApi` but no UI reads them.
  - Confirm a "maybe-dead" hook is actually consumed before flagging: `useProductMutations.ts` / `useProductCategoryMutations.ts` ARE both used by `useProductCatalogCrud.ts` → NOT dead.
- **Verify endpoint removals against consumers**: `grep -rn "TAX_RATES_BY_ID\|PRICE_HISTORY_BY_ID"` → only definitions/tests; stale `packages/shared/dist/` hits don't count.

## Durable findings (class-level, promoted to §9)

- Read-modify-write status toggle (`toggleProductSellingApi`: GET detail → PUT full object) — race + fails if GET fails.
- Dialog collects fields the API payload drops (`ProductTaxRateDialog` code/description vs `createTaxRateApi` sending only name/percentage).
- Aggregate `isMutating` computed in crud hook but never passed to dialog Save button → double-submit duplicates.
- Derived-readonly required field blocks the flow (`createForm.taxRate` derived read-only from category; validation `!createForm.taxRate`).

## Session-specific detail (lower reuse value — keep here, not in SKILL.md)

- **Hardcoded Vietnamese fallback strings** in `apis/product-catalog.ts` at lines 529, 571, 613, 627, 679, 704, 735, 749, 776, 788 (e.g. `parseApiError(error, 'Không thể tạo sản phẩm')`). These surface directly via `toast.error(response.error?.message || ...)` in the crud hook — i18n violation; return a code and let the caller map to `t()`.
- **`PRODUCT_CATALOG_QUERY_KEYS` defined in `apis/`** (line 462) instead of `hooks/` — convention violation (no React Query keys in apis/).
- **`normalizeRateValue`** (line 79-86): ternary with two identical branches (`Number.isInteger ? String(v) : String(v)`) — dead code.
- **`fetchAllPages` silent truncation** (lines 299-327, 349-353): if the paged response object has no `meta.pagination`/`pagination`/`total` and itemCount ≥ pageSize, `resolveTotalPages` returns `undefined` → `?? page` stops at the current page → a list with >100 items is silently truncated. Also: exact-multiple-of-100 totals trigger one extra empty request.
- **create/update category refetch entire tables** to build a 1-category response: `syncDefaultCategoryTaxRate` (fetchAllCategoryTaxRates) + create/update re-fetch `fetchAllTaxRates()` + `fetchAllCategoryTaxRates()` (lines 550-562, 592-604). Heavy N+1-style waste.
- **`updateProductApi` fetches detail (GET) before PUT** (line 688) purely to preserve `durationDays`/`targetType`; plus `buildProductResponse` (line 643) fetches price history after every create/update/toggle/detail → extra requests on mutations.
- **`priceAfterTax` computed from `createForm.taxRate` but displayed tax is `createForm.taxRate || category.taxRate`** (ProductCreateDialog 71-74 vs 328) → mismatch when `createForm.taxRate` is empty.
- **Detail modal fallback during load**: `product={productDetailQuery.data?.data ?? viewingProduct}` (View 641) but `priceHistoryRows` reads only `productDetailQuery.data` → "price changes" count shows 0 while loading, then jumps.
- **Tax rate edit round-trip is fine** (opposite of the hardcoded-defaults trap): `openProductEditor` reads `duration` from `normalizeDurationForForm(product.durationDays)`, `quantity` from `product.totalQuota`, etc. — no hardcoded defaults clobbering. (Positive confirmation of the round-trip check.)
- i18n: `viewDetail`, `deleteTitle`, `deleteDescription`, `productDeleted` keys added to BOTH en and vi — parity OK. Vi-only nav key rename (`salary`→`salary_fund_management`) flagged as out-of-scope parity concern.

## Round 3 outcome (2026-07-31, head `2d7283c1`) — all 5 🔴 from the Request-Changes review FIXED

One refactor commit `11118f1c refactor(product): simplify product catalog api...` (+ develop merge) answered the 5-🔴 architecture review. Verified at tip via scoped `git grep`:

- **Mappers/CatalogItemDto → 0 hits** repo-wide in `apps/product`; components bind `CrmProductDto`/`CrmCategoryDto` directly.
- **apis/ = 178 lines pure HTTP** (`git show <branch>:apis/product-catalog.ts | wc -l`); no try/catch, no hardcoded Vietnamese, no `fetchAllPages`/`resolveTotalPages`/`parseApiError`/`buildErrorResponse`. Business logic moved: `buildProductPayload` → `useProductCatalogCrud.ts:101`, `syncDefaultCategoryTaxRate` → renamed `syncCategoryTaxRate` in crud (still fetches all assignments at `PRODUCT_REFERENCE_PAGE_SIZE=1000` — acceptable 🟡, one call not N+1). Constants → `constants/catalog.ts`.
- **ErrorState reachable**: `catalogQuery.isError` + Retry at `ProductCatalogView.tsx:520`.
- **Server-side pagination**: `useProductCatalogFilters.ts` (`createSharedListUrlStateSchema` + `useUrlState`), `useProductCatalogQuery.ts` (`buildSharedListQueryRequest`), `DefaultPagination` footer wired with server `totalPages`/`page`.
- **Bugs**: `CrmTaxRatePayload` has `code?`/`description?`; toggle builds PUT payload from row entity (`currentProduct`) with no GET; `isMutating` → `isSubmitting` → `disabled={isSubmitting}` on both dialogs.
- **N+1 `enrichProducts` gone** — price history only fetched in `useProductDetailQuery` (lazy, `enabled: Boolean(viewingProduct)`).

Remaining 🟡 (not blockers): (1) multi-select category filter — server takes 1 `categoryId` (`length === 1 ? [0] : undefined`), rest filtered client-side on current page → range summary mismatch; (2) i18n keys still surface-nested (`productCatalog.createModal.*`, `detailModal.*`) vs flatten convention.

## Round MR !539 (2026-08-05, head `4eb8f829`) — CRM contract alignment (q→search + empty-cache fix, 4 files)

Quy's follow-up: `search` replaces `q` on product list, price history becomes paged, local `normalizePagedItems`/`resolvePagination` replace shared `normalizeApiCollectionData`, CKS fields preserved in `buildProductPayload`. Verified: typecheck + build pass at head (detached worktree: build needs workspace deps built first — `pnpm --filter product... build`), no develop conflict, no 🔴. Durable findings:

- **`resolvePagination` ignores `payload.pagination`** — local `CrmPagedListResponse<T>` (types/product-catalog.ts) declares `pagination?: ApiPagination` inside `data`, but the helper only reads top-level `total/page/pageSize`; `meta.pagination` (envelope) is checked first, then the helper. If BE returns pagination inside `data.pagination`, `totalItems` falls back to current-page length → wrong footer. Check: read `payload.pagination` before top-level fallback, or confirm BE shape.
- **Price history silently capped at pageSize 1000** — `buildProductPriceHistoryRequestParams()` = page 1 + `PRODUCT_REFERENCE_PAGE_SIZE` (1000); detail modal counts `priceHistoryRows.length` (≤1000) ignoring `totalItems`. Was unpaged before → products with >1000 price changes truncate silently.
- **New DTO nested fields unwired** — `CrmPriceHistoryDto` gained `product`/`oldTaxRate`/`newTaxRate` (BE returns them) but `ProductCatalogView.tsx` still shows the product's CURRENT `taxRate?.percentage` in every history row's tax column (`:381`) — wrong for old rows after a tax change. Pre-existing display bug, but the MR touched exactly this DTO/feature.
- **Partial search migration** — only product list moved to `search`; category list & tax-rate list builders still send `q` (`useProductCatalogQuery.ts:137,155`). If BE switched all list endpoints to `search` uniformly, those searches silently no-op. Verify BE contract per endpoint before flagging 🔴.
- **`sort`/`order`/`searchFields` added to `ProductListRequestParams`/`ProductPriceHistoryListRequestParams` but never sent** — contract-doc only, 🟢.

## MR !539 (2026-08-05, head `4eb8f829`) — align with latest CRM API contract (issue #133, author QuyCN)

Verdict: no blockers, mergeable; typecheck + build verified at head (via detached worktree, `pnpm --filter product... build`). 4 files: apis + 2 hooks + types.

- **`normalizePagedItems` covers 4 shapes** (array, `data: []`, `items: []`, `data: {data|items: []}`) — fixes the old bug where `{data: {data:[...]}}` went through `normalizeApiCollectionData`'s `Object.values` → garbage → "totalItems > 0 but table empty". The nested-shape support is what the issue's empty-cache fix actually needed.
- **search mapping done right**: local `omitEmptyProductSearchParams` trims + drops empty `search`; `q` destructured out of `buildSharedListQueryRequest` so it's never sent alongside `search`. Categories/taxRates still send `q` — if BE switched ALL list endpoints to `search`, those search paths silently no-op; verify with BE.
- **`resolvePagination` ignores `payload.pagination`** 🟡 — `CrmPagedListResponse` declares `pagination?: ApiPagination` but the helper reads only top-level `total/page/pageSize`; if BE returns pagination inside `data.pagination` (not `meta.pagination`), `totalItems` falls back to current-page length → footer shows "1/1 trang, 10 items" for a 48-item/5-page result. Read `payload.pagination` before falling back, or confirm the real shape.
- **Price history capped at pageSize=1000, page=1** 🟡 — was unpaged (full fetch) before; products with >1000 price changes are now silently truncated, and the modal counts `rows.length` instead of `totalItems`.
- **`CrmPriceHistoryDto` + `product`/`oldTaxRate`/`newTaxRate` added but unwired** 🟡 — history table still renders CURRENT `product.taxRate?.percentage` for every row (wrong for old rows after a tax change); BE now returns `oldTaxRate` — use it.
- **CKS preserve correct**: `buildProductPayload(nextForm, { currentProduct })` called with `editingProduct` (update) AND the row `product` (toggle) — 3 CKS fields survive both paths; create sends explicit `null` (out of scope, note if BE requires them on create).
