# CRM Codebase Audit — erp-admin (2026-07-28)

## State Matrix

| Feature (App) | Data Source | APIs Layer | DTO Type | Components | Real API? |
|--------------|-------------|------------|----------|------------|-----------|
| Customers (sale) | localStorage | apis/customers.ts (mock) | App-local CustomerListItemDto | CustomerListTable, CustomerFormModal, AgentTransferModal | ❌ |
| Orders (sale) | localStorage | apis/orders.ts (mock) | Shared OrderListItemDto | OrderListTable, CreateOrderDialog, OrderTimeline | ❌ |
| Dossiers (sale) | localStorage | apis/dossiers.ts (mock) | Shared DigitalSignatureDossierDto | DossierListTable, DossierCertLifecycle, DossierDocumentsSection | ❌ |
| Renewals (sale) | localStorage | apis/renewals.ts (mock) | App-local | RenewalItemCard | ❌ |
| Reports Dashboard (sale) | in-memory | apis/reports-dashboard-data.ts (static) | App-local | StatCard, ChartWidget | ❌ |
| Product Catalog (product) | localStorage ('product-catalog:mock-data') | apis/product-catalog.ts (mock) | Shared CatalogItemDto, ProductCategoryDto | ProductCatalogView, CategoryDialog, ProductCreateDialog | ❌ |
| Invoice Management (finance) | in-memory array | None (mock in DataSource hook) | App-local InvoiceRequestListItem | InvoiceRequestsTable, InvoiceRequestDetailDialog | ❌ |
| Debt Reconciliation (finance) | in-memory array | None (mock in DataSource hook) | App-local DebtReconciliationListItem | DebtReconciliationTable, DebtReconciliationSummary | ❌ |
| Salary Fund/Payroll (hr) | Real API | apis/salary-fund-management.ts | App-local | SalaryFundManagementView, PayrollPeriodDetailView | ✅ |
| Employees (hr) | Real API | apis/employee.ts | App-local | EmployeeListView, EmployeeDetailDialog | ✅ |

## Infrastructure Summary

- **API_ENDPOINTS**: Only HR section exists. No SALE/PRODUCT/FINANCE sections.
- **API client**: `apiClient` from `@hilo/shared` used by HR features.
- **Pattern reference**: `apps/hr/src/features/salary-fund-management/apis/` + `hooks/`.
- **Shared types**: Packages/shared has DTOs for Order, Dossier, InvoiceRequest, DebtReconciliation, Product.

## DTO Compatibility

| Feature | Severity | Issues |
|---------|----------|--------|
| Customers | ✅ None | App-local types, self-consistent. Will need mapping to API response. |
| Orders | ✅ None | Uses shared OrderListItemDto, OrderDetailDto directly. |
| Dossiers | ✅ Minor | DossierListItemDto is a flattened projection of shared DigitalSignatureDossierDto. |
| Products | ✅ None | Uses shared CatalogItemDto, ProductCategoryDto, TaxRateDto. |
| Invoice | ⚠️ Medium | `requestCode` → `code`, `taxCode` → `taxId`, status enums differ (lowercase vs uppercase). |
| Debt | ⚠️ Major | Flat vs nested (`target` object), field names differ (`debtCode`→`code`, `customerName`→`target.name`), number vs decimal string. |

## Mock Storage Keys

| Feature | Key |
|---------|-----|
| Sale Customers | `getCustomersFromStorage()` → shared mock-storage (localStorage) |
| Sale Orders | `getOrdersFromStorage()` → shared mock-storage |
| Sale Dossiers | `getDossiersFromStorage()` → shared mock-storage |
| Product Catalog | `'product-catalog:mock-data'` → localStorage |
| Finance Invoice | `mockInvoiceRequests[]` → in-memory |
| Finance Debt | `mockDebtReconciliationItems[]` → in-memory |

## HR Reference Pattern

```
apis/salary-fund-management.ts
  └── uses apiClient.get/post/patch/delete
  └── uses API_ENDPOINTS.HR.*
  └── uses buildSharedListQueryRequest + omitEmptySearchParam
  └── returns ApiResponse<T>

hooks/useSalaryFundQueries.ts
  └── SALARY_FUND_QUERY_KEYS root
  └── useQuery with enabled guard (organizationId)
  └── useMutation with queryClient.invalidateQueries
```
