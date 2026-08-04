# GitLab REST API — Issue Management Patterns

## Endpoint Summary

| Method | Endpoint | Use |
|---|---|---|
| GET | `/projects/:id/issues/:iid` | Read issue (title, description, labels, assignees) |
| PUT | `/projects/:id/issues/:iid` | Update issue fields |
| POST | `/projects/:id/issues` | Create issue |
| GET | `/projects/:id/boards` | List issue boards |
| GET | `/projects/:id/boards/:board_id/lists` | List board columns |
| GET | `/projects/:id/members` | List project members (supports `?search=`) |
| GET | `/projects/:id/members/all` | List all members including inherited |

## GET Issue Response (key fields)

```json
{
  "iid": 18,
  "title": "[TASK-2.4] Dashboard",
  "description": "## Metadata\n- **Task ID:** TASK-2.4\n...",
  "labels": ["crm-decomposition", "fe-only", "phase-2", "reports", "sales"],
  "assignees": [{"id": 10, "username": "cuongt", "name": "Trần Cường"}],
  "state": "opened",
  "web_url": "https://host/project/-/work_items/18",
  "start_date": null,
  "due_date": null
}
```

## POST Issue — Create

POST uses JSON body (not form-urlencoded):

```python
import urllib.request, json

def create_issue(title, description, labels=None, project_id=9):
    payload = {"title": title, "description": description}
    if labels:
        payload["labels"] = labels  # comma-separated string
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        f"{BASE}/projects/{project_id}/issues",
        data=data,
        headers={
            "PRIVATE-TOKEN": TOKEN,
            "Content-Type": "application/json"
        },
        method="POST"
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())
```

### Assign after creation
```python
def assign_issue(iid, assignee_ids, project_id=9):
    payload = {"assignee_ids": assignee_ids}  # list of ints
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        f"{BASE}/projects/{project_id}/issues/{iid}",
        data=data,
        headers={
            "PRIVATE-TOKEN": TOKEN,
            "Content-Type": "application/json"
        },
        method="PUT"
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())
```

## GET Members — Find User IDs

```python
def list_members(project_id=9):
    req = urllib.request.Request(
        f"{BASE}/projects/{project_id}/members/all",
        headers={"PRIVATE-TOKEN": TOKEN}
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())
```

### Filter by name/username
```bash
curl -s --header "PRIVATE-TOKEN: $TOKEN" \
  "https://host/api/v4/projects/9/members?search=quy"
# Returns only matching members — faster than listing all
```

## Board API — Read Issue Boards

When user references a board URL (`/-/boards`), use these endpoints:

### List boards
```bash
curl -s --header "PRIVATE-TOKEN: $TOKEN" \
  "https://host/api/v4/projects/9/boards"
# Returns [{id, name, lists: [...]}]
```

### List board columns (lists)
```bash
curl -s --header "PRIVATE-TOKEN: $TOKEN" \
  "https://host/api/v4/projects/9/boards/{board_id}/lists"
# Returns [{id, label: {name, color}, position}]
```

### List issues in a board list
```bash
curl -s --header "PRIVATE-TOKEN: $TOKEN" \
  "https://host/api/v4/projects/9/boards/{board_id}/lists/{list_id}/issues"
# Returns issues with that label applied
```

**Pitfall**: Board IDs are NOT the same as list IDs. First GET `/boards` to find the board `id`, then use that `id` in `/boards/{id}/lists`.

## Known User IDs (ERP project)
| ID | Username | Name |
|----|----------|------|
| 8 | luukhoahoc | Lưu Khoa Học |
| 10 | cuongt | Trần Cường |
| 31 | QuyCN | Cao Quý |

## MCP Fallback

GitLab MCP tools (`mcp_gitlab_create_issue`, `mcp_gitlab_search_repositories`, etc.) fail with `Cannot read properties of undefined (reading 'map')`. Do NOT retry MCP — fall back to REST API via curl/urllib immediately.

## PUT Issue — Update Parameters

| Parameter | Type | Notes |
|---|---|---|
| `title` | string | Issue title |
| `description` | string | Full markdown description |
| `labels` | string | Comma-separated. **NOT JSON array** |
| `assignee_id` | int | Single assignee user ID |
| `assignee_ids` | list[int] | Multiple assignees (use this instead of `assignee_id`) |
| `state_event` | string | "close" or "reopen" |
| `due_date` | string | `YYYY-MM-DD` format |
| `milestone_id` | int | Milestone ID |

### Labels Format — Critical
**CORRECT:**
```python
data = urlencode({"labels": "crm-decomposition,fe-only,phase-2,reports,sales"})
```

**WRONG (causes corruption with embedded quotes):**
```python
data = urlencode({"labels": '["crm-decomposition","fe-only"]'})
# Result: labels become ['"crm-decomposition"', '"fe-only"', ...] with extra quotes
```

### start_date — Not Writable
PUT `/projects/:id/issues/:iid` does NOT accept `start_date`. Returns 400 Bad Request.
`start_date` appears in GET response as read-only field. Only `due_date` is writable via API.

## Python urllib Pattern

```python
import urllib.request, urllib.parse, json

TOKEN = "glpat-..."
BASE = "https://gitlab.vppos.vn/api/v4"

def update_issue(iid, **kwargs):
    data = urllib.parse.urlencode(kwargs).encode()
    req = urllib.request.Request(
        f"{BASE}/projects/9/issues/{iid}",
        data=data,
        headers={
            "PRIVATE-TOKEN": TOKEN,
            "Content-Type": "application/x-www-form-urlencoded"
        },
        method="PUT"
    )
    with urllib.request.urlopen(req) as r:
        return json.loads(r.read())

# Usage
update_issue(18, labels="sales,reports,fe-only")
update_issue(18, description="New description here")
update_issue(18, assignee_id=8)  # luukhoahoc
```

## Label → Module Mapping (ERP project)

```python
def get_module(labels, title):
    if "finance" in labels: return "Tài chính & Báo cáo"
    if "reports" in labels or "sale" in labels: return "Bán hàng & CRM"
    if "product" in labels: return "Sản phẩm & Dịch vụ"
    if "employee" in labels: return "Cá nhân"
    if "phase-0" in labels: return "Hạ tầng chung"
    return "Khác"
```

## Phase → Week Mapping

```python
phase_weeks = {
    "Phase 0": 29,   # 13-19/07/2026
    "Phase 1": 30,   # 20-26/07/2026
    "Phase 2": 30,   # 20-26/07/2026 (parallel)
    "Phase 3": 30,   # 20-26/07/2026 (parallel)
    "Phase 3b": 30,  # 20-26/07/2026 (parallel)
}
```
