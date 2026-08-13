# Lightweight UI MR Verification Reference

## Reusable sequence

```bash
# From a clean temporary checkout at the MR source branch
git fetch origin <source-branch>
git diff --stat <base-sha>...HEAD
git diff --check <base-sha>...HEAD

# If workspace packages export dist artifacts
pnpm build-infra

# Targeted verification
pnpm --filter @hilo/ui typecheck
pnpm --filter @hilo/ui test
pnpm --filter <affected-app> typecheck
pnpm --filter <affected-app> build
pnpm --filter @hilo/ui lint
```

## Evidence checklist

- MR `head_sha` recorded; source branch and base SHA are explicit.
- Linked issue acceptance criteria checked one by one.
- Changed files and full surrounding implementations inspected.
- Shared semantic token mapping checked in generated CSS for light and dark themes.
- Exact old patterns and exact replacement patterns searched separately.
- Shared package usage and app-level overrides searched for blast radius.
- `pnpm build-infra` completed before package tests when workspace `dist` exports are involved.
- Test counts and typecheck/build exit status recorded from real output.
- CI aggregate status decomposed into job status plus `allow_failure`.
- Failed allowed jobs traced and classified as code failure versus infrastructure failure.
- Visual QA status reported separately; blocked visual QA is not silently presented as pass.

## Failure classification

| Observation | Report as |
|---|---|
| Test cannot resolve a workspace package entry before infra build | Verification setup failure; build infra and rerun |
| Typecheck or build fails after infra is built | Real code verification failure until explained |
| Lint has existing warnings but zero errors | Pass with warnings; do not call it error-free lint if precision matters |
| Pipeline is `success` but a job is `failed` with `allow_failure=true` | Passed with allowed failure; name the job and reason |
| Visual server/browser unavailable | Visual check blocked; keep separate from automated checks |
| Exact legacy class search returns no matches | Mechanical acceptance criterion verified for that pattern |

## Design-token checks

A semantic utility such as `text-muted-foreground` is only meaningful after tracing its mapping. Inspect the generated declarations and both theme blocks; a light-theme mapping may differ from dark-theme mapping. Also distinguish a placeholder utility (`placeholder:text-*`) from ordinary text utility usage (`text-text-caption`): acceptance criteria may target only the former.
