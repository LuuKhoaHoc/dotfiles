# Tool Pitfalls for Task Management Workflows

## `read_file` → `write_file` line number corruption

`read_file()` returns content prefixed with line numbers: `"1|content\n2|content\n"`.

If you do:
```python
res = read_file("file.csv")
lines = res["content"].split("\n")  # lines include "1|", "2|" prefixes
# ... modify lines ...
with open("file.csv", "w") as f:
    f.write("\n".join(lines))  # CORRUPT: writes "1|content" back into file
```

**Fix:** Strip line number prefixes before writing back:
```python
lines = res["content"].split("\n")
fixed = []
for line in lines:
    parts = line.split("|", 1)
    fixed.append(parts[1] if len(parts) >= 2 and parts[0].isdigit() else line)
# OR use execute_code which has write_file() that doesn't have this issue
```

**Better:** Use `execute_code` with `hermes_tools.write_file()` or `patch()` instead of raw file writes after `read_file()`.

## GitLab MCP server down → REST API fallback

When GitLab MCP tools fail or return empty, fall back to direct REST API:
```python
import urllib.request, json
TOKEN = "<from ~/.hermes/config.yaml>"
BASE = "https://gitlab.vppos.vn/api/v4"
HEADERS = {"PRIVATE-TOKEN": TOKEN}

req = urllib.request.Request(f"{BASE}/projects/9/issues/{iid}", headers=HEADERS)
res = json.loads(urllib.request.urlopen(req).read())
```

Use `urllib.parse.urlencode()` for PUT with form-encoded data. GitLab accepts Vietnamese/Unicode in description and title via this method.

## GitLab Issues API quirks

- `start_date` is NOT writable via `PUT /projects/:id/issues/:iid` → 400 error. Only `due_date` is settable.
- Labels via form-encoded PUT: comma-separated string (`"labels": "sales,fe-only,phase-2"`).
- Updating title + labels + assignee does NOT auto-update description. You must include description in the same PUT if changing it.
