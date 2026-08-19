# Stale local `develop` ref → false "extra scope" flags in MR review

## Symptom

Reviewing a branch worktree with `git diff develop...HEAD --stat` shows files/commits that are NOT in the MR's GitLab diff (e.g. changes from OTHER merged MRs: feature code, layout tweaks, helm image-tag bumps). You flag them as "extra scope" — the user pushes back because GitLab shows none of them ("sao tui có thấy cái nào liên quan đến extra scope đâu ta").

## Root cause

`git diff develop...HEAD` resolves `develop` to the **LOCAL ref** of the worktree (or main clone), which can lag behind remote develop by many commits. Commits merged via OTHER MRs are then included as if they were on the feature branch. GitLab's MR diff instead computes its own merge-base (`diff_refs.base_sha`) against the CURRENT remote target branch — so it does NOT show those already-merged commits.

Same class as the stale-base trap (mirror image): there the local ref is NEWER than the branch base; here the local ref is OLDER than the remote target.

## Verified diagnosis sequence (real case MR !610, 2026-08-17)

```bash
git fetch origin <branch> develop          # STEP 1 — always fetch first

# STEP 2 — stale ref detection: values differ ⇒ local ref unreliable
git rev-parse develop                      # e.g. c2df0dc3  (stale)
git rev-parse origin/develop               # e.g. 3d568b9b  (remote truth)

# STEP 3 — true MR commits (the ONLY authoritative list)
git log origin/develop..origin/<branch> --oneline

# STEP 4 — per-suspicious-commit verdict; exit 0 = already in MR base ⇒ NOT part of this MR
git merge-base --is-ancestor <sha> <MR-base_sha> && echo "IN BASE — don't flag"
```

`MR-base_sha` comes from MCP `get_merge_request` → `diff_refs.base_sha`.

## Real case facts (MR !610)

- Local `develop` = `c2df0dc3`, `origin/develop` = `3d568b9b`, MR `base_sha` = `3d389095`.
- `git diff develop...HEAD` showed 45 files; the true MR was 7 commits / memberships-only files.
- False "extra scope": employee cancel action (`469ad9395`), shell topbar layout (`50d4ca154`), helm image-tag bumps (`7baeaee70`) — all ancestors of the MR base via other MRs.
- After correction: the MR diff file list matched GitLab exactly, review closed with the real remaining findings only.

## Rule

Never flag "extra scope" (or any scope claim) from a diff against a non-fetched local ref. Fetch first, diff against `origin/<target>`, and attribute commits before flagging.