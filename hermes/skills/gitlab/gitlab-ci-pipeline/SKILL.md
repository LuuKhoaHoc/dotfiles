---
name: gitlab-ci-pipeline
description: "Read, edit, and validate GitLab CI/CD pipelines for the erp-admin MFE monorepo — parent orchestrator + child pipelines, per-app manual deploys, deploy gates, branch-scoped rules. Edit via MCP, lint before MR."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitLab, CI, CD, Pipeline, erp-admin, MFE, Deploy, Merge-Request]
    related_skills: ["gitlab-release", "gitlab-issues"]
---

# GitLab CI/CD Pipeline Editing (erp-admin / vppos)

Use when the user wants to change how the CI/CD pipeline builds or deploys — add/remove deploy steps,
collapse manual buttons, change triggers, gate stages, adjust `rules:` / `changes:`, tune caching.
Project: `gitlab.vppos.vn` → `vppos-team/erp-admin` (`project_id=9`).

## Pipeline architecture (verified)

Parent orchestrator + child pipelines, 7 MFE apps.

```text
.gitlab-ci.yml                        # parent orchestrator
  include:
    - .gitlab/ci/base.gitlab-ci.yml   # .cache_base .test_base .base_job .build_job .deploy_job (templates)
    - vppos-shared/cicd-library-for-scare-vulubility  # trivy / sonarqube / owasp-zap scanners
  stages: scan → lifecycle → gate → triggers → post-deploy → dast-scan
  trigger:<app>  (x7: shell, hr, dashboard, employee, finance, product, sale)
      → each triggers .gitlab/ci/child-template.gitlab-ci.yml (strategy: depend)

.gitlab/ci/child-template.gitlab-ci.yml   # child pipeline per app
  stages: build → deploy
  build:app  (extends .build_job)          # docker build+push image tagged $CI_COMMIT_SHORT_SHA
  deploy:app (extends .deploy_job, needs: build:app)  # yq update helm image.tag + git push [skip ci]
```

- **Branches:** `develop` → UAT (`erp.vppos.vn` / `api-erp.vppos.vn`); `main` AND `release/v*` → PROD (`erp.hilo.com.vn`). Since MR !541, `release/v*` is a first-class prod deploy branch: `.build_job` treats `main || release/v*` as prod env, `trigger:*` get a first rule for `release/v*` with NO `changes:` filter (release = build ALL apps), `.deploy_job` on `release/v*` is `when: manual` + `allow_failure: false`.
- **Deploy mechanism = GitOps:** `deploy:app` bumps `helm/frontend/values-<app>.yaml` `image.tag` and
  git-pushes with `[skip ci]`; an external ArgoCD/Flux syncs it. CI does NOT `kubectl apply` directly.
- **Why 7 manual buttons exist:** `deploy:app` inherits `when: manual` from `.deploy_job`, so each of the
  7 child pipelines has one manual deploy button.
- **Why all 7 fire on any packages change:** every `trigger:<app>` lists `packages/**/*` in its `changes:`.

## Core technique: one manual gate to collapse N per-app manual deploys

GitLab stage semantics: a **manual job with `allow_failure: false` in an earlier stage blocks the entire
next stage** until clicked. Use this to replace N per-app manual buttons with ONE gate.

1. Add a `gate` stage between `scan` and `triggers`.
2. Add one manual gate job (`allow_failure: false`) in `gate` — clicking it releases the whole `triggers` stage.
3. Remove `when: manual` from the per-app deploy so children auto-run once the gate passes.

Trade-off: build now happens AFTER the click (not pre-built). Usually fine / saves runner minutes.
See `references/one-click-deploy-gate.md` for the exact diff applied on MR !499.

## ⚠️ Pitfall: shared templates apply to BOTH develop and main (user-caught, MR !499)

`.deploy_job` (and `.trigger_template`) `rules:` originally matched
`$CI_COMMIT_BRANCH == "develop" || == "main"`. A change intended only for UAT (auto-deploy after gate)
**silently also changed PROD behavior.** The user asked "chỉ ảnh hưởng uat thôi hay cả prod nữa?" — always
answer this BEFORE editing a shared template.

