---
name: scanned-table-extraction
description: Use when extracting scanned-PDF tables into code.
triggers:
  - scanned PDF table (salary scale, price list, contract) whose values go into code/config
  - pdftotext returns empty or the PDF Producer is a scanner app
  - extracting many numeric rows from an image-only document
---

# Scanned Table Extraction (verified)

Single-pass OCR misreads digits. When the output is payroll/financial data, verify before writing. Proven on a 91-row salary/insurance table (3-page HP Scan) with zero errors.

## Workflow

1. **Detect image-only**: `pdftotext -layout file.pdf out.txt` — empty output, and `pdfinfo` shows `Producer: HP Scan` (or similar) ⇒ no text layer.
2. **Render pages**: `pdftoppm -png -r 300 file.pdf /tmp/page` (150 dpi for a first read; 300 dpi to confirm). 3-page scans → 3 PNGs.
3. **Layered vision reads**:
   - `vision_analyze` each full page at 150 dpi, then again at 300 dpi — two independent reads agreeing is the baseline.
   - Ambiguous cells → crop with PIL and upscale (LANCZOS, 2–3×), re-read digit-by-digit.
4. **Independent cross-checks** (any one catches a misread):
   - **Arithmetic invariants — the strongest.** Derived columns must hold: e.g. employee contribution = insurance base × 10.5%, company = × 21.5%. A suspicious base that fails the check is a misread (567.000 ÷ 10.5% = 5.400.000 rules out 5.310.000). Find the invariant in the document's own structure first.
   - `tesseract` on tight upscaled crops (`--psm 6`). The `eng` langpack reads digits fine even on Vietnamese docs; table structure comes out garbled — use it for numbers only, as a tiebreaker.
5. **Generate, don't hand-type**: write a script that builds the output (constants file, config) and embeds the vision-extracted values as a `GROUND_TRUTH` dict — assert every generated row matches ground truth BEFORE writing. Then sanity-check row counts per group (regex count) after writing.
6. **Flag anomalies, don't normalize**: source docs are often internally inconsistent (one row using a different rate than its siblings). Replicate as-is and list the anomalies for the user to confirm with the document owner — never silently "fix" financial data.

## Pitfalls

- Vision models hallucinate plausible digits; a value that breaks the document's own pattern (rate × base) is suspect until arithmetic confirms it.
- 150-dpi full-page reads can misread similar digits (5.310.000 vs 5.400.000); only the arithmetic check is decisive.
- Don't trust `tesseract` table layout on scans — trust it only for isolated digit strings.
- Keep the verification script (GROUND_TRUTH + generator) in /tmp or a scratch dir; the diff against the old file should show exactly the intended rows changing.

## Related

- `ocr-and-documents` (bundled) covers plain text/OCR extraction — this skill adds the verification discipline for structured numeric data.
- ERP example + full 91-grade salary data: `hr-salary-patterns` → `references/salary-grade-scale.md`.
