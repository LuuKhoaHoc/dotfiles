# Intern template rules (current state, Aug 2026)

Result of the "hide gross for intern + allowance × working days" change. Applies to
`templateType === 'intern'` in `create-salary-grade-sections.ts`.

## Section list (order as created)

1. `tax-free-allowance` — editable rows:
   - `allowance-4` meal 50.000/day (`INTERN_DAILY_MEAL_ALLOWANCE`)
   - `allowance-2` transportation 50.000/day (`INTERN_DAILY_TRANSPORT_ALLOWANCE`)
   - `policy-allowance-total` (calculated) — `TONG_TIEN`
2. `intern-personal-income-tax` — `intern-tax-1` (calculated) — `THUE_TNCN`
3. `welfare` — `welfare-1` birthday, `welfare-2` other (editable)
4. `final-net-salary` — `final-net-salary-1` (calculated) — `THUC_NHAN_CUOI_CUNG`

**No `gross-agreed-salary` section** — removed from `createInternInitialSections`; the View
pinned-card lookup (`agreedSalarySection`) returns undefined → card hidden. Old saved intern
templates still carry `agreedSalary` items in config JSON, but hydration skips them (no
matching section id).

## Calculation rules (intern branch of `applyCalculatedAmounts`)

- `dailyAllowanceTotal` = Σ editable allowance amounts (raw daily) = 100.000 default.
- `taxFreeAllowance` (monthly) = Σ over editable rows of `amount × (type === 'month' ? 1 : 22)`.
  `STANDARD_WORK_DAYS_PER_MONTH = 22`. Default: 100.000 × 22 = **2.200.000**.
- `policy-allowance-total` = `taxFreeAllowance` (monthly).
- `incomeBeforeTax` = gross (0, section gone) + `taxFreeAllowance`.
- `intern-tax-1` = 10% flat PIT if `incomeBeforeTax ≥ 5.000.000` else 0 (default 2,2M → 0).
- `finalNetSalary` = **`taxFreeAllowance` exactly** (`Math.max(0, taxFreeAllowance)`) —
  welfare and PIT are NOT included for intern (deliberate per product request).
- Welfare rows get NO helperText in intern mode (the generic `formulaNotes.welfare` text
  claims welfare is added to final net — false for intern).

## Formula note keys added

- `formulaNotes.internAllowanceTotal`: "Tổng phụ cấp ngày {{dailyAmount}} x {{workDays}} ngày công/tháng = {{amount}}"
- `formulaNotes.internFinalNetSalary`: "Thực nhận cuối cùng = Tổng phụ cấp {{allowanceTotal}} = {{amount}}"
(both `vi/hr.json` + `en/hr.json`).

## Open question (unresolved)

Whether intern welfare amounts should be added back to final net. Current behavior follows
the literal requirement "final-net-salary = policy-allowance-total". If product confirms
welfare must count, the intern `finalNetSalary` becomes
`taxFreeAllowance + welfareTotal` and welfare helperText must be restored for intern.

## Spec coverage

`create-salary-grade-sections.spec.ts` → "hides gross agreed salary and computes intern
allowance total by working days": asserts no `SALARY_SECTION_IDS.agreedSalary` section,
`policy-allowance-total` = `'2.200.000'`, `final-net-salary-1` = `'2.200.000'`.
