---
name: gitlab-issue-workflow
description: Create GitLab issues via MCP tools with to-tickets format.
---

# GitLab Issue Workflow

Create well-structured issues on GitLab using the MCP toolset, following the `.dotfiles/agents/skills/to-tickets` ticket format.

## Prerequisites

- `mcp__gitlab__*` tools must be available (discover by category if needed)
- API doc files to attach should exist on disk or be uploaded first

## Process

### 1. Activate needed tools via discover_tools

Before creating milestones or listing milestone-scoped issues, activate the tool category:

```text
mcp__gitlab__discover_tools(category="milestones")
```

This adds: `list_milestones`, `create_milestone`, `edit_milestone`, `get_milestone_issue`, etc.

### 2. Upload reference docs (optional)

When an issue references a spec or API doc:

```text
mcp__gitlab__upload_markdown(project_id="<id>", file_path="<path>")
```

This returns a markdown link like `[file.md](/uploads/<hash>/file.md)` that can be embedded in issue descriptions.

**Fallback when `upload_markdown` fails** (e.g. MCP server error): upload via curl with the glab token. `glab api "projects/9/uploads" -f file=@...` returns `"file is invalid"` — use curl instead (never print the token):

```bash
TOKEN=$(python3 -c "import yaml; c=yaml.safe_load(open('$HOME/.config/glab-cli/config.yml')); print(c['hosts']['gitlab.vppos.vn']['token'])")
curl -sS -H "PRIVATE-TOKEN: $TOKEN" -F "file=@<path>" "https://gitlab.vppos.vn/api/v4/projects/9/uploads"
```

Response JSON has a `markdown` field — embed that link in the issue's References.

### 3. Check existing milestones

```text
mcp__gitlab__list_milestones(project_id="<id>")
```

If the target milestone does not exist:

```text
mcp__gitlab__create_milestone(project_id="<id>", title="<name>", description="<scope>", start_date="...", due_date="...")
```

### 4. Create issues in dependency order

**Search for an existing issue first**: `list_issues(project_id, scope='all', state='all', search='<topic>')` — try both EN and VI keywords (e.g. `salary` and `bậc lương`). Reuse an open issue that already covers the change (update its description); only create a new one when nothing matches.

Publish issues **blockers first** so each subsequent issue can reference real IDs.

#### Issue structure (per to-tickets format)

```
## Parent (optional)

Reference to parent issue or milestone.

## What to build

The end-to-end behaviour this ticket makes work, from the user's perspective.

## Acceptance criteria

- [ ] Verifiable outcome 1
- [ ] Verifiable outcome 2

## Blocked by

- #<id> — <title> of blocking issue, or "None — can start immediately"

## References

- [file.md](/uploads/<hash>/file.md) — relevant section
```

**Rules:**
- Title format: `[<MODULE>] <Mô tả ngắn>` for Vietnamese projects
- Do NOT include exact file paths or code snippets — they go stale fast
- Exception: inline a state machine, schema, or type shape that encodes a decision more precisely than prose

### 5. Assign to milestone + people

```text
mcp__gitlab__update_issue(
  project_id="<id>",
  issue_iid="<iid>",
  milestone_id="<milestone_id>",
  assignee_ids=[<user_id>]
)
```

Find user IDs via `mcp__gitlab__list_project_members(project_id="<id>")`.

### 6. Update after creation

If format corrections are needed:

```text
mcp__gitlab__update_issue(
  project_id="<id>",
  issue_iid="<iid>",
  description="<full new description>"
)
```

Note: `update_issue` replaces the entire description — pass the complete new body.

### 7. Link related issues + consolidated note

For independent-but-related issues (e.g. one per MFE of the same standardization effort), link them so each issue shows its siblings:

```text
mcp__gitlab__create_issue_link(
  project_id="9", issue_iid="<src>",
  target_project_id="9", target_issue_iid="<dst>",
  link_type="relates_to"   # or blocks / is_blocked_by
)
```

