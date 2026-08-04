---
name: agent-plan-review
description: Review and finish incomplete work from other coding agents.
---

# Agent Plan Review

Review and finish code changes produced by another AI coding agent. The other agent often gets the bulk right but misses critical details — stores, locales, spec files, navigation, and cleanup.

## When to Use

- Another agent (antigravity, Claude Code, Gemini CLI, etc.) produced code or a plan that needs human review
- User says "review this plan", "clean up after X", "finish what Y started"
- A handoff document mentions unstaged / uncommitted changes

## Review Workflow

### Step 1: Read the handoff / plan

Check for:
- **Branch** it was created on
- **What was accomplished** vs what's still pending
- **Verification claims** (tests pass, typecheck clean)
- **Known remaining items**

### Step 2: Cross-reference against the real codebase

Don't trust the plan's claims. Verify every assertion by reading actual files:

| Item | What to check |
|---|---|
| **Feature structure** | Does the file hierarchy match the plan's diagram? |
| **Old features deleted** | Do the old folders actually appear as deleted in `git status`? |
| **stores/** | Zustand / Redux / Jotai stores are commonly forgotten. |
| **Spec files** | Count them in the original vs new location. |
| **Locales / i18n** | Check both `vi` and `en` translation trees for stale keys. |
| **Navigation** | `navigation.ts` — still referencing old paths? |
| **Path constants** | `paths.ts` — old constants removed? |
| **Cross-feature imports** | Grep for imports from old feature paths. |
| **Page files** | Old page components deleted? |
| **App route wiring** | `App.tsx` still pointing at old pages? |

### Step 3: Run the plan's own verification

If the plan says "tests pass" or "build passes", run those commands yourself. Plans often misreport.

### Step 4: Fix gaps systematically

Fix in order: shared packages first → feature code → cleanup.

### Step 5: Final verification

```bash
pnpm --filter <app> typecheck
pnpm --filter <app> lint
pnpm --filter <app> exec vitest run src/features/<feature>/
pnpm --filter @hilo/shared typecheck    # if shared paths changed
pnpm --filter @hilo/locales build       # if locales changed
```

## Common gaps checklist

When reviewing a merge/consolidation refactor from an automated agent:

- [ ] **stores/** — State management (Zustand, Redux) nearly always forgotten.
- [ ] **Spec files** (.spec.ts / .test.ts) — Agent moved the source but not the tests.
- [ ] **Locales** (i18n JSON) — Both `vi` and `en` trees must be updated together.
- [ ] **Navigation config** — Sidebar menu still has old entries.
- [ ] **Path constants** — Old route constants still exist alongside new ones.
- [ ] **Cross-feature imports** — Other features importing from the deleted module.
- [ ] **Barrel exports** (index.ts) — Public API boundary still re-exports from old paths.
- [ ] **Page files** — Old `pages/*.tsx` still exist.
- [ ] **App route wiring** — `App.tsx` / router config still references old page components.
- [ ] **Inline hex colors vs constants** — Helper components may have raw `'#xxxxxx'` instead of color constant references.

## React refactoring patterns for large component files

When splitting a component file > 700 lines:

### Extract helpers first, not JSX

**Bad**: Split a 1300-line component into 350-line "Section1"/"Section2" chunks — creates prop-drilling and indirection.

**Good**: Extract pure helper functions and constants to a `utils/` file first. Then the component file shrinks naturally (~700 lines) and the extracted code is testable independently.

### Extract print/document styles

Payslip/PDF-specific colors and print styles belong in `constants/`, not inline in the component.
CSS-in-JS template literals for `@media print` belong in a constants file.

### Consolidate color constants

When a component uses custom brand colors for a print/canvas output (payslip, certificate, etc.), define them once in a constant object and reference it everywhere. No raw hex strings in JSX.
