---
name: codebase-reconnaissance
description: "Use for systematic monorepo analysis and migration planning."
tags: [codebase-analysis, dto-compatibility, migration-planning, monorepo]
category: software-development
---

# Codebase Reconnaissance — Systematic Monorepo Analysis

Use when exploring an unfamiliar monorepo (especially micro-frontend or ERP-class) to understand its architecture, assess mock-to-real-API readiness, identify DTO mismatches, and produce an actionable migration plan.

## Workflow

### 1. Topology Discovery (start here)

```bash
# Show apps + packages
find apps -maxdepth 2 -type d | sort
find packages -maxdepth 2 -type d | sort

# Root guides
cat package.json    # scripts, workspace config
cat turbo.json       # pipeline
cat pnpm-workspace.yaml
cat CLAUDE.md CONTEXT.md AGENTS.md 2>/dev/null
```

**Check for local AGENTS.md** in every app/package you enter — the repo's own guidance system. Root guide overridden by local, best wins.

### 2. Shared Infrastructure — Read FIRST

Before diving into any app, read the shared package layer:

```
packages/shared/src/
├── api/
│   ├── index.ts            # exports
│   ├── axios.ts            # apiClient, interceptors, token refresh
│   ├── endpoints.ts        # API_ENDPOINTS — all backend URLs
│   ├── query-keys.ts       # QUERY_KEYS — TanStack Query cache contracts
│   └── list.ts             # normalizeApiCollectionData
├── constants/
│   ├── paths.ts            # PATHS — route constants (single source of truth)
│   ├── common.ts           # ALL_SENTINEL, DEFAULT_LIST_VIEW_PAGE_SIZE
│   └── ...                 # domain constants (roles, statuses, enums)
├── config/
│   └── navigation.ts       # APP_MODULES — MFE registry + feature catalog
├── types/
│   ├── api.ts              # ApiResponse<T>, ApiPagination
│   ├── data-source.ts      # DataSourceResult<T>
│   └── *.types.ts          # Shared domain DTOs (finance, order, product)
├── schemas/
│   └── list-query.ts       # createSharedListUrlStateSchema, buildSharedListQueryRequest, omitEmptySearchParam
├── hooks/
│   └── useUrlState.ts      # URL state hook pattern
├── constants/              # domain constants (roles, statuses, enums)
└── index.ts                # Public package API
```

Key contracts to capture:
- `ApiResponse<T>` shape: `{ success, data, error, meta }`
- Query key conventions (nested tuples)
- URL state schema pattern (Zod + `createSharedListUrlStateSchema`)
- Pagination helpers (`buildSharedListQueryRequest`, `omitEmptySearchParam`)

### 3. Per-App Feature Analysis

For each app, read each feature's **types → apis → hooks → components → pages** in that order:

```typescript
// Feature structure expected (Feature-Sliced / co-located):
features/{feature}/
├── types/{feature}.types.ts      // Narrow DTOs per use case
├── apis/{feature}.ts             // Dumb HTTP calls (NO useQuery)
├── hooks/
│   ├── use{Feature}Queries.ts    // TanStack Query wrappers
│   ├── use{Feature}Mutations.ts  // TanStack Mutation wrappers
│   └── use{Feature}UrlState.ts   // URL state hook (Zod schema)
├── index.ts                      // Public API boundary
```

#### DTO Compatibility Check (critical)

For every feature, compare its DTO fields against `packages/shared/src/types/*.types.ts`:

| Check | What to look for |
|---|---|
| Aligned | Same field names, same types |
| Minor mismatch | Different field name (`requestCode` vs `code`), flattened vs nested |
| Major mismatch | Different enum values, string vs number, flat vs nested objects |

Record findings in a compatibility matrix. This determines migration effort.

#### API Readiness Assessment

| Pattern | Status | Action |
|---|---|---|
| Mock (localStorage) | Not connected | Needs `apis/` layer + endpoint in `API_ENDPOINTS` |
| Mock (in-memory array) | Not connected | Needs `apis/` layer + endpoint |
| Real API (`apiClient.get/post`) | Connected | Reference pattern for other features |
| Missing `apis/` folder entirely | Needs creation | Create `apis/` then `hooks/` then `components/` pipeline |

#### Calculation Boundary Analysis

When the target of analysis is a **numerical or time-based calculation** (working days, grace period, overtime minutes, late/early penalties) rather than general feature structure, use this additional pattern after reading types → apis → hooks → mappers → UI:

