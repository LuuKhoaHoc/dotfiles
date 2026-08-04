# Salary grade builder — component map & session notes

## Section IDs

`SALARY_SECTION_IDS` (in `create-salary-grade-sections.ts`):

| Constant | id string |
|---|---|
| `agreedSalary` | `gross-agreed-salary` |
| `socialInsuranceSalary` | `social-insurance-salary` |
| `employeeContribution` | `employee-contribution` |
| `companyContribution` | `company-contribution` |
| `taxFreeAllowance` | `tax-free-allowance` |
| `dependentDeduction` | `dependent-deduction` |
| `competencyBonus` | `competency-bonus` |
| `performanceBonus` | `performance-bonus` |
| `welfare` | `welfare` |
| `overtime` | `overtime` |
| `internPersonalIncomeTax` | `intern-personal-income-tax` |

Other section ids (not in the constant): `income-after-insurance`, `taxable-income`, `progressive-tax`, `final-net-salary`.

## Key row ids

- `gross-1` — agreed salary amount (percent field for probation rate)
- `insurance-salary-1` — social insurance salary: amount + percent, official template only
- `policy-allowance-total` — calculated Σ of tax-free allowances (excluded from payload via `PAYROLL_TEMPLATE_EXCLUDED_ROW_IDS`)
- `intern-tax-1` — flat 10% PIT for intern/probation/collaborator
- `final-net-salary-1` — THUC_NHAN_CUOI_CUNG
- `welfare-1` / `welfare-2` — editable welfare rows
- `dependent-rate` / `dependent-1` / `dependent-total`
- `tax-1`..`tax-5` / `tax-total` / `income-after-tax-1` / `taxable-income-1`
- `allowance-1`..`allowance-8` map to `SALARY_GRADE_ALLOWANCE_ROW_KEYS` (housing, transportation, phone, meal, parking, internetDevice, uniform, otherPolicy)

## Constants (module-private in create-salary-grade-sections.ts)

- `STANDARD_WORK_DAYS_PER_MONTH = 22`, `STANDARD_WORK_HOURS_PER_DAY = 8`
- `INTERN_DAILY_MEAL_ALLOWANCE = 50_000`, `INTERN_DAILY_TRANSPORT_ALLOWANCE = 50_000`
- `PROBATION_DEFAULT_RATE = 85`
- `NON_OFFICIAL_PIT_THRESHOLD = 5_000_000`, `NON_OFFICIAL_PIT_RATE = 10`
- PIT brackets 5/10/20/30/35% (`PERSONAL_INCOME_TAX_BRACKET_RANGES`)

## Intern branch calculation (applyCalculatedAmounts, templateType 'intern')

- `grossSalary` = 0 (no gross-agreed-salary section anymore)
- `dailyAllowanceTotal` = Σ editable allowance rows (per-day values)
- `taxFreeAllowance` = Σ editable rows × (type === 'month' ? 1 : 22) — `sumEditableMonthlyTaxFreeAllowances`
- `incomeBeforeTax` = taxFreeAllowance; PIT = 10% if ≥ 5M else 0
- `finalNetSalary` = `taxFreeAllowance` (NOT income − tax + welfare — welfare dropped from intern final net per product decision)
- Default display: (50.000 + 50.000) × 22 = 2.200.000, PIT 0, final 2.200.000
- Intern helpers use keys `formulaNotes.internAllowanceTotal` (params dailyAmount/workDays/amount) and `formulaNotes.internFinalNetSalary` (params allowanceTotal/amount); welfare rows get NO helper for intern (generic welfare text says "added to final net", which is false for intern)

## Official insurance sync (implemented this session, refined by user)

- `createInitialSections`: `insurance-salary-1` `amountMode: 'editable'` (was `'calculated'`), `percentMode: 'editable'`. SalarySectionCard renders amount input editable iff `amountMode === 'editable'`.
- `applyCalculatedAmounts` official branch (current guards — user-refined):
  - percent presence = `insuranceSalaryRow.percent !== ''` (NOT `> 0` — 0% is valid → amount 0)
  - `derivedInsuranceSalaryRate = sync ? min(100, gradeRate) : hasPercent ? min(100, max(0, parse(percent))) : gross>0 && amount>0 ? min(100, amount/gross*100) : 0` — no grade-default fallback when percent empty (rate 0 instead)
  - rows.map: `if (row.id === 'insurance-salary-1' && (syncSalaryGradeDefaults || !row.amount) && grossSalary > 0) nextRow.amount = ...` — user-typed amount PRESERVED (gross edits no longer overwrite it once amount is set)
- `CreateSalaryGradeView.updateRow` (event layer — knows which field was edited):
  - field `'percent'` → `clampedRateNum = min(100, max(0, rate))`; `nextAmount = formatSalaryAmount(roundCurrency(gross × clampedRateNum / 100))` when gross > 0; `valueToSet` clamps input > 100 → `'100'` (displayed value)
  - field `'amount'` → `nextAmount = formatEditableAmountValue(value)`; `nextPercent = clamp(amount/gross × 100)` when gross > 0 and amount > 0, `'0'` when amountNum === 0, else `''`
  - spread override only for field `'amount'`: `...(isSocialInsuranceSalaryRow && field === 'amount' ? { percent: nextPercent } : {})` — otherwise the percent edit gets reverted
  - gross read from `current` sections (agreedSalary → gross-1) via `Number(normalizeAmountValue(amount || '0'))`
- Tests added: amount from percent (8.500.000 @ 85%), percent from amount, 0% → amount 0, >100% input capped.
- Rounding: percent stored with 2-decimal display convention; amount → percent → amount round-trip can drift by ~hundreds VND at 10M gross (exact for round values). Accepted.

## Intern payload: agreedSalary = FE net salary

- `buildPayrollTemplateConfig` special-cases `templateType === 'intern'`: `agreedSalary.items = getSectionItems(sections, 'final-net-salary', templateType)` — the FE-computed net salary row (`final-net-salary-1`, code `THUC_NHAN_CUOI_CUNG`, amount e.g. `'2200000'`) is sent as the agreed salary because the UI no longer has a gross section but `getTemplateAgreedSalary`/payroll engine still read `agreedSalary.items[0].amount`.
- Test: `'sends the FE-calculated intern net salary as the agreed salary config'` in `salary-grade-template-utils.spec.ts` (needs `createInternInitialSections` + `applyCalculatedAmounts` with `{ templateType: 'intern' }` first).

## Payload / hydration notes

- `buildPayrollTemplateConfig` always emits an `agreedSalary` section — for intern it carries the FE-computed net salary items (see "Intern payload" below), for other templates the gross section items (empty `items: []` when the section has no rows).
- `getSectionItems` filters `PAYROLL_TEMPLATE_EXCLUDED_ROW_IDS` and rows without values; rate = percent/100.
- `hydrateSectionsFromPayrollTemplate` maps config items to rows by code; unmatched config items become new rows via `createRowFromTemplateItem`.
- `CONFIG_SECTION_BY_SECTION_ID` maps section id → config key (`agreedSalary`, `insuranceSalary`, `taxExemptAllowances`, `internPit`, `benefits`, `ot`, `dependents`, `p2Bonus`, `p3Bonus`).
- `getTemplateAgreedSalary` reads config `agreedSalary.items[0].amount` (returns 0 when items empty → grade matching falls back to candidate codes).
