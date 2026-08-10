---
name: payroll-money-safety
description: Fix payroll money math bugs, percent precision, rounding.
triggers:
  - salary grade or payroll amounts look off by a few đồng/hundreds
  - percent ↔ amount round-trip drift in salary templates
  - payload rate precision for BE round-trip (insurance salary)
  - preview gross exceeding agreed salary (NV low grades)
  - auditing rounding of money values (đồng, PIT brackets, OT)
---

# Payroll Money Safety (erp-admin HR salary)

Rules that prevent "đền tiền" bugs in salary grade / payroll math. The UI engine is
`apps/hr/src/features/salary/utils/create-salary-grade-sections.ts`
(`applyCalculatedAmounts`) and `salary-grade-calculation.ts`
(`calculateSalaryGradePreview`). Real payroll money is BE-computed
(`PayrollEmployeeValues`) — FE previews must not corrupt the numbers BE receives.

## Non-negotiables

1. **P1 (insurance salary) amount is the source of truth.** Never derive P1 back
   from a display-formatted percent. `applyCalculatedAmounts` uses the entered
   amount directly when `> 0`; percent is display-only.
2. **Percent display rounds to 4 decimals** (`formatPercentAmount`); the engine
   reads the RAW percent string (`findRowPercentInput`) so tooltips match the math.
3. **Payload `rate` must be full-precision** — `getSectionItems` sends
   `rate = row.percent/100`, so a 4dp-truncated percent (62,79069767% → "62,7907")
   makes BE compute `round(gross × rate)` wrong (7.000.000 × 81,1714% = 5.681.998
   vs 5.682.000). Fix: `getInsuranceSalaryItems` in `salary-grade-template-utils.ts`
   overrides `rate = amount/gross` (full precision) for code `LUONG_DONG_BHXH`.
4. **Preview gross clamps to agreed salary**: `min(gross, P1 + allowance + P2 + P3)`.
   NV low grades have P1 5.400.000 + meal 1.100.000 (50k × 22) > gross 6.000.000 →
   P2/P3 pool negative → un-clamped preview showed 6.500.000 in the
   "Thu nhập sau thuế" tooltip. `calculateSalaryGradePreview` applies the same
   clamp guarded by `agreedSalary > 0` (intern/collaborator agreed = 0 must NOT
   clamp to 0).
5. **Every money value rounds to the đồng** (`roundCurrency = Math.round`).
   Progressive PIT rounds per bracket then sums; OT = `round(hourly × hours)`
   after multiplying; dependent count = `floor`.

## Known accepted drift (report, don't "fix")

- Multi-row P2/P3 percent rows each round independently → Σ can be ±1–2đ off
  `round(base × 100%)`. 1-row-100% templates: zero drift.
- FE previews are estimates; BE payroll is authoritative. If HR wants absolute
  certainty, ask BE to confirm their rounding point (per-bracket like FE, or total).

## Case numbers (regression anchors)

| Case | Expectation |
|---|---|
| Gross 8.600.000, P1 entered 5.400.000 | P1 stays 5.400.000; BHXH 567.000; đoàn phí 27.000; after-tax 8.006.000 − tax |
| NV-B1 sync (6.000.000 / 5.400.000, allowance 1.100.000) | previewGross = 6.000.000 (NOT 6.500.000); income-after-tax 5.406.000 |
| Gross 7.000.000, P1 5.682.000 | payload rate = 5.682.000/7.000.000 full precision; BE round → 5.682.000 |
| BA case: Gross 32.000.000, P1 17.600.000, P2 99% + 3 dependents | net 30.134.400 |

## Verification

- `node ../../node_modules/vitest/vitest.mjs run src/features/salary` (89 tests — includes percent-precision, clamp and payload-rate specs).
- Spec anchors: `create-salary-grade-sections.spec.ts` (clamp NV low grades),
  `salary-grade-template-utils.spec.ts` (rate precision), `salary-grade-calculation.spec.ts`.
- ESLint + `tsc -b --force` from `apps/hr` after touching the engine.

## Related pitfalls (this umbrella's neighbours)

- i18n namespaces: `useTranslations('employee')` reads **employee.json** (request-management keys live there), `useTranslations('hr')` reads **hr.json** (salary keys). Missing key → i18next renders the raw key string.
- shadcn Accordion in sidebar: default `[&[data-state=open]>svg]:rotate-180` rotates EVERY direct svg — use `svg:last-child` so module icons don't flip when the accordion opens.
- OT request detail "Hệ số hưởng lương": BE rule `payrollPercent = 0 → 100%; != 0 → actual value`; format via local helper (0/empty/NaN → "100%").

Full component map, section/row IDs and engine internals: see `hr-salary-patterns` (user-owned — suggest `hermes curator adopt hr-salary-patterns` if it needs updates).
