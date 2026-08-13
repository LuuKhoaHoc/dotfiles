---
name: lightweight-ui-mr-verification
description: "Use for small UI/design-token MR verification."
version: 1.0.0
author: hermes
license: MIT
metadata:
  hermes:
    tags: [software-development, code-review, gitlab, ui]
    related_skills: [review-pr, gitlab-mr-review, gitlab-mr-review-feedback]
---

# Lightweight UI / Design-Token MR Verification

Use this skill for focused GitLab MRs that change shared UI components, Tailwind classes, design tokens, placeholder states, or a small number of app overrides. The goal is a proportional but evidence-backed review: verify the requested behavior, inspect token semantics and blast radius, run the smallest meaningful local checks, and report CI state honestly.

This skill complements the GitLab review skills. It does not replace their rules for branch-first reading, conventional-commit checks, consolidated feedback, or publishing review notes.

## When to use

- The MR changes fewer than roughly 30 files and is primarily UI, styling, or design-token related.
- The MR claims to standardize a shared class or visual behavior across components.
- The linked issue contains acceptance criteria that can be checked mechanically.

For large, cross-MFE, architectural, or behavior-heavy MRs, use the broader review/orchestrator workflow instead of expanding this lightweight path.

## Workflow

### 1. Establish the evidence set

1. Read MR metadata: title, description, source/target branch, `head_sha`, `diff_refs`, state, merge status, and pipeline.
2. Read the linked issue and its acceptance criteria. Treat the issue as the behavioral contract, not the MR description alone.
3. List changed files and obtain the diff from the MR branch. Prefer GitLab MCP for metadata/diff; if a local checkout is needed, clone/fetch the source branch and compare against the MR `base_sha` or merge base. Never assume the current local branch is the MR tip.
4. Record the exact head SHA used for verification so later re-reviews can detect whether the author actually pushed to this MR.

### 2. Review at the semantic-token level

For a shared class or token change:

- Inspect the changed component's full surrounding implementation, not only the one-line hunk.
- Compare sibling/base components that express the same UI concept (for example Input, Select, Textarea, Combobox, and app-level overrides).
- Trace the semantic class to its generated token/CSS mapping. A class name that looks equivalent may resolve to a different color or opacity in light/dark themes.
- Search exact legacy patterns and exact intended replacements separately. Check known intentional exceptions before claiming the whole repository is clean.
- Search both shared package usage and app overrides to establish blast radius.
- Check whether `cn`/`tailwind-merge` or class ordering could cause an override to be dropped.

Do not turn a style preference into a blocker unless it contradicts the issue, breaks a user-visible state, violates a documented design-system rule, or causes an accessibility/contrast problem.

### 3. Verify with proportional commands

For a pnpm workspace where packages export generated `dist` artifacts:

1. Build infrastructure packages first: `pnpm build-infra`.
2. Run the changed shared package typecheck and tests, for example:
   - `pnpm --filter @hilo/ui typecheck`
   - `pnpm --filter @hilo/ui test`
3. Run typecheck/build for the directly affected app, for example:
   - `pnpm --filter hr-dashboard typecheck`
   - `pnpm --filter hr-dashboard build`
4. Run lint only for the changed package when appropriate. Separate existing warnings from new errors.
5. Run `git diff --check` and exact-pattern searches as final mechanical checks.

Build infrastructure before tests because workspace package `exports` commonly point at `dist`; otherwise tests can fail during module resolution before exercising the changed code. If the first test run fails this way, fix the verification setup by building infra and rerun; do not report the setup failure as a product regression.

### 4. Inspect CI, not just the aggregate badge

If GitLab says `passed with warnings`:

- List individual jobs and their `status` and `allow_failure` values.
- Trace any failed allowed job.
- Distinguish a code/quality failure from an infrastructure failure such as an unreachable analysis service.
- Report the allowed-failure job explicitly. Do not silently call the pipeline fully green, and do not block a small code change solely on an unrelated allowed infrastructure outage unless project policy requires it.

### 5. Report the verdict clearly

Use a compact review structure:

- **Blocking issues** — only real correctness, security, acceptance-criteria, accessibility, or merge-gate problems; include `file:line`, impact, and literal fix.
- **Suggestions** — lower-risk improvements or residual validation such as visual QA.
- **Verification evidence** — commands and exact pass/fail counts.
- **CI note** — aggregate status plus the underlying job explanation.
- **Overall assessment** — risk and recommendation.

A blocked visual check is residual evidence, not automatically a blocker for a low-risk class-only change. State what was and was not verified instead of implying visual confirmation.

## Common pitfalls

- Trusting the MR checklist without checking the linked issue's acceptance criteria.
- Searching only changed files and then claiming a repo-wide cleanup.
- Treating `muted-foreground` as a universal visual equivalent without reading its light/dark token mapping.
- Running package tests before building workspace infrastructure and mistaking missing `dist` exports for a regression.
- Calling a warning pipeline "green" without inspecting `allow_failure` and the failed job trace.
- Over-escalating a one-line UI normalization to a blocking issue when automated checks pass and only visual QA remains.
- Running a multi-agent review for a tiny focused diff; use the proportional single-agent path.

## References

- `references/lightweight-ui-mr-verification.md` — reusable command sequence, evidence checklist, and example failure classification.
