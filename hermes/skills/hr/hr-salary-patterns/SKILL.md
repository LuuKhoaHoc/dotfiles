---
name: hr-salary-patterns
description: Use when modifying salary grade templates in apps/hr.
triggers:
  - modifying salary grade templates or CreateSalaryGradeView in apps/hr
  - changing intern/probation/collaborator/official section behavior
  - adding or editing salary component calculation rows or formula notes
---

# HR Salary Patterns

Salary-grade builder architecture and rules for the HR MFE (`apps/hr/src/features/salary`). Session-specific detail (section/row IDs, constants, implementation notes): `references/salary-grade-builder.md`.

## Key files

| File | Role |
|------|------|
| `utils/create-salary-grade-sections.ts` | Source of truth: per-template initial sections, `applyCalculatedAmounts` pure recalc, `SALARY_SECTION_IDS`, `formatSalaryAmount`/`formatPercentAmount` |
| `utils/salary-grade-template-utils.ts` | `createSectionsByTemplateType`, hydration, payload building (`buildPayrollTemplateConfig`), template-type helpers |
| `components/salary-grades/CreateSalaryGradeView.tsx` | The view: holds `sections` state; `updateRow`/`addRow`/`removeRow`/`reorderRows`; template-type switching; hydration effect |
| `constants/salary-grade-scale.ts` | Hard-coded official grade scale (`SALARY_POSITION_GROUPS`, 91 grades) — source: scanned PDF "Thang bang luong bao hiem_2026". Full data + extraction workflow + anomalies: `references/salary-grade-scale.md` |
| `utils/create-salary-grade-sections.spec.ts` | Unit tests for sections + calculations (build sections, mutate rows, assert formatted amounts like `'2.200.000'`) |

## Core architecture

- `sections` (`SalaryComponentSection[]`) is the single UI state. Every mutation goes through `setSections` and ends with a call to `applyCalculatedAmounts(sections, salaryGrade, t, { templateType })`.
- `applyCalculatedAmounts` is PURE: recomputes every `amountMode: 'calculated'` row + `helperText` formula notes from current inputs. Editable rows have `amountMode: 'editable'`.
- Initial sections per template: `createInitialSections` (official, the default `DEFAULT_SALARY_GRADE_TEMPLATE_TYPE`), `createInternInitialSections`, `createProbationInitialSections`, `createCollaboratorInitialSections` — selected by `createSectionsByTemplateType`.
- **Hiding a section for a template = remove it from that template's initial sections.** The View renders the pinned `gross-agreed-salary` card only if `sections.find((s) => s.id === SALARY_SECTION_IDS.agreedSalary)` exists — removing it from `createInternInitialSections` hides it with zero View changes. Hydration and section-order loaders only touch existing sections, so removal is safe for edit/duplicate flows.
- Row/section order persisted in localStorage (`salary-grade-{row,section}-order.ts`); loaders reorder existing ids only.

## Bidirectional sync (amount ↔ percent)

When two editable fields derive from each other (e.g. `insurance-salary-1` amount ↔ percent, official template):

- Derive the "other" field in the event handler (`updateRow`) BEFORE the pure recalc — `applyCalculatedAmounts` cannot know which field the user edited; if percent holds a stale value and the user edits amount, the pure function would re-derive amount from the stale percent and clobber the edit.
- `applyCalculatedAmounts` keeps consistency: it re-derives amount from the rate (so gross/grade changes propagate), and has a fallback to derive the rate from amount when percent is empty (self-consistency for hydrated/legacy data).
- Full pattern + pitfalls (2-decimal percent drift, zero-base guards, spread-override trap): see `hr-form-patterns` "Bidirectional derived-field sync" (user-owned skill — if it needs updating, ask user to run `hermes curator adopt hr-form-patterns`).

## Intern template rules (current)

- Sections: tax-free-allowance (meal 50.000 + transport 50.000, `type: 'day'`), intern PIT, welfare, final-net-salary. **No gross-agreed-salary.**
- `policy-allowance-total` = Σ daily allowances × `STANDARD_WORK_DAYS_PER_MONTH` (22) via `sumEditableMonthlyTaxFreeAllowances` (day-type rows × 22, month-type × 1).
- `final-net-salary` = `policy-allowance-total` — welfare and PIT are NOT added for intern (product decision; PIT is 0 below the 5M threshold anyway).
- Default display: (50.000 + 50.000) × 22 = **2.200.000**, PIT 0, final net 2.200.000.

## Official grade scale (constants)

- `SALARY_POSITION_GROUPS` in `constants/salary-grade-scale.ts` hard-codes the official scale (BE config chưa có — hard ở FE để kịp payroll 10/08): NV 10, CV 21, TP 21, GĐ 15, TGĐ 15, HĐQT 9 = 91 grades.
- Insurance rules: CV/TP/GĐ/TGĐ = **55%** của lương thỏa thuận; NV cố định 5.400.000 (B1–B5) / 5.682.000 (B6–B10); HĐQT: B1 = 27,5M (55% — bất thường), B2–B8 = 40%, B9 = 50,6M (cap).
- Allowance breakdowns là per-group constants (`BOARD_ALLOWANCE`…`STAFF_ALLOWANCE`); `policyAllowance` = Σ breakdown. PDF nguồn không có phụ cấp — giữ nguyên.
- Khi BE có config: file này trở thành fallback — đã được consume qua `useSalaryQueries` queryFn nên đổi sang API chỉ là đổi 1 chỗ.
- Full 91-grade table + workflow trích xuất từ PDF scan + 3 anomaly chờ sếp xác nhận: `references/salary-grade-scale.md`.

## Formula notes (helperText)

- Every calculated row gets `helperText` from `translateCreate(t, 'formulaNotes.<key>', { params })`; rendered with `whitespace-pre-line` (supports `\n`).
- Keys live in `packages/locales/src/translations/{vi,en}/hr.json` under `features.salary.create.formulaNotes` — always add BOTH languages with identical `{{param}}` names.
- Intern uses dedicated keys (`internAllowanceTotal`, `internFinalNetSalary`); official/probation/collaborator share generic ones (`taxFreeAllowance`, `finalNetSalary`, ...).

## Tests & verification

- Focused: `pnpm --filter hr-dashboard exec vitest run src/features/salary` (all salary specs).
- `pnpm --filter hr-dashboard typecheck`.
- Root (after touching multiple workspaces or for final gate): `pnpm run lint` / `pnpm run typecheck` / `pnpm run build` (turbo). Root lint exit 0 = pass even if it lists pre-existing warnings in unrelated files.
- Locale JSON: validate with `python3 -m json.tool`; keep vi/en key sets in sync (parity check snippet in `hr-i18n-patterns`, user-owned).