1. **Identify every DTO field** that relates to the calculation across all MFEs and shared packages.
2. **Trace each field** through the full pipeline: API response → hook → mapper → UI. Note whether the mapper does a 1:1 passthrough, a simple parse (`toNumber()`), a unit conversion (`minutesToHours()`), or a complex derivation.
3. **Look for recalculation triggers**: API endpoints named `refresh`, `recalc`, `reprocess` that initiate server-side recalculation when called.
4. **Search for configuration**: Policy/rules features that send tolerances (grace minutes, thresholds, toggles) to the server for application.
5. **Identify display-only helpers**: Functions like `formatMinutesAsText()` or `formatWorkHours()` that only wrap server-provided values in labels — not calculation logic.
6. **Run targeted tests** at each boundary to confirm the responsibility split.

See `references/cross-mfe-calculation-trace.md` for the full workflow with a worked example from an attendance/timesheet analysis across HR, Employee, and shared packages.

### 4. Route & Navigation Gap Analysis

Cross-reference 3 sources:

1. **`PATHS`** in `packages/shared/src/constants/paths.ts` — all route constants
2. **`APP_MODULES`** in `packages/shared/src/config/navigation.ts` — MFE + feature definitions
3. **App route files** (`apps/{name}/src/App.tsx` or `pages/`) — actually mounted routes

Gaps to flag:
- PATHS defined but **no page component** exists (ComingSoon pages)
- Navigation feature defined in `APP_MODULES.features[]` but **no route** mounted
- Routes mounted but **no PATHS constant** (hardcoded inline)
- Detail routes without separate PATHS (e.g. `/customers/:id` using same PATHS)

### 5. Compile Report to `docs/solutions/`

Per repo convention (if AGENTS.md says to), write findings to `docs/solutions/{topic}.md` with:

- **A. Current State Matrix** — app x feature table (Status, Components, Hooks, Pages, APIs Pattern, Notes)
- **B. DTO Compatibility Matrix** — field-level comparison per feature
- **C. API Connect Pattern Recommendation** — reference implementation (HR real API) + per-feature plan
- **D. Mock Data Migration Strategy** — storage keys, fallback pattern (`VITE_USE_MOCK_API`)
- **E. Route & Navigation Gaps** — PATHS vs routes vs actual pages
- **F. New UI Requirements** — reusable components, page patterns, URL state templates

### 6. Mock to Real API Transition Pattern

```typescript
// Recommended: env-gated fallback
const USE_MOCK = import.meta.env.VITE_USE_MOCK_API === 'true';

export async function getFeatureListApi(params: ParamsDto) {
  if (USE_MOCK) {
    return getFeatureListApiMock(params);
  }
  const response = await apiClient.get<ApiResponse<PaginatedData<ItemDto>>>(
    API_ENDPOINTS.MODULE.FEATURE,
    { params: omitEmptySearchParam(buildSharedListQueryRequest(params)) },
  );
  return response.data;
}
```

### Cross-MFE Endpoint & DTO-Sharing Audit

Use when the user asks whether an MFE consumes another domain/MFE's endpoints through the correct shared interface (`API_ENDPOINTS` from `@hilo/shared`) and whether response DTOs are shared cross-MFE or duplicated locally. See `references/cross-mfe-endpoint-dto-audit.md` for the recipe: namespace-usage counts, export-chain verification, BE OpenAPI (`/openapi.yaml` — the `/docs` page is a Scalar HTML shell) path/param/schema comparison, dead-type detection (exported with 0 consumers), enum-VALUE diffs (not just field names), and the `*Id`-field-must-be-combobox form-UX corollary.

### Feature Consolidation Analysis

When comparing two or more features in the same domain for potential merge, split, or boundary realignment, see `references/feature-consolidation-analysis.md`. Covers: mapping public APIs, tracing routes, building an overlap matrix, analyzing shared dependencies, and scoring merge options.

## Post-Migration Verification

After a subagent or tool has completed a merge/refactor, follow `references/post-migration-verification.md` for the systematic cleanup pass. Covers: dead reference scan, locale migration, component-level extraction, tab UI consistency, and the full typecheck/test/lint gate.

## Doc ↔ Codebase Reconciliation (AGENTS.md / docs sync)

Use when the task is: "update/correct AGENTS.md (or any doc) so it matches the real codebase." This is the inverse of feature-deployment-verification: instead of checking a claimed feature exists, you check every *specific claim in the doc* (commands, paths, folder/component names, namespaces, ports, remotes, versions) against the source-of-truth config, then patch ONLY the stale/wrong claims with clear evidence. See `references/docs-codebase-reconciliation.md` for the full workflow, the erp-admin source-of-truth cheat-sheet (claim type → where to verify), the hard rules, and the worked 2026-07-31 findings.

