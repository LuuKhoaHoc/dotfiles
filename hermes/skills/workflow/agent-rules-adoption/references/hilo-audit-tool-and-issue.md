# Worked example — building the Hilo personal audit tool + issue filing (2026-08-17, session 2)

Continuation of `evondev-dev-rules-hr-audit.md`. The adoption analysis was approved; this session built the tool, ran it across the whole monorepo, and filed the first cleanup issue.

## Deliverable layout (kept OUT of the repo)

```
~/Dev-Work/dev-rules/
├── audit-rules.sh          # evondev original, section 1 fixed
├── hilo-conventions.md     # conventions config read via --config at runtime
├── run-audit-hilo.sh       # wrapper: whole-monorepo or single-target, --core mode
├── CLAUDE.md               # original markdown (reference only)
├── CLAUDE.nextjs.md        # unused (Vite MFE repo, not Next.js)
├── PROJECT-CLAUDE.md       # original template (reference only)
└── README.md
```

`hilo-conventions.md` (format: `- Key: \`value\`` lines; script's `convention()` greps these):
```
- Framework: `React (Vite)`
- Path alias: `@/`
- Filenames: `PascalCase`
- Types: `interface over type`
- React version: `19`
- Styling helper: `cn()`
- Button: `Button from @hilo/ui`
- Icons: `@hilo/icons`
- Images: `raw <img> allowed`
- Internal links: `react-router Link`
```
Setting `Images: raw <img> allowed` turns off section 5 (correct for non-Next). Setting `Filenames: PascalCase` made section 1 drop the 599 false hits.

## Section 1 fix (filename convention)

Original hardcodes kebab-case regex → 599 false hits on PascalCase Hilo. Patched to read `CONV_FILENAMES`:
- PascalCase mode: accept `use[A-Z]*` (hooks), `[A-Z]*` (components), `[a-z0-9]*[-.][a-z0-9]*` (kebab incl. `.spec`/`.test`), `[a-z0-9]+.ts(x)?` (single-word: index, types, attendance) → flag only true mixed-case camelCase.
- kebab mode (default): original regex.

## Wrapper (`run-audit-hilo.sh`)

- No args → cd into `~/Projects/Hilo-Vppos/erp-admin`, audit every `apps/*/src` + `packages/*/src`.
- `<path>` → single target.
- `--core` → print only sections 3,4,5,6,7,23,24 (real-bug classes) with file:line detail; everything else one summary line per section.
- Default mode prints `hits/OK/SKIP` per section + `TỔNG`.
- Needs to run with `cd` into the repo (terminal cwd does not persist reliably); relative target paths only work from the repo root.

## Cross-MFE density table (hits per 1000 lines)

| MFE | LOC | hits | hits/KLOC |
|---|---|---|---|
| partner (new, split 14/08) | 5075 | 102 | **20.1** |
| shared | 17299 | 275 | 15.9 |
| sale | 17253 | 254 | 14.7 |
| ui | 19213 | 277 | 14.4 |
| dashboard | 892 | 12 | 13.5 |
| shell | 13394 | 154 | 11.5 |
| finance | 5352 | 61 | 11.4 |
| employee | 25746 | 216 | 8.4 |
| **hr** | **124121** | **1025** | **8.3** |

Conclusion: newest MFE is densest — split inherits old sale code not yet refactored. Old MFEs are cleaner per line because review rounds already cleaned them. Raw totals alone mislead (hr looks worst, is actually best-per-line).

## Classification corrections (vs the analysis session)

Flipped from "real signal" to "intentional / acceptable" once sites were inspected:
- `export * from` — only in `features/*/index.ts` = FSD public API boundary (AGENTS.md-sanctioned for hr). NOT a finding. Check location before flagging.
- `(p)`, `(s)`, `(r)`, `(e)` map/onChange callbacks — standard React, not bugs.
- `const res =` in `useMutation` handlers — acceptable.

Survives as real on partner (issue #197): React.FormEvent ×3 (deprecated React 19), raw `<button>` ×1 (StandaloneErrorBoundary — same file copied across all 7 MFEs, candidate to lift into @hilo/ui instead of fixing per-copy), generic `interface Props` ×1, inline object types ×2, 2 components/file ×5, boolean state prefix ×9, >300-line ×2, missing barrels ×5 folders.

## Issue structure that worked (GitLab #197)

- Title: `[Partner] Cleanup code quality post-audit: deprecated API, FSD, naming`
- Per-group checkboxes with exact `file:line` → implementer runs without re-discovery.
- `🚫 Ngoài scope (chủ ý thiết kế, KHÔNG sửa)` section — explicit list of measured-but-not-fixed (export * boundary, short callbacks, res).
- Acceptance criteria end with `pnpm --filter partner typecheck && lint && exec vitest run`.
- Labels: `MFE::partner`, `Refactor`, `frontend`; assignee = MFE original author (luukhoahoc, also MR !609 author).
- Verified by GET-ing the created issue (never trust create's response alone).

## Shell parsing pitfalls (audit output)

- Section headers are printed with ANSI codes: `printf '\n\033[1m== %s\033[0m\n'`. So `awk '/^== /'` NEVER matches; the line starts with `\033[1m`. Use `/\033\[1m== /` in awk, or unanchored grep `'== 3\.'`. This cost three debug rounds.
- `grep -E '^== '` also fails for the same reason; unanchored `== ` works.
- Bash `case` globs in the audit script match the whole basename (prefix match semantics), which is why `[a-z0-9]*[-.][a-z0-9]*` accidentally allowed `attendance.ts`? No — that pattern requires a `-` or `.`, so single-word files fell through to the `*)` branch and were flagged. The final pattern order matters: longest/most-specific matchers first.