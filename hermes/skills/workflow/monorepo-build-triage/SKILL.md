---
name: monorepo-build-triage
description: Run monorepo build, triage TypeScript failures fast, and apply safe fix sequence in feature code without getting trapped by noisy typecheck output.
triggers:
  - "pnpm build failed"
  - "fix build errors"
  - "monorepo TypeScript errors"
  - "turbo build failed"
  - "hr-dashboard build failed"
tags: [monorepo, pnpm, turbo, typescript, triage, build]
category: workflow
---

# Monorepo Build Triage

Use when user asks: run build then fix errors.

## Core pattern

1) Run target build first (`pnpm build` or workspace-filtered build).
2) Extract first real source errors only. Ignore secondary `ELIFECYCLE` failures in other packages caused by same root failure.
3) Group errors by class before editing:
- missing module/path
- missing export/type mismatch
- stale tests after API rename
- nullability/never inference
- missing mock fixture file
4) Fix highest-fanout issue first (imports/paths/types).
5) Re-run narrowed build (`pnpm --filter <workspace> build`) until clean.

## High-value tactics from session

- If hook return shape changed, update tests to new keys first (example: `attendanceLogs` -> `data`, `safeCurrentPage` -> `currentPage`).
- If constant module only exports base types, do not import feature-specific types from it. Pull feature type from local `types/` boundary.
- For deep relative import uncertainty, compute exact path with:
```bash
realpath --relative-to=<from_dir> <to_file>
```
- When TypeScript shows `Property 'message' does not exist on type 'never'` from local placeholder errors, annotate error union or cast at render site.
- When AGENTS.md mentions mock file but file missing, create typed mock module in expected path to unblock build.

## Path alias strategy (MFE monorepo)

When many files use deep relative paths to `src/shared` (e.g. `../../../../../shared/`), add a workspace-level alias.

HR workspace example — add to `apps/hr/tsconfig.app.json`:
```json
"paths": {
  "@/*": ["src/*"],
  "@hr/shared": ["src/shared"],
  "@hr/shared/*": ["src/shared/*"]
}
```

Add matching Vite alias in `apps/hr/vite.config.ts`:
```ts
resolve: {
  alias: {
    '@': path.resolve(__dirname, './src'),
    '@hr/shared': path.resolve(__dirname, './src/shared'),
  },
},
```

Convention: `@hr/shared/` for `apps/hr/src/shared/`, `@hilo/shared` (package) for `packages/shared`.

After adding alias, bulk-replace old relative imports:
```bash
# Find all occurrences first
grep -rn "from '\.\.\.\./shared/" apps/hr/src/features/
```

## Pitfalls

- Do not trust assumed repo path; verify with `pwd` before first command.
- Do not create broad root-level fixes while one workspace failing; use filtered build loop.
- Do not trust first relative import guess in nested dialog/component trees.
- Avoid importing runtime values with `import type` (breaks switch/value use).

## Verification ladder

1. `pnpm --filter <failing-workspace> build`
2. If clean and change scope local, stop.
3. If user asked full check, run `pnpm build`.

## Output style for this user

- Report short: build status, remaining error class, next action.
- No long narrative.
