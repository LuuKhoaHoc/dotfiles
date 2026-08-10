---
name: gitlab-pipeline-ops
description: "Use when operating GitLab CI deploys/releases via glab API."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitLab, CI, CD, Pipeline, deploy, release, glab, erp-admin]
    related_skills: ["gitlab-ci-pipeline", "gitlab-release", "issue-ship"]
---

# GitLab Pipeline Ops (erp-admin) — drive deploys & releases at runtime

Use when the code is merged and you must OPERATE the pipeline: play manual gates, wait for child
pipelines, deploy UAT/prod, or run a release closeout. Complement to `gitlab-ci-pipeline` (editing
YAML) and `gitlab-release` (weekly release). Project: `gitlab.vppos.vn` → `vppos-team/erp-admin`.

## Pipeline anatomy (runtime view)

- Parent pipeline per branch push/merge: stages `scan → lifecycle → gate → triggers → post-deploy`.
- `deploy:uat` gate (manual, `allow_failure: false`) blocks the `triggers` stage until played.
- `trigger:<app>` × 7 → child pipelines (`build:app` → `deploy:app`). Child `deploy:app` is
  `when: manual` on prod (`main`/`release/v*`); on develop children auto-deploy after the gate.

## Driving steps (verified 2026-08-08, hotfix v1.0.1 + v1.0.2)

1. **Find the pipeline:** `glab api "projects/vppos-team%2Ferp-admin/pipelines?ref=<branch>&per_page=3"`
   → python json. Merge creates a NEW merge-commit SHA on the target — `git fetch` +
   `git ls-remote origin <branch>` for the real head. `glab mr view` may still say `opened`
   seconds after merge — re-query.
2. **Manual gate jobs live in `/pipelines/:id/jobs`** (`status: manual`, e.g. `deploy:uat`).
   Play: `glab api --method POST "projects/vppos-team%2Ferp-admin/jobs/<id>/play"` → `pending`.
3. **Triggers are BRIDGES, not jobs** — read `GET /pipelines/:id/bridges` for
   `downstream_pipeline.id`; do NOT rely on parent status alone.
4. **`changes:` decides scope:** fix touching only `apps/hr/**` → only `trigger:hr` runs;
   `packages/**` change → all 7. Predict scope before telling the user how long it takes.
5. **Poll children:** `GET /pipelines/<id>` per child (running/pending/manual/success).
   Runners are scarce — 7 apps build serially, budget 15–25 min. Prod: after `build:app`
   success, play each child's `deploy:app` (manual) from that child's `/jobs`.
6. **Harmless red herring:** pushing `release/vX.Y.Z` starts a branch pipeline; after the MR
   merge deletes the branch, its late children fail `fatal: couldn't find remote ref
   refs/heads/release/v1.0.1`. That is the BRANCH pipeline — ignore; drive the MAIN-branch
   children instead.
7. **Verify deploy landed:** curl the target (`https://hr-uat-erp.vppos.vn/` etc.) — a short
   502 burst right after deploy is normal (pod rollout); persists >5 min → check with infra.

## Release closeout (vX.Y.Z) — after UAT pass, before/at prod deploy window

1. Bump: python string-replace `"version": "1.0.1"` in root `package.json` (keep CRLF —
   `newline=''`), commit `chore(release): v1.0.2` on develop, push (`--no-verify` if corepack
   hooks broken — pre-commit/pre-push run `pnpm dlx`, which fails on this Windows box).
2. `git checkout -b release/v1.0.2 origin/main` → `git cherry-pick <fix SHAs>` (conflict-free
   when develop-only fix commits; NEVER merge develop). Verify `git diff origin/main..HEAD --stat`
   contains ONLY intended files + version bump.
3. `git tag -a v1.0.1 -m ... && git push origin refs/tags/v1.0.1`; create Release record:
   `glab api --method POST ".../releases" -f tag_name=... -f name=... -f description=<notes>`.
4. MR release branch → main (`--label "release"`, assignee = real username via
   `glab api user | python3` — `--jq` unsupported). Merge with
   `glab mr merge <iid> --when-pipeline-succeeds` (background, it exits after submit).
5. After prod children all success: sync `git checkout develop && git merge origin/main
   --no-verify --no-edit && git push` — then check CRM modules NOT disabled in
   `packages/shared/src/config/navigation.ts` (`enabled: false` only for inventory/marketing).
6. Update Release description checklist (GET → python replace `- [ ]` → `- [x]` → PUT with
   `-f description="$(cat file)"`), then `glab issue close <iid>` + close milestone via
   `PUT /milestones/<id> -f state_event=close`. Issue stays open until PROD deploy done.

## Pitfalls

- `glab ci list` is flaky — use `glab api ".../pipelines?ref=..."` + python.
- `glab mr update --assignee <empty>` is a silent no-op (empty `GLAB_USER`).
- Windows/MSYS: python scripts need `$(cygpath -w <path>)` for skill-dir paths.
- git status messages like "1 matches in 1 files" with no content = MSYS grep/head reading CRLF
  files — use `git show HEAD:<path>` or read_file instead of trusting head.
- Pinned/milestone issue updates: use `glab issue update` with heredoc file
  (`--description "$(cat file)"`) — works with UTF-8 Vietnamese.