Rule: **when editing a shared CI template, check every branch its `rules:` matches.** Scope UAT and PROD
separately. Correct pattern used:

```yaml
# .deploy_job rules — develop auto (after gate), main stays per-app manual (controlled rollout)
rules:
  - if: '$CI_COMMIT_BRANCH == "develop"'          # UAT: auto-deploy
  - if: '$CI_COMMIT_BRANCH == "main"'             # PROD: keep manual
    when: manual
```

And scope the gate job itself to `develop` only (`- if: '$CI_COMMIT_BRANCH == "develop"'`).
PROD should keep granular per-app control (e.g. ship `sale` but hold `hr` until QA done); never
auto-mass-deploy everything to prod with one click.

## Build-fail safety reasoning (answer users confidently)

Because `deploy:app` has `needs: [build:app]`: build fail → deploy does NOT run → helm `image.tag`
unchanged → nothing git-pushed → GitOps has nothing to sync → **running pods keep the old image.**
A single app's build failure does not affect the other apps. (Runtime crashes of a *successfully built*
image are a separate k8s rolling-update / readiness-probe concern, unrelated to CI.)

## Issue lifecycle automation workflow

For this ERP project, separate implementation completion from production release:

- `status::done` = code merged into `develop` and UAT-ready; issue remains `opened`.
- `closed` = production deployment succeeded; keep `status::done`.
- Feature MRs targeting `develop` must use non-closing references such as `Issue / Ticket: #N` / `Implements #N` / `Related to #N`, not `Closes #N` (empirically, `Closes #N` on a develop MR auto-closes the issue on merge).
- Release milestones (`vX.Y.Z`) are the per-release batch source of truth; `issue:lifecycle:prod` closes only `status::done` issues of the milestone.

**Final job layout (MR !542 — do NOT regress to earlier designs):**

