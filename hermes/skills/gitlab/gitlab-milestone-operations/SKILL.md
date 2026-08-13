---
name: gitlab-milestone-operations
description: "Assign issues to milestones and update snapshots."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitLab, Milestone, Release, Snapshot]
    related_skills: ["gitlab-issues", "gitlab-release"]
---

# GitLab Milestone Operations

Manage milestone scope and snapshots — assign issues, update descriptions, track release progress.

## Trigger

- "đánh milestone X vào các issue..."
- "assign issues to milestone..."
- "update milestone description..."
- "sync milestone với issue hiện tại..."

## Prerequisites

- GitLab MCP configured (project accessible)
- Know `project_id` (erp-admin = 9)
- Know milestone ID (from `list_milestones` or another issue's milestone object)

## Workflow: Sync Issues to Milestone

### 1. Find issues by status labels

```python
# List all open issues, filter client-side
# MCP: list_issues(project_id="9", scope="all", state="opened", per_page=100)

target_labels = ['status::in-progress', 'status::review', 'status::done']
filtered = [i for i in issues if any(l in i['labels'] for l in target_labels)]
```

**Result format:**
```python
{
  'iid': '148',
  'title': '[Shell] ...',
  'labels': ['status::done', ...],
  'milestone': None  # ← needs assignment
}
```

### 2. Identify missing milestone assignments

```python
milestone_title = 'v1.0.0'
needs_milestone = [i for i in filtered if not i.get('milestone') or i['milestone']['title'] != milestone_title]
```

### 3. Assign issues to milestone

```python
# MCP: update_issue(project_id="9", issue_iid="148", milestone_id="2")
```

**Milestone ID source:**
- `list_milestones(project_id="9", search="v1.0.0")` → `id` field
- Another issue's `milestone.id` (if already assigned)

### 4. Update milestone description with snapshot

Use `glab` CLI (MCP may not have `edit_milestone`):

```bash
glab api projects/9/milestones/2 --method PUT --field "description=$(cat <<'EOF'
## Status snapshot (YYYY-MM-DD)
- N issues in milestone:
  - **status::done** (M): #110, #116, ...
  - **status::in-progress** (K): #154, #157

## Release checklist
- [x] All intended issues are assigned to this milestone
- [ ] Feature MRs are merged into develop
- [ ] UAT deployment passes
- [ ] Production deployment passes
EOF
)"
```

**Snapshot format:**
- Total count
- Group by `status::*` label
- List #iid per group (comma-separated)

### 5. Verify

```bash
# Check milestone updated
glab api projects/9/milestones/2 | jq '.description' | head -20
```

## MCP Tool Discovery Pattern

When milestone tools aren't discovered:

```python
# Try discovery
tool_search("gitlab milestone")  # May return issue tools only

# Fallback: glab CLI
# GET: glab api projects/:id/milestones/:iid
# PUT: glab api projects/:id/milestones/:iid --method PUT --field "description=..."
```

## Pitfalls

- **KHÔNG gắn milestone vào MR — milestone chỉ gắn trên ISSUE** (convention team, case 2026-08-07 release v1.0.0). MR liên kết milestone gián tiếp qua issue refs trong description (`Issue / Ticket: #N`); lifecycle automation chỉ đọc milestone của issue. Milestone page đếm MR theo field `milestone` của MR → số MR luôn lệch số issue (bình thường, không phải lỗi). Nếu MR đã bị gắn milestone (gán tay/auto trước đó) → **bỏ gán**: `PUT /projects/9/merge_requests/:iid` với `milestone_id=0` (curl `--data "milestone_id=0"`), verify bằng `GET /merge_requests?milestone=<v>&state=all` → phải trả 0 MR.
- **Milestone ID ≠ IID** — `update_issue(milestone_id=...)` takes global ID, not project-scoped IID. Always get from `list_milestones` result.
- **Large list_issues response** — 100 issues ≈ 250KB. Parse with Python in execute_code, don't load raw into context.
- **Don't assume all done issues are in milestone** — explicit check required.
- **Status::done ≠ closed** — issue stays open until prod deploy. Milestone snapshot counts by status label, not state.

## Related Workflows

- Pre-release verification — see `gitlab-milestone-management` (if available)
- Release creation — see `gitlab-release`
- Issue lifecycle — see `gitlab-issues`