## Feature Deployment Verification

Use when a stakeholder (BA/PO/PM) provides a list of features claimed to be deployed on a specific environment (UAT/staging). Systematically verify each claim against the actual codebase on the deployment branch.

### Workflow

#### 1. Parse the Claim List

Group the claims by codebase area, separating FE and BE concerns:

```markdown
**FE:** salary (payslip, salary period, salary grade), attendance (tab removal), dashboard v2, directory, time-off format, i18n
**BE:** payroll calc (OT, tax, net pay), timesheet working days, org structure aggregation, attendance grace period
```

#### 2. Map Claims to Files

For each claim, identify the exact files that would contain the implementation. Use this erp-admin monorepo cheat-sheet:

| Claim Area | Likely files to check |
|------------|----------------------|
| Payroll/payslip display | `apps/hr/src/features/salary/components/payroll-runs/PayrollEmployeeSlipView.tsx` |
| Salary period columns | `apps/hr/src/features/salary/components/payroll-runs/PayrollPeriodDetailView.tsx` |
| Salary grade tabs→dropdown | `apps/hr/src/features/salary/components/salary-grades/CreateSalaryGradeView.tsx` |
| Attendance tab removal | `apps/hr/src/features/attendances/components/AttendanceTabs.tsx` |
| Employee directory | `apps/employee/src/features/directory/` |
| Time-off format | `apps/employee/src/features/time-off-management/` |
| Dashboard v2 | `apps/hr/src/features/dashboard/` |
| Organization structure | `apps/hr/src/features/organizations/` |
| Attendance grace period | `apps/employee/src/features/attendance/apis/` + `apps/hr/src/features/attendances/` |
| i18n / Vietnamese labels | Search locale JSON files and `t('...')` calls in relevant components |

**Monorepo app-to-feature mapping (erp-admin):**

| App | Features | BE-ref |
|-----|----------|--------|
| `apps/hr` | salary, attendances, dashboard, employees, organizations, insurance-tax | Payroll calc, timesheet, org |
| `apps/employee` | directory, time-off, attendance, dashboard (self-service) | Leave balance, check-in |
| `apps/finance` | debt-reconciliation, invoice-requests | Finance |
| `apps/sale` | customers, orders, renewals, reports-dashboard | Sales |
| `apps/product` | product-catalog | Catalog |
| `apps/shell` | login, profile, attendance-confirmation | Auth |

#### 3. Deploy Orchestrator Subagents

For each category, dispatch orchestrator agents with:

```python
delegate_task(tasks=[
    {
        "goal": "Specific verification goal (e.g. Check payslip OT mapping)",
        "context": f"""
Files to check:
- {file_path_1}
- {file_path_2}

Checklist:
1. {specific claim 1 to verify}
2. {specific claim 2 to verify}

Evidence required: file path + line numbers + code snippet for each finding.
If something is NOT implemented or wrong, say so clearly.
"""
    },
])
```

**Guidelines for task splitting:**
- **Group closely related claims** into one subagent (e.g. all payslip claims in one task)
- **Separate independent areas** into different tasks (e.g. salary period ≠ salary grade)
- **Keep each subagent focused** — 3–5 claims max per task
- **Always provide concrete file paths** — don't make the subagent guess where to look
- For claims about **calc/transform logic** (OT, tax, net pay), include the `apis/`, `hooks/`, and `utils/` dirs too, not just `components/`
- **Role = "orchestrator"** when a subagent needs to delegate further (e.g. split within a group)
- **Role = "leaf"** when the subagent just reads files and reports

#### 4. Aggregate Results

Combine evidence from all subagents into a structured report. To extract subagent conclusions from delegation logs, use the helper script:

```bash
python ~/.hermes/skills/software-development/codebase-reconnaissance/scripts/read-delegation-summary.py <delegation_id>
# Or view all:
python ~/.hermes/skills/software-development/codebase-reconnaissance/scripts/read-delegation-summary.py --all
```

This reads the `final | summary=` line from each task's live transcript and prints it — no need to manually `tail -f` the log files.

Report format:

```markdown
### Area: {name}

#### Confirmed Features
| Feature | Status | Evidence |
|---------|--------|----------|
| {feature name} | ✅ Done | {file}:{line} — {snippet} |

#### Issues Found
| Feature | Issue | Location |
|---------|-------|----------|
| {feature name} | ❌ Not implemented / Wrong / Partial | {file}:{line} |

#### Items That Could Not Be Verified (BE-only, external API)
| Feature | Reason |
|---------|--------|
| {feature name} | Logic lives on backend API only |
```

