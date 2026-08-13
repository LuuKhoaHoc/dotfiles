# GitLab Issue-Creation Mechanics (vppos.vn, 2026-08-12)

Session-specific detail for turning a reconciled spec into GitLab issues, learned while
creating the CRM onboarding A/B/C issues and milestone v1.0.4/v1.0.5. Patterns only —
verify against current license/tooling before reuse.

## Instance quirks

- **Block/blocked-by issue links NOT supported (license).**
  `POST /projects/9/issues/:iid/links` with `link_type=blocks` → `HTTP 403
  {"message":"Blocked issues not available for current license"}`. Do not retry.
  Team convention: write `Blocked by #N` as plain text in the issue description
  (existing issues #108/#109 already use this).
- **Work item type "task" is invisible on the issue board.** Real case #57: user
  created a work item as Task, so it never showed on the board and was forgotten.
  If the user says "issue không thấy trên board", check the work item `type` via API
  before assuming it is lost.
- `glab issue create --due-date` and `--milestone` work; verify afterwards with
  `glab issue view <iid>` (assignee/milestone/due/labels in one read).

## Creation workflow that worked

1. Create the milestone first (if the target doesn't exist):
   `glab api projects/9/milestones --method POST -f title="v1.0.5" -f due_date="..." -f description="..."`
   — milestone ID from response (≠ IID).
2. Write each issue description to `/tmp/issueX_desc.md` (Vietnamese with full dấu).
   Use a placeholder token for dependencies: `#<ISSUE_A>`.
3. Create the dependency issue first:
   `glab issue create --title "..." --description "$(cat /tmp/issueX_desc.md)"
   --label "crm,feature,frontend,status::todo,priority::high" --milestone "v1.0.5"
   --due-date "2026-08-14" --assignee luukhoahoc`
4. `sed -i 's/#<ISSUE_A>/#182/' /tmp/issueB_desc.md /tmp/issueC_desc.md` then create
   the dependents. (Careful: a later patch that re-introduces the placeholder is a
   real risk — verify `#<...>` is gone before updating.)
5. Update issue later (e.g. after BE confirmation):
   `glab issue update 184 --description "$(cat /tmp/issueC_desc.md)"`.

## Milestone & due-date semantics

- Issue `due_date` (working deadline, e.g. Friday) and `milestone` (release patch,
  e.g. next week's v1.0.x) are independent and both set at creation.
- "Patch tuần sau" → create the next weekly milestone now; "gắn tất cả N issue" →
  list candidates grouped by `status::*` first, confirm composition before assigning,
  and if the user's stated total includes a struck-out item (blocked/todo), follow the
  explicit number and report the exact composition.
- Snapshot description groups: `status::in-progress`, `status::review`, `status::done`,
  `status::blocked`, and `open / chưa có status` (NO-STATUS).
- Team versioning convention: weekly `v1.0.x` patch cadence while a module is WIP;
  bump minor (`v1.1.0`) only when the module milestone (e.g. `CRM Module v1`) is
  feature-complete.

## Assignee/user-id notes

- luukhoahoc=8, cuongt=10, QuyCN=31 (existing mapping in gitlab-project-management).
- Reassigning an issue: `glab api projects/9/issues/:iid --method PUT -f assignee_ids=31`,
  then verify — response assignees list is the source of truth.
