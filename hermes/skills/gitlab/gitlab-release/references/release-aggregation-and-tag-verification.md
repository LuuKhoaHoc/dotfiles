# Release aggregation and tag verification

## Why this reference exists

GitLab MCP list/diff calls can return hundreds of KB. Keep raw responses out of the model context. Save or use the persisted result path, parse JSON with Python, then print compact release facts.

## Compact aggregation recipe

```python
import json
from pathlib import Path

raw = Path("/tmp/hermes-results/<call>.txt").read_text()
outer = json.loads(raw[raw.find('{"result":'):])
value = outer["result"]
data = json.loads(value) if isinstance(value, str) else value

for item in data:
    print({k: item.get(k) for k in (
        "iid", "title", "state", "created_at", "updated_at",
        "merged_at", "closed_at", "web_url", "labels"
    )})
```

Use `merged_at` for MR window filtering. Use `created_at` and `closed_at` separately for issue accounting. `updated_at` alone mixes unrelated edits with delivery events.

## GitFlow verification facts

After creating the release branch from `main` and merging `origin/develop`:

```bash
git rev-parse HEAD
git ls-remote origin refs/heads/release/YYYY-MM-DD refs/heads/main refs/heads/develop
git ls-remote origin refs/tags/release/YYYY-MM-DD
```

If branch and tag use same name, always use explicit ref namespaces:

```bash
git push origin refs/heads/release/YYYY-MM-DD
git push origin refs/tags/release/YYYY-MM-DD
```

Verify the tag's peeled commit, not only the tag object SHA:

```bash
git fetch origin refs/tags/release/YYYY-MM-DD:refs/tags/remote-release

git rev-parse refs/tags/remote-release^{}
git rev-parse HEAD
```

Annotated tag push may report `already exists` when GitLab created the tag while creating the Release. Treat this as a race/duplicate only after comparing `refs/tags/<tag>^{}` with the intended release HEAD. Never force-push a release tag without explicit user approval.

## Release notes content

Include three independent sections:

1. BA scope — business-facing capabilities.
2. MR/commit changelog — verified code changes since previous release.
3. Issue snapshot — new issues, older issues closed, and still-open issues excluded from deploy.

State verification truthfully: local typecheck, branch/tag SHA, MR mergeability, pipeline status, and merge status are separate facts. Do not mark pipeline or merge complete until GitLab confirms them.

## Known MCP parameter mismatch

If `create_tag` rejects a valid-looking request with an error mentioning a missing `release` field, use the local Git remote to create/push the tag, then verify it with `git ls-remote`. Continue using GitLab MCP for `create_release` after the tag exists. This avoids guessing undocumented MCP parameters while retaining a verifiable remote result.

## Release MR verification

After creating the MR, fetch it again and require:

- `source_branch == release/YYYY-MM-DD`
- `target_branch == main`
- `detailed_merge_status == mergeable`
- `merge_status == can_be_merged`
- `diff_refs.head_sha` equals release branch HEAD

Leave review, pipeline, merge, and post-merge sync as unchecked until each event occurs.
