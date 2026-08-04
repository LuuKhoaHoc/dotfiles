# Agent plan review — Salary merge example

Concrete review session from 2026-07-28.

## Context

**Agent**: antigravity (Gemini-powered) produced an implementation plan and executed 80% of a salary feature merge (Issue #115, erp-admin repo).

**Goal**: Merge `salary-fund-management` + `salary-management` into unified `salary/` feature.

## Gaps found during review

| Section | Issue found | Fix applied |
|---|---|---|
| stores/ | `useSalaryFundUiStore.ts` not mentioned in plan at all | Migrated to `salary/stores/useSalaryUiStore.ts` |
| paths.ts | `HR_SALARY` added but `HR_SALARY_FUND_MANAGEMENT` + `HR_SALARY_MANAGEMENT` NOT removed | Removed old constants |
| navigation.ts | Unchanged — still had 2 menu items | Replaced with 1 "Tiền lương" entry |
| locales (hr.json) | Unchanged — still had `salaryFundManagement` + `salaryManagement` keys | Migrated → `features.salary.*` in both vi & en |
| locales (common.json) | Unchanged — navigation keys still old | Replaced with `salary` key |
| SalaryView.tsx | i18n key references still `features.salaryManagement.*` | Replaced across 28 files with `features.salary.*` |
| Spec files | Plan didn't mention them but antigravity moved them | ✅ Already done |
| Big components | `CreateSalaryGradeView.tsx` (1305 lines), `PayrollEmployeeSlipView.tsx` (1163 lines) | Extracted `salary-grade-template-utils.ts`, `payroll-slip-data.ts`, `constants/payroll-slip.ts` |
| Inline hex colors | `PayrollSlipSectionCard` used raw `'#30313d'`, `'#727682'` | Replaced with `PAYSLIP_COLORS.*` constants |

## Verification results

| Check | Status |
|---|---|
| typecheck (hr-dashboard) | ✅ pass |
| lint (hr-dashboard) | ✅ 0 errors |
| test (salary/) | ✅ 48/48 |
| @hilo/shared typecheck | ✅ pass |
| @hilo/locales build | ✅ pass |

## Key insight

The agent did the structural heavy lifting correctly (file hierarchy, code migration, view splitting) but **skipped all "connection" work**: navigation wiring, path cleanup, locale migration, and cross-file import updates. These are the glue that makes the structure actually work.
