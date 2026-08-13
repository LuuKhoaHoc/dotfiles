---
name: gitlab-pipeline-operations
description: "Use when operating GitLab CI pipelines via REST API."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitLab, CI/CD, Pipelines, REST-API]
    related_skills: ["gitlab-release", "gitlab-issue-workflow"]
---

# GitLab Pipeline Operations (erp-admin / vppos)

Use when operating GitLab CI/CD pipelines over the REST API: retrying/canceling/creating pipelines, diagnosing "job never ran", or hitting 409 when creating an MR after pushing a branch. Complements `gitlab-release` (release flow) and `gitlab-issue-workflow` (issue lifecycle automation) — those are user-owned; this one is the operations reference.

Token access pattern (never print the token):

```bash
TOKEN=$(cat ~/.config/glab-cli/config.yml 2>/dev/null | grep -oP '(?<=token: ).*' | head -1)
# hoặc: python3 -c "import yaml; c=yaml.safe_load(open('$HOME/.config/glab-cli/config.yml')); print(c['hosts']['gitlab.vppos.vn']['token'])"
curl -s --header "PRIVATE-TOKEN: $TOKEN" "https://gitlab.vppos.vn/api/v4/..."
```

Project: `vppos-team/erp-admin` = project_id `9`. Base URL luôn `/api/v4` (không phải `/api/v1` — đó là BE ERP).

## Pitfalls & techniques (verified 2026-08-07, release v1.0.0)

### 1. Push branch → GitLab auto-creates MR → `create_merge_request` 409

Pushing a branch to remote (vd `release/vX.Y.Z`) makes GitLab auto-create an MR (title mặc định, target theo default branch rules). Creating the MR via MCP then fails:

```
409 Conflict: Another open merge request already exists for this source branch: !NNN
```

**Fix:** `get_merge_request(merge_request_iid=!NNN)` → `update_merge_request` with the correct title/description/labels. Verify `detailed_merge_status: mergeable` afterwards.

### 2. Pipeline auto-cancel + retry API is a NO-OP on canceled pipelines

- GitLab auto-cancels an older pipeline when a newer one appears for the same ref/SHA (vd push pipeline bị cancel khi MR pipeline chạy).
- `POST /pipelines/:id/retry` on a **canceled** pipeline returns the pipeline **unchanged (still canceled)** — no retry happens, no error is raised. Don't loop retries.
- **Working alternative:** create a fresh pipeline: `POST /projects/9/pipeline?ref=<branch>` → returns new pipeline id. Variables are re-evaluated at creation (see §3).
- A fresh API-created pipeline (`source=api`) may contain a DIFFERENT job set than the original push pipeline (rules can depend on `CI_PIPELINE_SOURCE`/branch). Inspect what actually got created before assuming it will redeploy anything.

### 3. GitLab snapshots CI/CD variables at pipeline creation time

- Project CI/CD variables (Settings → CI/CD → Variables) **override** same-named variables declared in `.gitlab-ci.yml` job-level blocks.
- BUT the value is **snapshotted when the pipeline is created** — a variable added *after* the pipeline was created does NOT apply to it. Sequence that works: set variable first → then create/retrigger the pipeline. Re-running an old pipeline keeps the old value.
- Real case: `issue:lifecycle:prod` declares `DRY_RUN: "true"` in YAML; user added `DRY_RUN=false` as a project variable → only pipelines created AFTER that get the override.

### 4. `GET /pipelines/:id/jobs` hides trigger (downstream) jobs

- `trigger:*` jobs (downstream triggers) do NOT appear in `GET /pipelines/:id/jobs` — a parent pipeline that visibly has 7 triggers can list only 1 job (`issue:lifecycle:prod`). This looks like a misconfiguration; it isn't.
- Use `GET /projects/:id/pipelines/:pipeline_id/statuses` (MCP `list_commit_statuses` with `sha` + `pipeline_id`) for the full job picture including `trigger:*`.
- `GET /pipelines?ref=<branch>` + `per_page` for recent pipelines per ref; `GET /pipelines/:id` for status (status values: `running`, `created`, `canceled`, `success`, `skipped`, `failed`).

### 5. Cancel API is async; verify after a few seconds

`POST /pipelines/:id/cancel` returns the pipeline with status still `running` — the cancel is processed asynchronously. Re-fetch the pipeline after ~10s to confirm `canceled`.

### 6. Job waiting on runner while builds run

A single shared runner (instance runner with tag `erp-admin`) picking jobs one at a time means a `post-deploy` job can sit `created` for many minutes while MFE build jobs run. Check runner status: `GET /projects/:id/runners` (fields: `online`, `status`, `tag_list`, `runner_type`) — `tag_list` may appear `None` at project level but full on `GET /runners/:id`. Don't kill the pipeline over a waiting job; wait for the runner queue.

## Diagnostic recipe (job never runs)

1. `GET /pipelines/:id/jobs` — see what's scheduled (remember: triggers hidden, see §4).
2. `GET /projects/:id/pipelines/:pipeline_id/statuses` — full set incl. `trigger:*`.
3. `GET /projects/:id/runners` — runner online? has the required tag? busy?
4. If job `created` and runner free but stuck >5 min: check rules in `.gitlab-ci.yml` (branch/source match) — rules mismatch = job never created at all, not stuck.

## Related

- Release flow + post-deploy lifecycle run: `gitlab-release` (user-owned) — the release skill's "issue:lifecycle:prod only runs on `release/v*` branches" design is what makes §2–§4 relevant.
- Case detail: `references/pipeline-operations-case-2026-08-07.md`.
