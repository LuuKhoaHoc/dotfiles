# Issue Lifecycle Automation Reference (erp-admin)

Session 2026-08-05. MRs: !538 (manual pilot, superseded), !541 (UAT-deploy-triggered + release/v* wiring), !542 (final: merge → done, prod → close).

## Project convention

- `status::done` = implementation merged to `develop`, UAT-ready — issue stays **opened**.
- `closed` = production deployment succeeded (closed by post-prod automation).
- Feature MRs targeting `develop` must NOT use `Closes #N` — empirically (MR !537) `Closes #131` on a develop MR auto-closed the issue (develop acts as the closing branch). Use `Issue / Ticket: #N` / `Implements #N` / `Related to #N`.
- Release milestone `vX.Y.Z` is the batch source of truth (weekly SemVer planning: plan scope → create milestone → assign issues → release).

## Why earlier designs failed (do not regress)

1. **Milestone-wide status flip after UAT deploy** — force-set ALL opened milestone issues to `done`; the v1.0.0 dry-run listed in-progress #133/#132/#128. Only touch issues REFERENCED by the merged MR.
2. **UAT-deploy-triggered per-MR marking** — several devs merge at once → auto pipelines get cancelled → ONE manual pipeline deploys everything; `CI_COMMIT_MESSAGE` = last merge only → earlier MRs' issues never marked. `done` must be a function of MERGE, not deploy.

## Final design (MR !542 state)

### merge mode — `issue:lifecycle:merge` (develop pipeline, stage `lifecycle` BEFORE the deploy gate)
1. Collect MR iids: `!(\d+)` from `CI_COMMIT_MESSAGE` + `git log -n 30 --format=%B` (shallow checkout; a later pipeline re-scans and catches MRs whose pipelines were cancelled — the robustness trick).
2. Per MR: `GET /projects/:id/merge_requests/:iid` → description → issue refs from lines containing `issue|ticket|closes|fixes|resolves|implements` (lowercased), skipping lines containing `blocked` ("References"/"Related to" sections ignored).
3. Per issue (opened only): remove `status::todo|in-progress|review|done`, add `status::done`, PUT the FULL label set (GitLab replaces the set). Idempotent — skip if already exactly `status::done`.
4. `DRY_RUN=true` default: prints `[merge] issue #N -> {...}` only.

```yaml
issue:lifecycle:merge:
  stage: lifecycle          # after scan, BEFORE deploy:uat gate → deploy-independent
  image: python:3.12-alpine
  tags: [erp-admin]
  variables:
    ISSUE_LIFECYCLE_MODE: "merge"
    DRY_RUN: "true"
  script:
    - test -n "$GITLAB_AUTOMATION_TOKEN" || { echo "❌ Thiếu GITLAB_AUTOMATION_TOKEN (CI/CD variable)"; exit 1; }
    - python3 scripts/gitlab-update-milestone-issues.py
  rules:
    - if: '$CI_COMMIT_BRANCH == "develop"'
```

### prod mode — `issue:lifecycle:prod` (release/v* pipeline, stage `post-deploy`)
1. Milestone auto-detect (user requirement — NO manual variables): `RELEASE_MILESTONE` env → `CI_COMMIT_TAG` (v*) → `CI_COMMIT_BRANCH` (`release/v1.0.0` → `v1.0.0`) → `package.json` version (develop carries the upcoming SemVer version). Fail loudly if nothing derivable.
2. List opened issues in milestone; CLOSE only those whose labels contain `status::done`; skip others with a printed reason.
3. Runs only after REAL prod deploy: `.deploy_job` on `release/v*` is `when: manual` + `allow_failure: false` → child pipeline does not pass until every app deploy succeeded → parent triggers (`strategy: depend`) → `post-deploy`.

## CI wiring (release/v* = first-class PROD deploy branch, MR !541/!542)
- `.gitlab-ci.yml` stages: `scan → lifecycle → gate → triggers → post-deploy → dast-scan`
- `trigger:*`: FIRST rule `$CI_COMMIT_BRANCH =~ /^release\/v/` with NO `changes:` filter (release = build ALL apps), then develop/main + changes
- `base.gitlab-ci.yml`:
  - `.build_job` prod env for `main || release/v*` via POSIX prefix test `[ "${CI_COMMIT_BRANCH#release/v}" != "$CI_COMMIT_BRANCH" ]` — the runner shell is ash (docker:26.1), NO bash `[[ ]]`
  - `.deploy_job` `release/v*` rule: `when: manual` + `allow_failure: false` (blocking — this is what makes "post-deploy runs only after prod deploy finished" true)
- Production close on `main` is NOT used — the user's flow deploys prod from the `release/v*` branch pipeline.

## CI variables
`GITLAB_API_URL=https://gitlab.vppos.vn/api/v4` and project ID `9` are non-secret — hardcode in `.gitlab-ci.yml` `variables:`. Only `GITLAB_AUTOMATION_TOKEN` goes in Project → Settings → CI/CD → Variables as **masked + protected** (scope `api`).

**Masked pitfall:** masked variables require ≥8 characters — `GITLAB_PROJECT_ID=9` fails with "The value must have 8 characters." Do NOT pad the value to fake it; keep short non-secret values unmasked or in YAML.

## GitLab UI quirks (user-confirmed)
- Clicking ▶ on a `when: manual` job starts it IMMEDIATELY — the variables popup does NOT appear on first click.
- The variables popup only appears on retry: ▶ → fail → open job detail → **Retry ▾ → "Run with variables"** → Add variable → Run.
- If users keep hitting this, the fix is to eliminate the input (auto-derive milestone), not to document the click flow.

## Validation
- `mcp__gitlab__validate_project_ci_lint(content_ref=<branch>)` — require `valid: true`, 0 errors/warnings; inspect `merged_yaml` resolved `rules:`/`when:` per job (the auto job must resolve `when: on_success`).
- `dry_run: true` on that tool can transiently return `merged_yaml: Expected string, received null` — retry without `dry_run`; plain lint still validates.

## Team convention
MR description must reference its issue: `Issue / Ticket: #NNN` or `Closes #NNN` — the automation source for `status::done`.
