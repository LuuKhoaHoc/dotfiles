---
name: jsonc-config-editing
description: Edit JSONC settings files safely with tolerant validation.
triggers:
  - "zed settings.json edit"
  - "jsonc validation"
  - "trailing comma json error"
  - "edit settings file with comments"
category: editor-config
---

# JSONC Config Editing

Use when editing or validating settings files that allow comments + trailing commas — Zed `~/.config/zed/settings.json`, VS Code settings, any tool config written by the app itself.

## What JSONC is (and why strict parsers lie)

- Full-line `//` comments.
- **Trailing commas allowed**: `"x": true,` directly before `}`/`]` — apps (Zed etc.) write and accept this.
- Strict `json.loads` therefore fails at the FIRST trailing comma in the file — an early "INVALID" is usually the file's normal dialect, **not** your edit. Never panic-fix based on strict-parse output alone.

## Validate with a tolerant parse

```python
import json, re
def tolerant(s: str) -> str:
    s = "\n".join(l for l in s.splitlines() if not l.lstrip().startswith("//"))
    return re.sub(r",(\s*[}\]])", r"\1", s)
json.loads(tolerant(open(path).read()))  # raises only on REAL structural errors
```

**Pre-existing vs my-edit check**: run the same tolerant parse on a pre-edit backup. Identical error position → pre-existing, edit is fine. Different position → your edit broke something.

## Regex-edit pitfalls (each hit in production)

1. **Pattern consuming the closing brace**: a `re.subn` whose match includes the previous block's `}` (e.g. `(\t\t\t},\n\t\t},\n\t\t"dock")`) silently leaves that block unclosed — the next `"key": {` becomes a key inside the wrong object. Always re-read the edited section afterward.
2. **Double comma**: replacement string ending with `,` + the original trailing `,` still in the text → `{},,`. Match only up to the value; keep the comma out of the replacement or strip it explicitly.
3. **Python <3.12**: backslashes inside f-string expressions are a SyntaxError (`f"{re.search(r'\\n', s)}"`). Bind regex results to variables first, then interpolate.
4. **Assert match counts**: `n = pattern.subn(...)` → assert `n == expected` before writing; a silent 0-match leaves the file unpatched while you believe it's done.

## Workflow

1. Backup: `cp file file.bak.$(date +%s)`
2. Targeted regex/text replace with count assertions
3. Tolerant-validate the WHOLE file
4. Read back the edited section (read_file around the edit) to eyeball brace/comma structure
5. If strict parse still fails, compare error position against backup to confirm pre-existing
