# Feature Consolidation Analysis — Comparing Sibling Features for Merge

Use this pattern when two (or more) features in the same domain overlap in scope, share dependencies, or live side by side with unclear boundaries. The goal is an objective comparison that informs a merge, split, or boundary-realignment decision — not a guess.

## Workflow

### 1. Discover Both Features

```bash
# List all features
find apps/{mfe}/src/features -maxdepth 1 -type d | sort

# Or search by domain keyword
find apps/{mfe}/src/features -type d -iname '*salary*' -o -type d -iname '*payroll*'
```

### 2. Map Each Feature's Public API

Read `index.ts` for each feature — the exported boundary reveals what the feature *claims* to own:

```typescript
// Example: salary-fund-management/index.ts
export type { SalaryFundListParams, SalaryFundListPayload }
export { fetchSalaryGrades }
export { SalaryFundManagementView }
export type { SalaryGrade }
export { createSalaryGradeDetail }
```

Key questions:
- What `View` component is exported? → This is the page-level entry.
- What types are re-exported? → These are consumed by sibling features or other MFEs.
- What utilities are exported? → Shared calculation/DTO logic.

### 3. Trace How Each Feature Is Mounted

Cross-reference through the app's `App.tsx` routes and `PATHS`:

```
packages/shared/src/constants/paths.ts   → route constants
apps/{mfe}/src/App.tsx                   → mounted routes
packages/shared/src/config/navigation.ts → sidebar/nav menu items
```

Note:
- Distinct route constants → separate pages.
- Same icon in nav config → same-level menu items (consolidation candidate).
- Different page metadata titles → separate SEO/page titles.

### 4. Build Overlap Matrix

Use `codegraph_explore` to probe each feature, then compare:

| Dimension | Feature A | Feature B |
|---|---|---|
| **Core entity** | SalaryGrade (thang lương) | ManagementGroup (nhóm lương) |
| **Primary API endpoints** | PAYROLL_TEMPLATES, PAYROLL_RUNS | PAYROLL_MANAGEMENT_GROUPS, PAYROLL_EMPLOYEES |
| **API overlap** | CRUD payroll templates | READ payroll templates for assignment |
| **Types overlap** | Defines SalaryGrade | Consumes SalaryGrade from A |
| **Hooks overlap** | useSalaryFundQueries | Separate useSalaryManagementQueries |
| **Store/Zustand** | useSalaryFundUiStore (own) | Local state in View component |
| **View modes** | salaryGrades → detail → create → payrollPeriods | payrollEmployees \| managementGroups |
| **Menu icon** | Payroll | Payroll |
| **Target user** | HR admin (cấu trúc) | HR operator (gán) |

### 5. Identify Shared Dependencies

Use `codegraph_explore` with the shared type/hook as query:

```
codegraph_explore(query="SalaryGrade type usage across features", projectPath="apps/hr")
```

Document:
- Types consumed across feature boundaries (e.g. `SalaryGrade` from A → used by B and `employees`)
- API endpoints called by both features
- Utils or formatters shared or duplicated
- Query key namespaces — do they overlap or conflict?

### 6. Analyze Consolidation Viability

For each candidate merge option, score along these axes:

| Criterion | Question |
|---|---|
| **Route continuity** | Do users naturally flow between these pages? |
| **Data coupling** | Does one feature's output (salary grade) feed the other's input (assign to employee)? |
| **Implementation coupling** | Do they share the same Zustand store, query keys, or mutation hooks? |
| **UI pattern** | Do they use the same table/view/table-option-menu patterns? |
| **State overlap** | Does a change in one (deactivate salary grade) affect visibility in the other? |
| **Team ownership** | Are they owned by the same team/developer? |
| **Module depth** | Would merging create a shallow module (lots of interface, little impl) or a deeper one? |

### 7. Propose Merge Options

Present concrete options rather than open-ended questions:

**Option A — Route-level merge (shallow):** Combine into one parent route with tabs. Each tab delegates to the existing View component. No code migration — just routing + nav consolidation.