Create links for ALL pairs after every issue exists (no dependency on creation order). Then post ONE consolidated note on the biggest issue tagging the assignee — `@Username` in the body notifies them on GitLab. Note content: sibling issue list, suggested priority order (dead buttons/no-ops → migrate custom code → add new), reference components/patterns, and a "Đừng làm" section.

**User preference (erp-admin):** for cross-MFE work ("chuẩn hóa X cho mọi module") create ONE issue per MFE — even same assignee — so devs never touch the same files. Skip MFEs already compliant; report the skip to the user. (Overlaps with the `issue-to-tickets` skill's assignee-separation rule.)

### 8. Create the MR (issue-ship)

1. Check for an existing open MR first: `list_merge_requests(project_id, state='opened')` — the user tends to create MR v2 instead of fixing v1; never ship a second MR for the same topic while one is open.
2. Base the branch on **fresh `origin/develop`** (see the stale-develop pitfall below).
3. Use the repo MR template `.gitlab/merge_request_templates/feature.md` (sections: 📝 Mô tả thay đổi (What) / 💡 Ngữ cảnh & Tài liệu liên quan (Why) with `**Issue / Ticket**: #<iid>` / 🛠️ Giải pháp & Kiến trúc / 🧪 Bằng chứng kiểm thử / ✅ Checklist cơ bản). Title: `feat(scope): <summary>`.
4. After creation, re-fetch the MR (`get_merge_request`) and confirm `detailed_merge_status: mergeable` (not `cannot_be_merged`) before reporting success — CI pipeline result comes later.

## Pitfalls

- ❌ Creating issues in the wrong order (not blockers-first) — you won't know the blocking issue IDs yet
- ❌ Adding file paths or code snippets to descriptions — they go stale when the codebase evolves
- ❌ Forgetting `project_id` in get/update calls (easy to miss when batching)
- ❌ Listing milestones without activating the category first via `discover_tools`
- ❌ Assigning a milestone to a closed issue — verify the issue is open first
- ❌ Putting different assignees' work items in the same issue — create separate issues instead
- ❌ **Issue-shipping WIP from a STALE local `develop`** — if `git status` shows `[behind N]`, base the ship branch on fresh `origin/develop`: `git fetch origin` → `git checkout -b fix/<iid>-<slug> origin/develop`. Git carries uncommitted WIP across the switch when the dirty files are identical between branches (verify with `git status` after; helm image-tag commits are the usual diff). A branch based on stale local develop produces confusing MR diffs the moment the same files moved on origin, and shows as "behind" forever.
  - When dirty files DID move on origin (pre-check: `git diff <old-branch> origin/develop -- <dirty files>`), use the stash sequence: `git stash push -m "<desc>"` → `git checkout -b feat/<iid>-<slug> origin/develop` → `git stash pop`. The 3-way merge usually auto-resolves when your edits and origin's edits touch different regions; resolve manually if not. Then verify `git status` lists exactly your intended files and `git diff origin/develop --stat` shows ONLY them before committing.
  - The stash list is SHARED across worktrees of the same repo — after a successful pop, `git stash show -p stash@{0}` may show an unrelated older stash; verify your WIP via `git status`/`git diff`, not stash inspection.
- ❌ Shipping an issue whose working tree contains an EMPTIED test file (0B) — vitest hard-fails `No test suite found in file`; `git rm` the file as part of the fix commit.

## Project-specific conventions (erp-admin)

- **Labels available:** `crm`, `cks`, `finance`, `Shared`, `frontend`, `feature`, `chore`; MFE labels `HR`, `employee`, `hrm-settings`, `MFE::hr`, `MFE::shell`; work-type `Refactor`, `enhancement`, `bug`
- **Module prefixes:** `[Sale]`, `[Product]`, `[Finance]`, `[Shared]`, `[HR]`
- **Milestone:** `CRM Module v1` (id=1) — scope covers sales, product, finance, CKS features
- **People:** luukhoahoc (id=8, Sale), cuongt (id=10, Finance), QuyCN (id=31, Product)
- **Project ID:** `9` (`vppos-team/erp-admin`)