#### 5. Cross-Reference Findings with Issue Tracker

After subagents complete, cross-reference **every issue found** against the project's issue tracker (GitLab, Jira, etc.):

```python
# For each claimed-deployed feature that is MISSING or WRONG in code:
# 1. Fetch the relevant issue(s) via API
# 2. Compare: is the missing feature already tracked?
# 3. Decide action:
#    - Already tracked in an open issue → note that the issue needs attention (claim "deployed" was wrong)
#    - Not tracked at all → create a new issue or add a task to an existing umbrella issue
#    - Claimed as deployed but pending in issue → update acceptance criteria
```

**Common scenarios and actions:**

| Scenario | Action |
|----------|--------|
| Feature missing from code, tracked in open issue | Update issue — note "claimed deployed but code not found" |
| Feature missing from code, NOT tracked | Create new issue with findings as evidence |
| Feature partially implemented, tracked | Add acceptance-criteria gap to existing issue |
| Feature partially implemented, not tracked | Create new issue or update existing one |
| BE-only claim can't be verified | Flag in issue as "needs BE verification" |

Use `mcp__gitlab__get_issue` or direct REST API to read issues. When updating, prefer `update_issue_description_patch` for focused edits.

#### 6. Handle BE-Only Claims

In a FE-only monorepo (like erp-admin), many "BE" claims cannot be verified from frontend code:
- **API call exists** → partially verified (FE expects this endpoint)
- **Display/processing logic exists** → verified that FE handles the result
- **No FE code at all** → flag as "Cannot verify — BE-only logic"

### Evidence Quality Standards

| Claim status | Minimum evidence |
|-------------|-----------------|
| ✅ Confirmed | file path + line number(s) + 3–5 line code snippet showing the feature |
| ⚠️ Partial | Explain what's there vs what's missing |
| ❌ Not found | Show search queries attempted and results |
| 🔍 Unsure | Explain why it can't be determined from FE code alone |

### References

- `references/feature-deployment-verification.md` — full worked example from this session's erp-admin UAT check
- `references/async-job-notification-pattern.md` — async job trigger → loading toast → WebSocket notification → data refresh pattern with cleanup and fallback timeout (extracted from HR payroll period recalculation)

## List-View Filter Standardization Audit

Use when the task is "tìm list view nào có / chưa có / lệch chuẩn filter" — standardize list filters to a canonical component across MFEs. Dispatches parallel leaf subagents (1 per MFE; split the biggest MFE into two tasks) with a STANDARD / CUSTOM / NONE / SUB classification and file:line evidence, then consolidates findings into one linked issue per MFE. See `references/list-view-filter-audit.md` for the full dispatch template, the erp-admin canonical filter component (`TableFiltersPanel` in `@hilo/ui`), classification rules, and the ticket-creation flow.

## Feature Performance Pattern Audit

Use when the goal is to evaluate loading states, async job handling, batch processing, and optimization patterns within a feature (not just architecture discovery).

### Audit Checklist

For each feature, walk this pipeline in order:

**a. API Layer** (`apis/`)
- Examine every endpoint signature — does it support batch operations or only single-ID?
- Look for async/job endpoints (POST that returns immediately, no blocking) vs synchronous endpoints
- Check if the endpoint path hints at async processing (e.g. `/calculate`, `/export`, `/send`)

**b. Mutation Hooks** (`hooks/use*Mutation.ts`)
- Does the `onSuccess`/`onError` handler check `response.success` or status before cache invalidation? (optimization: skip invalidation on failure)
- Are cache invalidations batched via `Promise.all` or sequential?
- Is there a loading state exposed for the UI (`isPending`)?
- Are toasts fired at the hook layer or component layer? (Convention: component layer)

**c. Query Hooks** (`hooks/use*Query.ts`)
- Are queries **conditionally enabled** (only when dialog/panel is open)?
- Is `useDebouncedSearch` or similar used for filter inputs to prevent excessive API calls?
- Is there a `staleTime` or `refetchOnMount` that could improve freshness vs performance?

**d. Component Loading UX** (`components/`)
- Identify every async trigger button (Calculate, Export, Send, Recalculate)
  - Does it show a **loading toast** (with `duration: Infinity`) during the operation?
  - Does it have a **fallback timeout** in case the async notification doesn't arrive?
  - Does it **dismiss the loading toast** and refresh data on completion (success or failure)?
  - Is there cleanup on unmount (clearTimeout, removeEventListener)?
- For list views: skeleton rows (`TableLoadingRows` or `ListViewSkeleton`) vs no loading state
- For table data: is there an `isLoading` guard that prevents empty-state flash?

