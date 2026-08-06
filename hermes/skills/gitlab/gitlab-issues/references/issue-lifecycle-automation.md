# Issue Lifecycle Automation (erp-admin) — design & implementation notes

Session 2026-08-05. MRs: !538 (manual pilot, superseded), !541 (UAT-deploy-triggered + release/v* prod wiring), !542 (final: merge → done, prod → close), !543 (merge scan via API + skip release MRs), + direct commit `c2c78140` (keyword-adjacent issue refs).

## User's lifecycle model
- `status::done` = implementation merged to develop, UAT-ready — issue stays **OPEN**
- `closed` = released to production (deployed)
- `status::todo` / `in-progress` / `review` = unfinished; never auto-promoted
- Milestone = release bucket (SemVer `v1.0.0` first; CalVer → SemVer migration), due date = release day
- Release/tag = "đã release"; milestone = "dự định release"

## Why earlier designs failed (do not regress)
1. **Milestone-wide flip after UAT deploy** — force-set ALL opened milestone issues to done; in-progress issues (#133/#132/#128 in the v1.0.0 dry-run log) would be marked done while unfinished. Root cause: script never checked the current status label; the reviewer validated only count/list, not status semantics.
2. **UAT-deploy-triggered per-MR marking** — when several devs merge close together, the auto pipelines get cancelled and ONE manual pipeline deploys everything; `CI_COMMIT_MESSAGE` = last merge only → earlier MRs' issues never marked. `done` must be a function of MERGE, not deploy.
3. **Self-referential false positives** — an MR that DOCUMENTS a false positive ("đề xuất sai #108/#109 …" in !543) re-triggers it once merged: the parser sees a line with keyword `issue` + `#NNN` and can't read negation. Dry-run looked clean only because the MR wasn't merged yet (outside the scan window). Fixed via keyword adjacency (commit `c2c78140`). Rule: MR/commit descriptions about the lifecycle tooling must NOT put `#NNN` near a ref keyword — write bare numbers ("108/109").
4. **Release MR snapshot lines now fail adjacency too** — lists like "Issue mới còn mở, không đưa vào phạm vi deploy lần này: #95, #107…" sit >25 chars from the keyword → no match even if the release-label skip regresses. Double protection.

## Final design (!543 + `c2c78140` state)

### merge mode (develop pipeline, stage `lifecycle` BEFORE the deploy gate)
1. Collect MR iids: `GET /merge_requests?state=merged&scope=all&order_by=updated_at&sort=desc&per_page=50`, keep `merged_at` within `LIFECYCLE_MR_WINDOW_DAYS` (default 7). Skip MRs with label `release` (their descriptions carry issue SNAPSHOT sections — "còn mở, không đưa vào phạm vi: #NNN" — that would falsely mark pending issues done; verified dry-run bug: !520 proposed #108/#109). `CI_COMMIT_MESSAGE` kept as fallback only for the just-merged MR (git log is unreliable on `GIT_DEPTH=20` shallow checkouts — the old scan missed 4 of 5 merge commits).
2. Per MR: description → issue refs. **`#NNN` refs only count when a reference keyword sits within 25 chars before them** (`ADJACENT_REF_RE`: `(?:issue|ticket|closes|fixes|resolves|implements)[^\d\n#]{0,25}#(\d+)`), skipping `blocked` lines. URL refs (`/-/work_items/N`, `/-/issues/N`) still count with keyword anywhere on the line.
3. Per issue (opened only): remove `status::todo|in-progress|review|done`, add `status::done`, PUT labels. Idempotent — skip if already exactly `status::done`.
4. `DRY_RUN=true` default: prints `[merge] issue #N -> {...}` only.

### prod mode (release/v* pipeline, stage `post-deploy`)
1. Milestone auto-detect: `RELEASE_MILESTONE` env → `CI_COMMIT_TAG` (v*) → `CI_COMMIT_BRANCH` (`release/v1.0.0` → `v1.0.0`) → `package.json` version.
2. List opened issues in milestone; CLOSE only those whose labels contain `status::done`; skip others with a printed reason.
3. Runs only after real prod deploy: `.deploy_job` on `release/v*` is `when: manual` + `allow_failure: false` → child pipeline does not pass until every app deploy succeeded → parent triggers (strategy: depend) → post-deploy.

## CI wiring summary
- `.gitlab-ci.yml` stages: `scan → lifecycle → gate → triggers → post-deploy → dast-scan`
- `issue:lifecycle:merge`: stage `lifecycle`, `rules: if: '$CI_COMMIT_BRANCH == "develop"'`, MODE=merge
- `issue:lifecycle:prod`: stage `post-deploy`, `rules: if: '$CI_COMMIT_BRANCH =~ /^release\/v/'`, MODE=prod
- `trigger:*`: first rule `$CI_COMMIT_BRANCH =~ /^release\/v/` with NO `changes:` filter (release = build ALL apps), then develop/main + changes
- `base.gitlab-ci.yml`:
  - `.build_job` prod env for `main || release/v*` via POSIX prefix test `[ "${CI_COMMIT_BRANCH#release/v}" != "$CI_COMMIT_BRANCH" ]` (docker:26.1 image shell is ash — no bash `[[ ]]`)
  - `.deploy_job` `release/v*` rule: `when: manual` + `allow_failure: false` (blocking)
- Both jobs `test -n "$GITLAB_AUTOMATION_TOKEN"` first (CI/CD variable, masked + protected)
- CI variables: `GITLAB_API_URL=https://gitlab.vppos.vn/api/v4`, `GITLAB_PROJECT_ID="9"` hardcoded in YAML (masked variables need ≥ 8 chars)

## GitLab UX pitfalls (pilot phase)
- Manual job variables: pipeline-graph ▶ starts the job instantly (no dialog). After fail → job detail → **Retry ▾ → "Run with variables"** → add variable → run.
- `CI_COMMIT_MESSAGE` on a manual "run pipeline" = develop HEAD's commit message.

## Team convention
MR description must reference its issue: `Issue / Ticket: #NNN` or `Closes #NNN` — automation source. Feature MRs to develop should use non-closing refs (`Implements #N`) so issues stay open until prod.
