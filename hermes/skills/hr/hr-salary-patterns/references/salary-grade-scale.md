# Official salary grade scale — data & extraction (2026)

Source: `Thang bang luong bao hiem_2026.pdf` — 3-page **HP Scan** (image-based, no text layer), scanned copy of the company salary/insurance table (Công ty Cổ phần Dịch vụ T-VAN HILO). Boss wants these grades hard-coded in FE until BE config lands; payroll deadline 10/08.

## Where it lives

`apps/hr/src/features/salary/constants/salary-grade-scale.ts` → `SALARY_POSITION_GROUPS` (consumed by `useSalaryQueries` queryFn, `SalaryGradesListView`, `getPositionGroupsByTemplateType`). Shape: `createGrades(rows, allowanceBreakdown)` with `[code, agreedSalary, socialInsuranceSalary]` tuples; `level` derived from `code.split('-')[1]`.

## The 91 grades (agreed / insurance)

| Group | Grades | Agreed salary | Insurance salary rule |
|---|---|---|---|
| NV | B1–B10 (10) | 6M, 7M, 8M, 8.6M, 9M, 10M…14M | **Fixed** 5.400.000 (B1–B5), 5.682.000 (B6–B10) |
| CV | B1–B21 (21) | 15M → 35M, +1M/step | **55%** of agreed |
| TP | B1–B21 (21) | 20M → 40M, +1M/step | **55%** of agreed |
| GĐ | B1–B15 (15) | 30M → 44M, +1M/step | **55%** of agreed |
| TGĐ | B1–B15 (15) | 35M → 49M, +1M/step | **55%** of agreed |
| HĐQT | B1–B9 (9) | 50M, 60M…130M | B1 = 27.500.000 (55%); B2–B8 = **40%**; B9 = 50.600.000 (cap) |

Insurance check on the PDF: employee contribution = insurance × 10.5%, company = insurance × 21.5% (all rows internally consistent — this is the decisive arithmetic cross-check).

## ⚠️ Anomalies awaiting boss confirmation (replicate PDF as-is, do NOT normalize)

1. **HĐQT-B1 insurance = 27.500.000 (55%)** while B2–B8 use 40% — 4 independent reads (150dpi, 300dpi, zoomed crop, digit-by-digit) + arithmetic (2.887.500 = 27.5M × 10.5%) all agree. Likely a typo in the source doc (would be 20.000.000 = 40%).
2. **HĐQT-B9 insurance = 50.600.000** (not 52M = 40% of 130M) — looks like a contribution cap in the source doc.
3. **NV-B1–B5: 5.310.000 → 5.400.000** — old FE value was wrong vs the new table.

## Extraction workflow (reusable for scanned salary docs)

1. `pdftotext -layout` empty → image scan. Confirm via `pdfinfo` (Producer: "HP Scan").
2. `pdftoppm -png -r 300` per page (150 dpi is enough for a first read; 300 for confirmation).
3. `vision_analyze` each page; for ambiguous cells crop + upscale with PIL (LANCZOS) and re-read digit-by-digit.
4. Independent cross-checks: (a) second vision read at higher DPI, (b) tesseract on tight crops (eng works for digits even on Vietnamese docs — table structure is garbled though), (c) **arithmetic invariants** (contribution columns = base × rate) — the strongest check.
5. Generate the constants with a Python script embedding the extracted values as `GROUND_TRUTH`, assert generated == ground truth for all rows BEFORE writing the file.
6. Flag anomalies to the user instead of silently "fixing" them — the source doc itself may be inconsistent; payroll data must not be guessed.

## Generation script pattern

```python
PDF_ROWS = { 'NV': [('NV-B1', 6_000_000, 5_400_000), ...], ... }  # explicit, from PDF
GROUND_TRUTH = { 'NV-B1': (6_000_000, 5_400_000), ... }           # vision-extracted
# assert PDF_ROWS values == GROUND_TRUTH for every code, then emit TS
```

Script output: `/tmp/salary-grade-scale.generated.ts`, then `cp` into the repo and sanity-check grade counts per prefix (10/21/21/15/15/9).

## Payroll config linkage

`buildPayrollTemplateConfig` uses these grades for official templates (agreedSalary, insuranceSalary rates default from `socialInsuranceSalary / agreedSalary`). Intern/collaborator use `SPECIAL_TEMPLATE_POSITION_GROUPS` (B1–B5, agreedSalary 0) — unchanged.
