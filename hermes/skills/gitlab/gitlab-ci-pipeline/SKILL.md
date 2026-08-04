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
  stages: scan → triggers → dast-scan
  trigger:<app>  (x7: shell, hr, dashboard, employee, finance, product, sale)
      → each triggers .gitlab/ci/child-template.gitlab-ci.yml (strategy: depend)

.gitlab/ci/child-template.gitlab-ci.yml   # child pipeline per app
  stages: build → deploy
  build:app  (extends .build_job)          # docker build+push image tagged $CI_COMMIT_SHORT_SHA
  deploy:app (extends .deploy_job, needs: build:app)  # yq update helm image.tag + git push [skip ci]
```

- **Branches:** `develop` → UAT (`erp.vppos.vn` / `api-erp.vppos.vn`); `main` → PROD (`erp.hilo.com.vn`).
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
