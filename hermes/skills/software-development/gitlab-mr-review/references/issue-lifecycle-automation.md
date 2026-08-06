# Issue Lifecycle Automation — MR Description Ref Extraction (erp-admin)

The `issue:lifecycle:merge` job (develop pipelines, `DRY_RUN: "false"`) auto-marks `status::done`
on issues referenced by merged MRs. It has failed silently TWICE — both failure modes look
identical from outside: "issue didn't auto-close after merge".

## Failure mode 1: DRY_RUN leftover (fixed 2026-08-05)
Job ran with `DRY_RUN: "true"` (pilot leftover): trace printed the PUT payload + `Job succeeded`
but the PUT never fired. See SKILL §9. Fix was flipping DRY_RUN in `.gitlab-ci.yml`.

## Failure mode 2: ref-extraction blind spot for work_items URLs (fixed 2026-08-05, commit `9ad19927`)
`issue_refs_from_text()` in `scripts/gitlab-update-milestone-issues.py`:
- `ISSUE_REF_RE = re.compile(r"#(\d+)")`, keyword-gated lines only (`issue/ticket/closes/fixes/resolves/implements`; `blocked` lines skipped).
- The standard MR template's `- **Issue / Ticket**: https://gitlab.vppos.vn/.../-/work_items/NNN` has **no `#` fragment** → regex finds nothing → `MR !540: 0 issue ref(s) from description` + `Job succeeded` + issue never updated.
- Symptom chain (real case, MR !540 → issue #128): merge 09:24 → job 09:25 `0 issue ref(s)` → human manually added `status::done` at 09:43.

Fix regexes — keep the `/-/` prefix, it's GitLab-specific and kills false positives (`docs/issues/7`, `work_items/9 in docs` must NOT match):
```python
WORK_ITEM_URL_RE = re.compile(r"/-/work_items/(\d+)")
ISSUE_URL_RE = re.compile(r"/-/issues/(\d+)")
```
Both `refs.update(...)` calls go inside the same keyword-gated branch. Works for full URLs AND relative markdown links `[#128](/vppos-team/erp-admin/-/work_items/128)`.

## Detection recipe (issue not auto-done after merge)
1. `GET /projects/<id>/issues/<iid>/resource_label_events` — filter `status::*` events: WHO added `status::done` and WHEN. A human username = manual set, not CI (CI's token owner would be the same user as the automation token — check the job trace before concluding).
2. Find the merge pipeline: `GET /projects/<id>/pipelines?sha=<merge_commit_sha>`; then `GET /pipelines/<id>/jobs` → job `issue:lifecycle:merge` → `GET /jobs/<job_id>/trace`, grep `MR !<iid>` for `N issue ref(s)` and `skip issue #<iid>`.
3. Verdicts: trace shows `0 issue ref(s)` → ref-extraction gap (mode 2); trace shows the ref + `skip ... (already status::done)` → idempotent skip, fine; trace shows ref but issue still `status::review` and no skip → DRY_RUN (mode 1).
4. Issue `updated_at` ≥ job `finished_at` is NECESSARY but not sufficient — label events + trace are authoritative.

## Verify-a-fix recipe (no import side effects)
`gitlab-update-milestone-issues.py` has no `__main__` guard and module-level logic — do NOT import it. Extract the pure function:
```python
import re
src = open("scripts/gitlab-update-milestone-issues.py").read()
ns = {}
exec("import re\n" + re.search(r"MR_REF_RE = .*?(?=\n\ndef api\()", src, re.S).group(0), ns)
exec("import re\n" + re.search(r"def issue_refs_from_text\(.*?\n    return refs\n", src, re.S).group(0), ns)
f = ns["issue_refs_from_text"]
```
Test against REAL data: `GET /projects/9/merge_requests/<iid>` → `f(description)` — MR !540 → `{128}`, MR !547 → `{130}` (both were `set()` before the fix). Negative cases that must stay `set()`: `docs/issues/7`, `work_items/9 in docs`, `## Blocked by` lines, `## References` header lines, `## References` attachment URLs.
End-to-end: push to develop, then read the NEW pipeline's job trace — must show `MR !540: 1 issue ref(s) from description`.

## Push-to-develop notes
- develop moves fast: `git push` → non-fast-forward is common → `git fetch origin develop && git rebase origin/develop && git push origin develop`.
- `issue:lifecycle:prod` (release/* pipelines) stays `DRY_RUN: "true"` by design — issues close only after prod deploy.
