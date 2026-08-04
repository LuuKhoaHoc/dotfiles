# erp-admin weekly release checklist (SemVer)

Project: `vppos-team/erp-admin` (`project_id=9`)  
Local path: `/home/luukhoahoc/Projects/Hilo-Vppos/erp-admin`

Naming: branch `release/vX.Y.Z`, tag `vX.Y.Z`, Release name `Release vX.Y.Z — YYYY-MM-DD`.

## Preflight

- [ ] No open mistaken MR `develop → main`
- [ ] Bump root `package.json` version on develop (step 0: minor/patch/major theo SemVer)
- [ ] Biết version release: `vX.Y.Z` (branch `release/vX.Y.Z`, tag `vX.Y.Z`)
- [ ] Stash local WIP on `develop` if dirty
- [ ] `git fetch origin`

## Branch + merge

- [ ] `release/vX.Y.Z` created from **`origin/main`** (not develop — đừng chạy `pnpm git:release` khi đang trên develop)
- [ ] `git merge origin/develop` into release branch (mang theo commit bump version)
- [ ] Conflicts resolved (typical: `helm/frontend/values-*.yaml` → take develop image tags)
- [ ] Push branch: `git push origin refs/heads/release/vX.Y.Z`

## Tag + Release page

- [ ] Tag `vX.Y.Z` points at **release HEAD after develop merge** (không trùng tên branch)
- [ ] Push tag: `git push origin refs/tags/vX.Y.Z` (avoid ambiguous refspec)
- [ ] GitLab Release notes published/updated — name `Release vX.Y.Z — YYYY-MM-DD`
- [ ] Evidence JSON on Releases UI is expected (ignore)

## Ship

- [ ] MR `release/vX.Y.Z → main` with label `release`, structured description
- [ ] `mergeable` / no conflicts
- [ ] UAT pass confirmed (nếu có thay đổi user-facing) → pipeline green → merge
- [ ] Sync `main → develop` after production merge

## Changelog sources

- Commits on develop not in main (skip noisy image-tag chores)
- Merged MRs titles when available
