# GitLab Issue Management via REST API

For when GitLab is used instead of GitHub. No `glab` CLI assumed — use curl or Python against GitLab REST API.

## Prerequisites

```bash
GITLAB_TOKEN="glpat-xxxx"  # Personal Access Token with api scope
GITLAB_URL="https://gitlab.vppos.vn/api/v4"
```

## Find project ID

```bash
curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/projects?search=erp-admin&simple=true" | python3 -c "
import json,sys
for p in json.load(sys.stdin):
    print(f'ID={p[\"id\"]} PATH={p[\"path_with_namespace\"]}')"
```

## List issues

```bash
curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/projects/9/issues?per_page=100&order_by=created_at&sort=asc" | python3 -c "
import json,sys
for i in json.load(sys.stdin):
    labels=','.join(i.get('labels',[]))
    a=i.get('assignee',{}) or {}
    a_name=a.get('name','')
    print(f'  #{i[\"iid\"]}: [{i[\"state\"]}] {i[\"title\"][:90]} | {a_name} | {labels}')"
```

## Create issue

```bash
curl -s -X POST --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/projects/9/issues" \
  -d '{
    "title": "[TASK-0.1] Define shared DTO types",
    "description": "## Description\n\nCreate TypeScript types...\n\n## Files\n- packages/shared/src/types/product.types.ts\n\n## Acceptance Criteria\n- [ ] All types exported",
    "labels": "crm-decomposition,fe-only,phase-0",
    "assignee_ids": [8]
  }'
```

## Get user/assignee IDs

```bash
curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/users?search=luukhoahoc" | python3 -c "
import json,sys
for u in json.load(sys.stdin):
    print(f'ID={u[\"id\"]} USER={u[\"username\"]} NAME={u[\"name\"]}')"
```

## Filter by label

```bash
curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/projects/9/issues?labels=crm-decomposition,fe-only&state=opened"
```

## Update issue (title, labels, assignee, description)

```bash
# Update title + description after gap analysis
curl -s -X PUT --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/projects/9/issues/<IID>" \
  -d '{
    "title": "[TASK-1.2] Customer list and detail pages + Agent Transfer",
    "description": "**UPDATED: added Agent Transfer**\n\nNew components:\n- AgentTransferModal: ..."
  }'

# Assign user
curl -s -X PUT --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/projects/9/issues/<IID>" \
  -d '{"assignee_ids": [10]}'

# Close
curl -s -X PUT --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/projects/9/issues/8" \
  -d '{"state_event": "close"}'

# Add/remove labels
curl -s -X PUT --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  "$GITLAB_URL/projects/9/issues/8" \
  -d '{"labels": "crm-decomposition,phase-0,in-progress"}'
```

## Batch update (Python — read → modify → PUT per issue)

Use this pattern when multiple issues need the same change (module move, reassignment, label swap):

```python
import urllib.request, urllib.parse, json

TOKEN="glpat-..."
BASE="https://gitlab.vppos.vn/api/v4"
HEADERS={"PRIVATE-TOKEN":TOKEN,"Content-Type":"application/x-www-form-urlencoded"}

for iid in [18, 25, 26]:  # list of issue IIDs
    # 1. Read current issue
    req = urllib.request.Request(f"{BASE}/projects/9/issues/{iid}", headers=HEADERS)
    current = json.loads(urllib.request.urlopen(req).read())

    # 2. Modify fields
    new_title = current["title"].replace("finance", "sales")
    new_desc = current["description"].replace("Người nhận: Cường", "Người nhận: Lưu Khoa Học")
    new_labels = "sales,fe-only,phase-2,reports"

    # 3. Write back
    data = urllib.parse.urlencode({
        "title": new_title,
        "description": new_desc,
        "labels": new_labels,
        "assignee_id": "8"
    }).encode()
    req2 = urllib.request.Request(f"{BASE}/projects/9/issues/{iid}",
                                   data=data, headers=HEADERS, method="PUT")
    print(f"Updated #{iid}: {json.loads(urllib.request.urlopen(req2).read())['title']}")
```

## CRITICAL: description field is NOT auto-updated

When you PUT title + labels + assignee, the **description** field is left untouched. If the description contains the old assignee name ("Người nhận: Cường") or old module info, it stays stale unless you:

1. READ the current issue first (GET)
2. MODIFY the description string
3. INCLUDE it in the PUT data

## Limitations

| Field | Writable via REST? | Notes |
|-------|-------------------|-------|
| `title` | Yes | PUT /projects/:id/issues/:iid |
| `description` | Yes | Must include in same PUT |
| `assignee_ids` | Yes | Array of user IDs |
| `labels` | Yes | Form-encoded: comma-separated string; JSON: JSON array string |
| `due_date` | Yes | `"due_date": "2026-08-13"` |
| `start_date` | **NO** | Returns HTTP 400. Not settable on issues (only epics). |
| `state_event` | Yes | `"open"`, `"close"`, `"reopen"` |

## Key differences from GitHub API

| Aspect | GitHub | GitLab |
|--------|--------|--------|
| Auth header | `Authorization: token x` | `PRIVATE-TOKEN: x` |
| Project ref | `:owner/:repo` | Numeric project ID (`:id`) |
| Issue ID | PRs also in `/issues` | Separate issues vs MRs |
| Label assignment | POST `/issues/N/labels` | PUT `/issues/N` with `labels` string |
| State change | PATCH with `state` | PUT with `state_event` (open/close/reopen) |
| Sort param | `sort=created` | `order_by=created_at&sort=asc` |
