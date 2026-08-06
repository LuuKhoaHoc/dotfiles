---
name: hr-salary-grade-patterns
description: HR MFE salary-grade/payroll-template patterns.
triggers:
  - editing CreateSalaryGradeView or salary grade section templates
  - changing salary calculations (applyCalculatedAmounts) or formula notes
  - adding/removing sections or rows in salary grade templates
  - intern/probation/collaborator salary template specifics
---

# HR Salary Grade & Payroll Template Patterns

Salary grade create/edit flow in `apps/hr/src/features/salary`. Templates = **sections** (cards) of **rows** (salary components); calculated rows are recomputed by one engine and annotated with i18n formula notes.

## Where things live

| File | Role |
|---|---|
| `components/salary-grades/CreateSalaryGradeView.tsx` | Page: template-type select, renders section cards, submit → `buildPayrollTemplateConfig` |
| `components/salary-grades/create-salary-grade/` | `SalaryGeneralInformationCard`, `SalarySectionCard`, `SortableSalarySectionCard` |
| `utils/create-salary-grade-sections.ts` | **Per-type section factories + `applyCalculatedAmounts` calc engine** (spec: `create-salary-grade-sections.spec.ts`) |
| `utils/salary-grade-template-utils.ts` | `createSectionsByTemplateType`, `hydrateSectionsFromPayrollTemplate`, `buildPayrollTemplateConfig`, `getTemplateType` |
| `utils/salary-grade-{row,section}-order.ts` | localStorage order persistence (`hr.salaryFundManagement.createSalaryGrade.*`) |
| `types/create-salary-grade.ts`, `types/salary-fund.ts` | `SalaryComponentSection`/`Row`, `SalaryGradeTemplateType` = `official`/`intern`/`probation`/`collaborator` |
| `packages/locales/src/translations/{en,vi}/hr.json` | `features.salary.create.*` incl. `sections`, `rows`, `formulaNotes` |

## Core model

- Row: `{ id, name, code, displayName, amount, percent, quantity, amountMode, type?, ... }` — `amountMode`: `'editable'` (user input) | `'calculated'` (engine overwrites `amount` + sets `helperText`). `type`: `'day' | 'month'` (allowance rows; daily amounts × working days).
- Section/row ids are stable strings (`SALARY_SECTION_IDS`: `gross-agreed-salary`, `tax-free-allowance`, `final-net-salary`…; rows: `gross-1`, `policy-allowance-total`, `final-net-salary-1`…) — row ids are the `calculatedAmounts` keys.

## Calc engine: `applyCalculatedAmounts(sections, salaryGrade, t, { syncSalaryGradeDefaults, templateType })`

Two branches: simplified (`intern`/`probation`/`collaborator`: gross + editable tax-free allowances + flat 10% PIT ≥ 5,000,000 + welfare + final net) vs full `official` (insurance, P1/P2/P3, progressive PIT, OT, welfare).

- Returns a NEW sections array — the View wraps every edit in `setSections(current => applyCalculatedAmounts(current, …))`.
- Only `amountMode === 'calculated'` rows get `calculatedAmounts[rowId]` written to `amount`.
- `formatSalaryAmount` = vi-VN dot thousands (`'2.200.000'`); spec assertions use these formatted strings.

## Hide a section: omit from the factory, NOT a View conditional

The View renders the pinned `gross-agreed-salary` card only if `sections.find(id === SALARY_SECTION_IDS.agreedSalary)` exists. Dropping the section from `createInternInitialSections` etc. auto-hides the card, empties the payload items (`getSectionItems` → `[]`), and makes hydration skip old saved configs gracefully.

## Formula notes (helperText)

- `translateCreate(t, 'formulaNotes.<key>', {...})`, rendered under the amount input (`whitespace-pre-line`).
- New keys go into **both** `en/hr.json` and `vi/hr.json`; verify parity with `scripts/check-locale-parity.py` (run from repo root; optional dotted subtree arg, e.g. `features.salary.create.formulaNotes`).
- Prefer template-specific keys (`internAllowanceTotal`, `internFinalNetSalary`) over mutating shared ones (`taxFreeAllowance`, `finalNetSalary`) used by the official branch.

## Pitfalls

- No `if (templateType === 'intern')` in the View for hiding — factory omission only.
- `sumEditableTaxFreeAllowances` = raw daily sum; intern monthly total needs type-aware sum (`day` × `STANDARD_WORK_DAYS_PER_MONTH` = 22, `month` × 1). `addRow` defaults new allowance rows to `type: 'day'`.
- Section/row order is shared localStorage across template types; loaders only reorder existing ids, so removals are safe.
- `INTERN_DAILY_*` constants are hardcoded intern defaults; official/probation values come from the grade scale + `SALARY_GRADE_CONFIG`.
- **Percent precision drift (helperText ≠ input)**: `formatPercentAmount` caps at 2 decimals (`maximumFractionDigits: 2`) — 66.375% renders as `"66,38"`. The calc engine re-derives `insuranceSalaryRate` from the percent STRING (`parseDecimalInput(row.percent)`), so formula-note tooltips can disagree with the amount field. Real case: gross 8.000.000 + amount 5.310.000 (true rate 66.375%) → percent derives to `"66,38"` → note recomputes 8.000.000 × 66.38% = 5.310.400 ≠ input 5.310.000. The note and the input derive from DIFFERENT sources of truth (percent string vs. stored amount); the amount is only overwritten when empty or on grade-default sync (`!row.amount` / `syncSalaryGradeDefaults` guard at the end of `applyCalculatedAmounts`). Diagnose any tooltip/input mismatch by checking which string the note interpolates (`calculatedHelpers[rowId]`) and whether the row's `amountMode` lets the input diverge.
- **`insurance-salary-1` (official) is a hybrid row**: `amountMode: 'editable'` + `percentMode: 'editable'` — the amount IS user-editable even though tooltip copy `tooltips.socialInsuranceSalaryPercent` claims "Số tiền được tự động tính và không sửa trực tiếp". Editing the amount re-derives percent via `formatPercentAmount` (2-decimal cap) in the View's `updateRow` — that's the precision-loss entry point. Fix directions if it bites: derive the note's amount from the stored row amount, raise percent precision, or make the amount read-only to match the copy.
- `roundCurrency` (in `salary-grade-calculation.ts`) is plain `Math.round` — integer rounding only, NO nearest-thousand; 5.310.400 stays 5.310.400.

## Editing checklist

1. Row/section shape → the `createXxxInitialSections` factory for that type.
2. Calculation → matching branch in `applyCalculatedAmounts` (`calculatedAmounts`/`calculatedHelpers`).
3. Display text → `formulaNotes` keys in vi + en.
4. Update `create-salary-grade-sections.spec.ts` (formatted-string expectations).
5. Verify: `pnpm --filter hr-dashboard exec vitest run src/features/salary`; `pnpm --filter hr-dashboard typecheck`; `pnpm exec eslint <files>`; `pnpm exec prettier --write <files>`; `python3 -m json.tool` both hr.json.

## References

- `references/intern-template.md` — intern template rules (current state): no gross section, daily allowance × 22 working days, final net = allowance total.
