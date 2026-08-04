# Doc ↔ Codebase Reconciliation (AGENTS.md / docs sync)

Use when the task is: "update/correct AGENTS.md (or any doc) so it matches the real codebase." This is the inverse of feature-deployment-verification: instead of checking a claimed feature exists, you check every *specific claim in the doc* and patch the stale/wrong ones.

## Workflow

1. **Read ALL assigned docs first** (batch read_file in parallel). Extract every *specific, checkable claim*: commands, script names, file paths, folder names, component names, namespaces, ports, base URLs, env vars, remotes, versions.
2. **Batch-gather source-of-truth** (read-only, parallel): config files + `ls`/`find` for existence of referenced files/folders + grep for named symbols.
3. **Classify each claim**: ✅ verified OK / ❌ stale-wrong (with evidence) / ⚠️ needs human judgment.
4. **Patch ONLY ❌ stale-wrong claims** with clear evidence (a diff that states the old line, new line, and the evidence). Do NOT add new content without evidence. Do NOT rewrite for style.
5. **Report in a structured table**: `File → Edit (old→new) → Reason → Evidence`, plus a "Verified OK (no change)" section. Always flag ⚠️ items needing human review (e.g. renames where you had to infer intent).

## Source-of-truth cheat-sheet (erp-admin: pnpm + Turbo + MFE monorepo)

For each claim type, verify against:

| Claim type | Where the truth lives |
|---|---|
| Root scripts (build, dev, lint, typecheck, format, test, clean, git:release...) | `package.json` `scripts`. Root may have NO `test`/`clean` even if `turbo.json` has those tasks. `npx turbo clean` is CLI, not a script. |
| Workspace scope / hoisting / allowBuilds | `pnpm-workspace.yaml` (`shamefullyHoist`, `publicHoistPattern`, `allowBuilds`, `overrides`) |
| Node / package-manager pins | `.nvmrc` + `packageManager` in root package.json |
| Git hooks | `lefthook.yml` (pre-commit / commit-msg / pre-push commands + globs) |
| lint-staged globs | `.lintstagedrc.*` (may be a separate file, NOT in package.json) |
| Commitlint types / max lengths | `commitlint.config.*` (types list, `header-max-length`) |
| Ports / base / envDir / host / allowedHosts | each `apps/*/vite.config.ts` (`server.port`, `base`, `envDir`, `VITE_PUBLIC_DEV` → `host`/`allowedHosts`) |
| `emptyOutDir` (clean-output) behavior | each `packages/*/vite.config.ts` |
| Active MFE remotes | **ALL THREE must hold**: present in `apps/shell/src/registry/mfe-manifest.ts` (MFE_REMOTE_CONFIGS) AND in `apps/shell/src/registry/entries.tsx` (MFE_LOADERS) AND `enabled:true` in `packages/shared/src/config/navigation.ts` (APP_MODULES). A remote in MFE_REMOTE_CONFIGS alone is NOT active. |
| MFE route/module metadata | `packages/shared/src/config/navigation.ts` (APP_MODULES), `packages/shared/src/constants/paths.ts` (PATHS) |
| Package name / exports / scripts | `packages/*/package.json` (`name`, `exports`, `files`, `scripts`) |
| i18n namespaces + defaultNS | `packages/locales/src/i18n.ts` (resources keys + `defaultNS`) — namespaces drift as apps are added/removed |
| Component/folder existence | `find`/`ls` the actual dirs — docs claim folders/components that no longer exist |
| "Focused test" commands | Verify the referenced test file EXISTS before trusting/echoing the command |

## Hard rules

- **Never trust a doc's claim about a path/command/component — verify it.** This session found: a root "focused test" referenced a spec file that didn't exist; `@hilo/ui` STRUCTURE listed a `components/shared/` folder that had been removed; an i18n namespace list referenced a `department` namespace that no longer existed and missed `employee/finance/sale`.
- **A named component/state claim can be wrong even when close names exist**: `@hilo/ui` has `Empty`, `EmptyView`, `Skeleton` — but NO `EmptyState` or `ErrorState`. Grep the actual exports (`index.ts`) before repeating "X is available in the library."
- **Only patch what's demonstrably wrong; report the rest as verified.** Include a "Verified OK (no change)" section so reviewers trust the audit.
- **Flag judgment calls as ⚠️**, e.g. when you must infer a rename destination (I mapped composed-shared components to `components/customs/` because that's where the actual shared composites live).

## Worked findings (2026-07-31 sync)

Stale claims fixed in root `AGENTS.md`:
1. `Quy tắc Cursor theo feature: .cursor/rules/*.mdc` — no `.cursor/` dir, zero `*.mdc` files. Removed clause.
2. Focused test `employee-schema.spec.ts` → real file `create-employee-contract.spec.ts`.
3. "active remotes = hr, employee; apps-dashboard not in MFE_LOADERS" → all 6 (`apps-dashboard, hr, employee, sale, finance, product`) present in all three sources + enabled. (apps-dashboard had since been added to `MFE_LOADERS`.)
4. `.npmrc: shamefully-hoist=true + public-hoist-pattern[]=*` — deprecated; real values now in `pnpm-workspace.yaml:12-14`. Contradicted the doc's own earlier line.
5. "Skeleton/EmptyState/ErrorState có sẵn trong @hilo/ui" — EmptyState/ErrorState don't exist; only `Skeleton`/`Empty`/`EmptyView`.

`packages/ui/AGENTS.md`: removed `components/shared/` from STRUCTURE tree, WHERE-TO-LOOK, and conventions (folder gone; shared composites now in `components/customs/`).

`packages/locales/AGENTS.md`: namespace list `(common, department, shell, hr, appsDashboard)` → `(common, shell, hr, appsDashboard, employee, finance, sale)`.

**Never commit during a parallel multi-agent doc-sync** — other subagents touch their own file groups; your `git status` will show unrelated modified files. Only report YOUR group's diffs.
