---
name: consolidation-refactor-review
description: "Review consolidation refactors (duplicate comps → shared)."
related_skills: [gitlab-mr-review, pr-review, gitlab-mr-review-feedback]
---

# Consolidation Refactor Review

Use when reviewing MRs that merge N duplicated local implementations into ONE shared component/utility (e.g. 3 MFEs each with their own `StatusBadge` → `@hilo/ui` + a `toneMap`/variant prop). These MRs claim "no behavior change" — the reviewer's job is a **key-by-key parity diff** between each old implementation and the new shared abstraction. Worked real case: MR !620 StatusBadge consolidation (finance/hr/employee → @hilo/ui).

## The 5-step parity check

1. **Exact paths first.** `git diff --stat` truncates paths with `.../` prefixes. Run `git diff --name-only origin/develop...origin/<branch>` BEFORE targeting individual files — guessing paths wastes calls (real case: an hr file actually lived under `features/dashboard/` / `features/time-off-management/`, not the guessed `features/requests/`).

2. **Extract every OLD style switch and diff against the NEW map.** `git show origin/develop:<old-path>` for each deleted local component, then compare key-by-key with the new shared map. Watch for:
   - **Missing keys** — a status the old code styled but the new map lacks silently falls to the default tone. Real case: `HR_STATUS_TONE_MAP` had no `draft` key while the change-management adapter normalizes statuses to `'draft'` — draft badges went gray. Confirm with a grep that the status is REAL (`git grep -n "draft" origin/<branch> -- <app>/src/features` for the status value), not a phantom.
   - **Styles the new abstraction cannot express** — outline variants (`bg-surface-subtle text-text-body border border-primary`), border/badge-level classes. A tone map only carries color tone; any special style silently collapses to the neutral default. Flag as visual regression vs the "no behavior change" claim, or confirm intent with the author/design.
   - **Normalization drift** — old `trim().toUpperCase().replace(/[\s-]+/g,'_')` vs new plain `toLowerCase()` lookup: space/hyphen statuses (`'needs supplement'`, `'on-leave'`) fall to default. Usually an edge case; note it, don't block.
   - **Fallback improvements** — new case-insensitive lookup may color statuses that were gray before (old exact-case match). Say so; it's a plus, not a regression.

3. **Verify migration completeness.** `git grep -n "import.*<Component>" origin/<branch> -- <apps>` — every consumer import must point at the shared package, none at deleted paths. For removed helpers: `git grep -n "<helperName>" origin/develop` — zero consumers proves dead-code deletion is safe. Check deleted type exports too (e.g. `export type { LeaveStatus }`).

4. **Blast radius of shared-component prop changes.** If the shared component's own behavior changed (e.g. `{children ?? label ?? status}` added), grep ALL consumers repo-wide on develop — including MFEs NOT in the MR (sale, product, shell...) — for the changed prop. Safe only if no consumer passes it; also note the old behavior (children fell through `...props` → double render) so the change is understood, not just approved.

5. **Verify the "typecheck pass" claim** — run the affected packages' typecheck in background (`notify_on_complete`) while finishing the diff read.

## Mapping-parity table template

| Old impl (file) | Status/key | Old style | New map key | New tone | Match? |
|---|---|---|---|---|---|
| `apps/hr/.../StatusBadge.tsx` | `DRAFT` | `bg-surface-subtle ... border-primary` | *(missing)* | NEUTRAL default | ❌ regression |

## Review comment guidance

- One consolidated comment (see gitlab-mr-review-feedback for the format), @mention the author.
- The blocking finding is usually #2a/2b; frame the fix as: add the missing key (`draft: STATUS_TONE.NEUTRAL,`) + confirm with design that the lost special style is intentional, OR pass `className` at the call site if the style must survive.
- ⚠️ Tell the author what NOT to do: e.g. don't add uppercase duplicate keys when the shared component already has a `toLowerCase()` fallback and the convention is lowercase-only.
- Nit bucket: redundant duplicate-case keys in maps, font-token/height/responsive-size drift in the shared component vs old local classes (`text-caption h-6 sm:text-sm` → `text-xs`).

## Pitfalls

- Don't trust the MR description's "no behavior changes" checklist — verify each visual claim against the old code.
- Don't review the old local components from memory of a different branch — always `git show origin/develop:<path>` (or the MR base_sha).
- Duplicate-case keys (`approved` + `APPROVED`) in one map while the sibling map is lowercase-only = convention drift; flag as nit, the toLowerCase fallback makes them dead weight.
