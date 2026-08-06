# Cross-MFE endpoint & DTO-sharing audit (worked example: sale MFE using finance endpoints, 2026-08-05)

Class of task: user asks "MFE A dùng endpoint của domain/MFE B — có dùng đúng interface từ packages/shared không? Response types có dùng chung cross-MFE không?"

## Recipe (all read-only, ~5 tool calls, no delegation needed)

1. **Find cross-namespace usage** (counts per namespace):
   ```bash
   grep -rhoE "API_ENDPOINTS\.[A-Z_]+" apps/<mfe>/src --include="*.ts" --include="*.tsx" | sort | uniq -c
   ```
   Worked example: sale MFE = 12× SALE, 2× FINANCE, 0× PRODUCT — PRODUCT namespace exists in shared but sale never uses it.

2. **No hardcoded URLs**: grep `/api/v1/(finance|product)`, `api-erp`, `https?://` in the MFE → expect 0 hits.

3. **Verify the export chain** — `API_ENDPOINTS` must flow: `@hilo/shared` `src/index.ts` → `export * from './api'` → `api/index.ts` → `export * from './endpoints'`. Import from package root only. Pitfall: grep for the symbol in `index.ts` can return 0 hits because it's behind `export *` barrels — follow the chain instead of concluding it's unexported.

4. **Verify path + params vs BE**: BE OpenAPI at `https://api-erp.vppos.vn/openapi.yaml` — the `/docs` page is a Scalar HTML shell (`<script data-url="/openapi.yaml">`), curl the YAML (~1.4MB). Check path prefix (`/api/v1/crm/finance/...`) and that query params the MFE sends (e.g. `customerId`) exist (`parameters: ... in: query`). Also check every path in the namespace, not just the used ones — path drift happens (shared `BANK_TRANSACTIONS` = `/finance/bank-transactions` vs BE `/api/v1/crm/finance/bank-transactions`).

5. **Type-sharing check (the real finding)**: grep `packages/shared/src/types` for the entity types, then grep the WHOLE repo for imports of those types from `@hilo/shared` → **0 consumers = dead code** (exported ≠ used; shared types rot silently). Compare shared type shape vs BE `components/schemas` — mock-era types rot hard: `ReceivableDto` was `{ c, amt, paid, out, due, st }` while BE returns `{ amount, paidAmount, outstandingAmount, dueDate, status }`.

6. **Check each MFE's local types**: same entity declared independently in 2+ MFE features = AGENTS.md violation ("❌ Không duplicate types cho cùng API entity"; correct = narrow DTOs derive from shared base via `extends`/`Pick`). Re-declared enum/status types (e.g. `InvoiceRequestStatus` copy-pasted) count as duplication too.

7. **Diff enum VALUES, not just field names**: FE `customerType` used `BUSINESS_HOUSEHOLD`/`OTHER_ORGANIZATION` while BE create accepts `ENTERPRISE, HOUSEHOLD_BUSINESS, INDIVIDUAL` — value-level mismatch = data sent wrong. Flag for curl verification in the issue.

8. **Form UX corollary (*Id fields)**: if a form must send `*Id` (uuid) fields but renders plain text `<Input>`, users cannot type UUIDs — must be `AsyncPaginatedCombobox`. Check the search endpoint exists in BE + `API_ENDPOINTS` (e.g. `HR.EMPLOYEES` supports `search`/`pageSize`/`status`), add a feature-local query hook (`enabled: !!user`) — never import from another MFE (cross-MFE deep import cấm).

## Issue-writing notes

- One issue for the whole shared-types cleanup (shared → sale → finance sequential steps): changes are DEPENDENT, not parallel — splitting per MFE creates fake blockers. Labels used: `shared, finance, sale, Refactor, frontend, priority::medium, ready-for-agent`.
- Include BE evidence in the description (schema field lists), per to-tickets format.
- The customerType enum mismatch shows up exactly in the form you're already fixing — bundle the verify-curl into the same issue rather than a separate one.
