---
name: release-branch-porting
description: Port fixes from develop to a release branch via cherry-pick.
triggers:
  - "port this fix to the release branch"
  - "đem fix vào nhánh release"
  - "cherry-pick to release"
  - "src refspec matches more than one"
tags: [git, cherry-pick, release, gitlab, erp-admin]
category: workflow
---

# Release Branch Porting

Use when a fix committed on develop must also land on the active release branch (erp-admin cadence: `release/YYYY-MM-DD`).

## Sequence

1. **Set aside WIP first**: `git stash push -m "WIP: <desc>"` so develop is clean. But BEFORE re-writing any fix, check whether the stash IS the fix — see Pitfalls.
2. **Reproduce the failure on develop**: run `pnpm build` (or `pnpm --filter <workspace> build`) and extract the exact tsc errors.
3. Commit the fix on develop (`git commit -m "fix(...): ..."`), then `git push origin develop`.
4. **Fetch + divergence check**:
   ```bash
   git fetch origin release/<date> -q
   git log --oneline develop..origin/release/<date>   # release-only commits
   git log --oneline origin/release/<date>..develop   # what release still lacks
   ```
   Expected shape: release = develop + release-only commits (e.g. `chore(release): disable CRM modules`). If that holds, the fix cherry-picks cleanly.
5. `git checkout release/<date> && git pull origin release/<date> -q`
6. `git cherry-pick <fix-sha>` — no conflicts expected when release is develop + release-only commits. Do NOT merge develop into release; cherry-pick keeps the branch clean.
7. **Verify**: `pnpm --filter <workspace> build` (the fix's workspace is enough; full `pnpm build` if time allows).
8. **Push — watch the tag collision**: erp-admin creates a tag with the SAME name as each release branch, so a bare `git push origin release/<date>` fails with `error: src refspec release/<date> matches more than one`. Use the full refspec:
   ```bash
   git push origin refs/heads/release/<date>
   ```
9. `git checkout develop` and confirm the working tree is clean (`git status --short`).

## Pitfalls

- **The WIP stash may BE the fix.** A broken develop after a merged refactor often coincides with the user's half-finished fix sitting in a stash. Before writing anything, `git stash list` + `git stash show -p` and compare hunks to the tsc errors — if they match exactly, pop, build, and commit instead of re-inventing. (Observed: 3 tsc errors ↔ 3 stash hunks, one-to-one.)
- **Ambiguous refspec on push**: any same-named tag breaks `git push origin <branch>`; always `refs/heads/<branch>` for release branches in this repo.
- **Cherry-pick vs merge**: porting a single fix = cherry-pick. Merging develop wholesale drags unreleased work into the release branch.
- **Verify after cherry-pick**: a clean cherry-pick can still fail typecheck if the release branch has diverged code; run the filtered build before pushing.

## Verification ladder

1. Filtered build (`pnpm --filter <workspace> build`) on release after cherry-pick.
2. Push success (full refspec), then `git checkout develop` clean.
