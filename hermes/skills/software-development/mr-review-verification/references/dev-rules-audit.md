# Dev-rules audit tool (personal, Hilo-adapted) — how to run & interpret

Tool: `~/Dev-Work/dev-rules/` — evondev's MIT dev-rules bundle adapted for the
Hilo erp-admin monorepo. **Personal use only; never push into the repo.**

## Invocations

```bash
bash ~/Dev-Work/dev-rules/run-audit-hilo.sh                      # summary per section, all MFEs
bash ~/Dev-Work/dev-rules/run-audit-hilo.sh apps/hr/src          # one MFE
bash ~/Dev-Work/dev-rules/run-audit-hilo.sh apps/hr/src --core   # detail only for real-bug sections (3-7, 23, 24)
```

- Config: `~/Dev-Work/dev-rules/hilo-conventions.md` — Filenames `PascalCase`,
  `cn()` helper, `@hilo/icons`, `raw <img> allowed`, React 19. Script reads it
  to skip sections that don't apply (Next.js, img, className).
- Wrapper lives next to the script and passes `--config` automatically.

## Output interpretation

- **Sections 3-7 = real bugs** (cross-feature imports, raw button/img/svg/a) — fix first.
- Sections 11-24 = style/types/naming (generic Props, inline types, vague
  names, boolean prefix, dupes/barrels, >300-line files).
- Section 25 (blank line before return) + section 1 leftovers = noisy
  heuristics — low priority, not blockers.
- Baseline 2026-08: hr 1025 / sale 254 / shared 275 / ui 277 / employee 215 /
  shell 154 / partner 79 / finance 61 / product 31 / dashboard 12 hits —
  mostly sections 14/18/20/25 noise; sections 3-7 nearly clean repo-wide.

## Pitfalls discovered while adapting (2026-08-17)

1. **Stock audit-rules.sh hardcodes kebab-case filenames** → 599 false
   positives on Hilo's PascalCase codebase. Fix applied: read a
   `Filenames: PascalCase` convention from config; the Pascal branch accepts
   PascalCase / usePascalCase / kebab / single-word (index, types, attendance)
   / spec-test, and flags only true camelCase mixes. Lesson: any grep-audit
   whose regex hardcodes a convention (case, framework, styling helper) will
   lie about a repo that chose differently — read the script's assumptions
   before trusting output.
2. **Section headers carry ANSI escape codes before the text** —
   `printf '\033[1m== %s\033[0m'` → line starts with `\033[1m==`, so
   `awk '/^== /'` NEVER matches. Match `/\033\[1m== /` or strip ANSI first.
   Same trap for any tool output piped through awk/grep with `^` anchors.
3. **Dotted spec files** (`attendance.lock-unlock.spec.ts`) get mis-flagged by
   the stock kebab regex (requires `-`-separated segments) — patched regex
   accepts `[.-]` separators.