# One-click UAT deploy gate — worked example (MR !499)

Problem: deploying UAT required clicking 7 manual `deploy:app` buttons (one per MFE child pipeline).
Goal: one button for UAT; **prod (`main`) unchanged** (keep per-app manual, controlled rollout).

## Change 1 — `.gitlab-ci.yml` (parent): add gate stage + gate job (develop only)

```yaml
stages:
  - scan
  - gate            # ⬅️ added between scan and triggers
  - triggers
  - dast-scan

# ─── ONE-CLICK UAT DEPLOY GATE (develop only) ───
deploy:uat:
  stage: gate
  image: alpine:3.20
  tags:
    - erp-admin
  script:
    - echo "✅ Duyệt deploy UAT cho các MFE thay đổi (SHA ${CI_COMMIT_SHORT_SHA})"
  rules:
    - if: '$CI_COMMIT_BRANCH == "develop"'   # ⬅️ develop ONLY, not main
      when: manual
  allow_failure: false                        # ⬅️ REQUIRED: blocks `triggers` stage until clicked
```

`trigger:<app>` jobs are left untouched (still gated by their `changes:` rules), so only apps that
actually changed will run.

## Change 2 — `.gitlab/ci/base.gitlab-ci.yml`: split `.deploy_job` rules by branch

Before (applied to both branches — the bug the user caught):

```yaml
.deploy_job:
  # ...
  rules:
    - if: '$CI_COMMIT_BRANCH == "develop" || $CI_COMMIT_BRANCH == "main"'
      when: manual
```

After:

```yaml
.deploy_job:
  # ...
  rules:
    - if: '$CI_COMMIT_BRANCH == "develop"'   # UAT: auto-deploy after gate passes
    - if: '$CI_COMMIT_BRANCH == "main"'      # PROD: keep per-app manual
      when: manual
```

## Resulting flow

- `develop` push → scan → **1 button `deploy:uat`** → click → changed apps auto build+deploy to UAT.
- `main` push → scan → per-app manual `deploy:app` buttons (exactly as before). No prod behavior change.

## Verify via lint's merged_yaml

After `validate_project_ci_lint(content_ref=<branch>)` confirm in `merged_yaml`:
- `deploy:uat` has ONLY the `develop` rule.
- `.deploy_job` (and each `deploy:app`) has TWO rules: develop (no `when`, = on_success/auto) and
  main (`when: manual`).

## Trade-off accepted

Build happens AFTER the gate click (not pre-built). Saves runner minutes; downside is build errors
surface only after approving. If you need pre-build + one deploy button, that's "Solution B":
move all helm-tag updates into a single parent-level deploy job / one commit, which also lets you
delete the `MAX_RETRIES=5` race-condition retry loop. Left out of scope for MR !499.