**Option B — Code merge (deep):** Move B's features into A's (or A into B's) directory. Unify API calls, hooks, types. Requires migrating imports across `index.ts` boundaries.

**Option C — Shared infra only:** Keep two pages separate. Harvest shared dependencies (types, API helpers, query hooks) into a `shared/` directory under the feature folder or into `@hilo/shared` if 3+ consumers exist.

## React Component Decomposition After a Merge

When two features merge, their View components often grow to 800–1500+ lines. The key question is not "how many lines" but "does this file mix concerns?"

### Diagnostic: When to Split a View File

| Signal | Action |
|---|---|
| Pre-component helper functions (const/fn before `export function`) account for >30% of file | Extract to `utils/{name}.ts` |
| Style constants, color palettes, CSS print styles embedded inline | Move to `constants/{name}.ts` |
| 4+ variant render paths (e.g. CT/TV/TTS/CTV payslip) | Extract variant data builders to `utils/{name}-data.ts` |
| 200+ lines of column definitions or table config | Extract to a named config object or separate file |
| Inline sub-components at bottom of file | Keep if ≤ 10 lines and used only there; extract if reused or > 10 lines |
| Business logic intertwined with UI handlers | Extract pure functions to utils; test them independently |

### Extraction Pattern (React 19 Best Practice)

```
Before:
components/MyBigView.tsx  (1305 lines)
├── imports
├── 15x const definitions (constants, config maps)
├── 20x helper functions (data transformation, template building)
├── export function MyBigView() { ... } (650 lines of component)
└── 1x inline helper component

After:
components/MyBigView.tsx           (~650 lines — component + handlers only)
utils/my-big-utils.ts              (~500 lines — extracted helpers + constants)
├── constants (SPECIAL_TEMPLATES, EMPTY_DEFAULTS, EXCLUDED_IDS, CONFIG_MAP)
├── type aliases (SectionItem, SectionConfig, ConfigSource)
├── pure functions (buildTableName, getType, hydrate, findMatch, buildConfig)
└── formatting utils (formatAmount, formatPercent, normalize)
```

**Rules of thumb:**
- A function without JSX, hooks, or component state → belongs in `utils/`.
- A constant without component-specific context → belongs in `constants/`.
- A type used across multiple files → belongs in `types/`.
- A sub-component used only in one parent → stay in the same file (co-location wins).
- Print styles, color tokens, and layout constants → belong outside the component file.

### API File Organization

During a merge, API files are often split by their origin feature rather than by business domain. Common pitfalls:

| Mistake | Fix |
|---|---|
| Splitting into 2 files (`salary-fund.ts`+`salary-management.ts`) because they came from 2 features | Merge into 1 file per business domain (`salary.ts`) **only if** they serve the same entity (e.g. same endpoint). |
| Keeping 2 files because they serve different endpoints | **OK** — `fetchSalaryGrades` (payroll templates) and `fetchManagementGroups` (management groups) are genuinely different entities. Different files for different resources is correct. |
| Renaming exports to avoid collision instead of merging | Renaming (`fetchPayrollEmployees`→`fetchPayrollRunItems`) is a code smell. If you have to rename to import both, they should be in 1 file or have genuinely different purposes. |

**Decision tree:** Count how many distinct API endpoints each file calls. If they share 2+ endpoints, merge them. If 0-1 overlap, keep separate.

## Reviewing AI-Generated Implementation Plans

After deciding the approach, an AI may generate an implementation plan. Common issues found in real reviews:

### Checklist

- [ ] **Missing stores/state management** — Zustand stores (view mode, dialog open/close, selection state) are often overlooked. Verify the plan migrates or merges them.
- [ ] **API split vs API merge** — The plan may split files by arbitrary criteria. Check for true duplication (same endpoint, different view model) vs distinct endpoints. Only merge genuinely duplicate calls — keeping separate files for separate business domains is fine.
- [ ] **Spec files omitted** — `.spec.ts` files are frequently forgotten. Verify every migrated util/API file has a corresponding spec in the new location.
- [ ] **Tab/View architecture ambiguity** — If the merge introduces a unified View with tabs or sub-views, the plan must specify: URL-based vs store-based tab switching. URL-based is preferred for tabs + view modes so deep-linking works.
- [ ] **Locales not updated** — The plan should explicitly list which locale files change (`common.json`, `hr.json`, etc.) and whether keys are renamed or just moved.
- [ ] **Cross-feature imports not traced** — Search for old `index.ts` re-exports consumed by sibling features (e.g. `employees` importing from `salary-fund-management`). The plan must redirect these.
- [ ] **Navigation config + route constants not listed** — `paths.ts` and `navigation.ts` changes are easy to forget. Verify both old constants are removed and new ones added.
- [ ] **Monolithic View not split** — When a feature merge produces a 1500+ line View, the plan should explicitly name the sub-views to extract (e.g. `SalaryGradesListView`, `PayrollPeriodsView`, `SalaryFundConfirmDialog`).

## Post-Merge Cleanup Checklist

After the code is moved (either manually or by an AI), verify these often-missed items:

### Navigation & Routes
- [ ] `paths.ts` — old route constants removed (not just added alongside)
- [ ] `navigation.ts` — old sidebar entries removed, new single entry added
- [ ] `App.tsx` — old routes removed, new single route added
- [ ] Old page components deleted (e.g. `SalaryFundManagementPage.tsx`, `SalaryManagementPage.tsx`)

### Locales
- [ ] `common.json` — old `module.hr.features.*` keys removed, new one added
- [ ] `hr.json` (or equivalent) — old `features.salaryFundManagement.*` and `features.salaryManagement.*` merged into `features.salary.*` (both `vi` and `en`)

### i18n Key References in Components
- [ ] All `t('features.salaryFundManagement.*')` → `t('features.salary.*')`
- [ ] All `t('features.salaryManagement.*')` → `t('features.salary.*')`
- [ ] Run `grep` across the feature directory to confirm zero old references remain

### Code Cleanup
- [ ] Old feature directories deleted
- [ ] Old page files deleted
- [ ] Cross-feature imports (e.g. `employees/`) redirected to new boundary

### Cross-Feature Import Resolution
- [ ] Search across the entire app for imports from old feature paths or old public APIs
- [ ] Update each to the new unified path

### Verification
- [ ] `typecheck` passes
- [ ] `lint` clean (0 errors, pre-existing warnings OK)
- [ ] All spec files in new location — tests pass
- [ ] Build passes (if shared packages changed)
- [ ] Manual: navigation sidebar shows 1 item, page loads, tabs switch correctly

## Pitfalls

- **Don't assume feature folder names reflect actual scope.** Read `index.ts` and view components — `salary-management` might contain employee management, not salary grading.
- **Check navigation separately from routing.** A feature can have a route but no sidebar entry (sub-page) or a sidebar entry but no route (dead nav item).
- **Don't conflate API endpoint sharing with domain coupling.** Both features calling `PAYROLL_TEMPLATES` doesn't mean they should merge — one creates, the other reads.
- **Consider user flows, not just code structure.** Separate screens for different personas (HR admin vs HR operator) may justify separate features even with overlapping data.
- **Scan `AGENTS.md` local guides** — the MFE may have documented boundary rules that prohibit certain merges.
- **Locales are the most commonly skipped step.** AI agents often don't touch locale files even when restructuring features. Always verify both language files (`vi` + `en`) independently.
- **Don't accept "API merged into 1 file" as correctness.** Two API files serving genuinely different endpoints (payroll templates vs management groups) are better separate. Only merge duplicate endpoint calls.
- **Spec files don't survive file moves automatically.** You must explicitly verify every `.spec.ts` landed in the new path with a matching `vitest run` pattern.
- **Large file ≠ bad file.** A 700-line list view is fine if it's one cohesive responsibility. The problem is mixing concerns (helpers + component), not absolute line count. Diagnose by SRP, not by `wc -l`.