- `issue:lifecycle:merge` — stage `lifecycle` (after scan, BEFORE the `deploy:uat` gate), `rules: $CI_COMMIT_BRANCH == "develop"`. Marks `status::done` on issues referenced by MRs found in `CI_COMMIT_MESSAGE` + `git log -n 30` (per-MR, idempotent). **`done` attaches to MERGE, not deploy** — deploy-triggered marking fails when several MRs merge at once, auto pipelines get cancelled and one manual pipeline deploys everything (only the last MR would be seen).
- `issue:lifecycle:prod` — stage `post-deploy`, `rules: $CI_COMMIT_BRANCH =~ /^release\/v/`. Closes milestone issues already `status::done`; fires only after real deploy because `.deploy_job` on `release/v*` is `when: manual` + `allow_failure: false` (child pipeline doesn't pass until every app deploy succeeded).
- **Never milestone-wide status flips** — the first design marked ALL opened milestone issues `done` after UAT deploy, force-flipping in-progress issues (real incident: v1.0.0 dry-run listed #133/#132/#128). Only touch issues referenced by the merged MR.

Safe rollout: both jobs default `DRY_RUN=true`; confirm the dry-run log lists exactly the intended issues, then flip `DRY_RUN=false`. **Status 2026-08-05:** merge job is LIVE (`DRY_RUN=false`, commit `e2612b21`); prod job still `DRY_RUN=true`. **Do NOT require manual `RELEASE_MILESTONE` input** — user rejected that friction ("automation rồi mà vẫn phải manual nhập variables"); the script auto-derives the milestone (env override → CI tag `v*` → `release/v*` branch → `package.json` version). Project ID `9` is public configuration — hardcode in YAML, never mask (masked vars need ≥8 chars). Only the GitLab API token is masked/protected. Keep initial user guidance operational and concise: exact next action, click/run location, and expected output; defer architecture details unless requested.

Use `references/issue-lifecycle-automation.md` for the tested API/script/job pattern and the failure history.

## ⚠️ Pitfall: DRY_RUN left on — job "succeeds" but writes nothing (real case 2026-08-05)

`issue:lifecycle:merge` ran with `DRY_RUN: "true"` for weeks (kept from the pilot commit when a88f971d
switched the job to merge-time). Logs showed `[merge] issue #133 -> {'labels': ...,'status::done'}`
and `Job succeeded` — but the PUT never fired, because the script `print()`s the payload BEFORE
`if not DRY_RUN: api("PUT", ...)`. Issues silently stayed `status::review`; nobody noticed until a
user asked "why isn't my issue done?".

**Detection recipe (cheap, deterministic):**
1. `curl .../projects/<id>/jobs/<job_id>/trace` — a `[merge] issue #N -> ...` line is a PRINT, not a write.
2. Cross-check `GET /projects/<id>/issues/<iid>` → `updated_at` MUST be ≥ the job's `finished_at`.
   Real case: issue updated_at 09:00:18 < job ran 09:01:47 → PUT never happened. (MCP `get_issue` is fine; the "stale" reading was actually the truth.)
3. Attribution: `GET /projects/<id>/issues/<iid>/resource_label_events` shows WHO changed labels —
   a human username = manual set, not the CI job.
4. Fix: flip `DRY_RUN=false` in `.gitlab-ci.yml`, push to develop (rebase first — develop moves fast),
   and the NEXT develop pipeline re-runs the job idempotently, catching up on all missed issues
   (script re-queries merged MRs in a 7-day window).

**Verifying a `.gitlab-ci.yml` change is NOT `pnpm typecheck/lint/build`** — it's a YAML file, not app
code. Correct verification: (a) `python3 -c "import yaml; yaml.safe_load(open('.gitlab-ci.yml'))"` +
assert the intended variable value; (b) `mcp__gitlab__validate_project_ci_lint` → `valid: true`, 0
errors, read `merged_yaml` for resolved `rules:`; (c) watch the real pipeline on the pushed commit run
the changed job and confirm the side effect actually happened (trace + target resource state).

## MCP edit → lint → MR workflow

1. Read current files at the right ref:
   `mcp__gitlab__get_file_contents(file_path, project_id, ref=<branch>)` for
   `.gitlab-ci.yml`, `.gitlab/ci/base.gitlab-ci.yml`, `.gitlab/ci/child-template.gitlab-ci.yml`.
2. `mcp__gitlab__create_branch(branch, ref=develop)`.
3. `mcp__gitlab__create_or_update_file(...)` — pass full file content; use the file's `last_commit_id`
   from the previous read to avoid clobbering.
4. **Always** `mcp__gitlab__validate_project_ci_lint(content_ref=<branch>)` before opening the MR.
   Check `valid: true`, 0 errors/warnings, and read the returned `merged_yaml` to confirm the resolved
   `rules:` per job are what you intend (this is where branch-scope bugs show up).
5. `mcp__gitlab__create_merge_request(source, target_branch=develop, remove_source_branch=true)`.
   Follow the erp-admin title/body conventions (see gitlab-issues memory: `[MODULE] Mô tả`, `## Mô tả`,
   `## Verification`, `## Out of scope`).

## Pitfalls / ops notes

- **MCP tools drop mid-session.** If `mcp__gitlab__*` returns "does not exist" or "server unreachable",
  re-activate with `mcp__gitlab__discover_tools(category=pipelines)` (or via `tool_search` +
  `tool_call`). After 3 identical failures the server enters a ~50s cooldown — wait, don't hammer.
- **`discover_tools category=pipelines`** adds: list/get_pipeline, list_pipeline_jobs,
  play_pipeline_job, retry/cancel, list_environments, list_deployments, download_job_artifacts, etc.
- Do NOT call `get_issue_link`/`list_issue_links` for a pipeline id — wrong tool, returns
  "issue_iid is invalid".
- Keep the retry loop (`MAX_RETRIES=5`) in `.deploy_job` while multiple child pipelines still git-push
  the same branch (race condition). It only becomes removable if you consolidate all helm-tag updates
  into ONE parent job / one commit (documented as future "Solution B", out of scope of the gate change).

## Related

- Release flow (develop→main, tags, release notes): `gitlab-release`
- Issues / task decomposition: `gitlab-issues`, `gitlab-project-management`
- Worked example diff: `references/one-click-deploy-gate.md`