**e. Notification / WebSocket Infrastructure**
- Does the feature use **CustomEvent-based browser notifications** (`dispatchNotificationBrowserEvent` / `hilo:notification`)?
- What event types are listened for? (e.g. `PAYROLL_RUN_CALCULATION_SUCCEEDED`, `PAYROLL_RUN_CALCULATION_FAILED`)
- Is there a singleton WebSocket manager with reconnect, dedup, and ACK?
- How does the component subscribe/unsubscribe? (`addEventListener` + cleanup)

**f. Git History Scan**
- Check recent commits touching the feature's files for performance-related messages:
  ```bash
  git log --all --oneline --grep="optimize\|perf\|nhanh\|batch\|async\|recalculat\|notification.*payroll\|loading\|debounce" -- <feature-dir>
  ```
- Look for commits that changed loading states, added notification handling, or introduced debounce/throttle
- Read the full diff of relevant commits to understand the before/after

**g. Batch Operations**
- Does the feature allow **selecting multiple items** (checkboxes, select-all)?
- Is there a batch endpoint to act on multiple IDs at once?
- Does the UI guard batch operations with proper checks? (e.g. "finalize required before send")

### Reference

See `references/async-job-notification-pattern.md` for the concrete pattern of async job trigger → loading toast → WebSocket notification → data refresh, with cleanup and fallback timeout.

## Verification

- Confirm the report covers all apps/packages in the monorepo
- Confirm DTO compatibility matrix is exhaustive per feature
- Confirm route gap analysis cross-references all 3 sources (PATHS, APP_MODULES, route files)
- Check `docs/solutions/` already exists in repo before writing

## Bridge to Implementation

After verification, findings often feed directly into implementation. The typical flow is:

```
Verify codebase against claims → cross-ref with issue tracker → create/update issue → plan → implement in phases
```

When verification uncovers a gap (a claimed-deployed feature that doesn't exist), the correct sequence is:

1. **Report finding** with file evidence showing the gap
2. **Cross-reference with issue tracker** (see section 5 above)
3. **Update issue** — note the gap, add new tasks if needed
4. **Create implementation plan** using the `implementation-plan` skill
5. **Implement** using the `implementation-runner` skill — work in **phases** (e.g. Phase 1: UI cleanup, Phase 2: search/filter, Phase 3: verify done items)
6. **Verify each phase** with typecheck, lint, and targeted tests before moving on

Each implementation phase should produce a clean diff: remove dead code + clean imports + clean locale in one pass, not scattered across multiple commits.

## Pitfalls

- Reading features before shared infra: you need `API_ENDPOINTS`, `PATHS`, `ApiResponse`, and URL state patterns first to evaluate everything else
- Treating mock types as gospel: mock types often differ from shared DTOs. Always cross-reference with `packages/shared/src/types/`
- Skipping AGENTS.md files: the monorepo itself documents conventions, anti-patterns, and verification commands inside AGENTS.md. Read them
- One-size DTO analysis: distinguish narrow-list DTOs from detail DTOs. A feature may have `ListItemDto` (flattened projection) and `DetailDto` (full object) — both need checking
- Claiming "no api/ folder" as broken: some repos deliberately delay creating `apis/` until backend contracts are stable. Note it as "needs creation" when API is ready
- **Missing the notification layer** when auditing async operations — the API POST may return instantly while the real work completes via WebSocket. Always check for CustomEvent listeners and notification infrastructure alongside the API call
- **Treating a single loading state as sufficient** — async jobs need multiple states (trigger loading, in-progress toast, notification listener, fallback timeout, success/error handler, cleanup on unmount). A single `isLoading` boolean is not enough
- **Trusting feature claims without verification** — a feature listed as "deployed" may not actually exist in code. Always search the actual codebase, don't assume the claim is correct
- **Missing subagent results after dispatch** — delegation results arrive asynchronously and are appended to the conversation. After dispatching, check for completed results immediately rather than waiting silently. Read live transcripts or find the `final | summary=` line in task logs to extract subagent conclusions
- **Skipping locale files when verifying i18n** — Vietnamese text changes may live in `packages/locales/` not in the component. Always search both components AND locale JSON files for text changes
- **Using sed for locale JSON manipulation** — sed is too aggressive: it affects ALL matching lines, not just the target section, and leaves trailing commas that break JSON syntax. Always use Python's `json.dump()` for structural changes (load → modify dict → dump) or the terminal's `json_del` helper for single-key removal. Verify with `python -m json.tool <file>` after every edit
