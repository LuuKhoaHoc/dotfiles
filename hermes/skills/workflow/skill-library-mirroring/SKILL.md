---
name: skill-library-mirroring
description: Manage one source of truth for agent skills in ~/.agents/skills and mirror or symlink it into Hermes or other CLIs that reuse the same library.
triggers:
  - "sync skills"
  - "mirror skills"
  - "one source of truth for skills"
  - "~/.agents/skills"
  - "~/.hermes/skills"
  - "skill library"
  - "share skills across agents"
tags: [skills, sync, symlink, hermes, agents]
category: workflow
---

# Skill Library Mirroring

Use when user wants one skill source of truth and multiple agent CLIs should reuse it.

## Goal

Keep canonical skill files in `~/.agents/skills/`.
Make other agent skill trees point back to it, usually via symlink.

## Preferred layout

- Canonical: `~/.agents/skills/<category>/<skill>/SKILL.md`
- Mirror: `~/.hermes/skills/<category>/<skill>/SKILL.md` -> symlink to canonical file

**User preference**: Keep compound-engineering `ce-*` skills in a `ce/` subdirectory, not flat. This keeps `hermes skills list` organized and enables batch updates.

## Workflow

1. Inspect current skill trees.
2. Pick canonical root, usually `~/.agents/skills/` if user says so.
3. Move or copy skill content into canonical root.
4. Replace duplicate copies in other trees with symlinks to canonical files.
5. Verify both paths resolve and canonical path is real file.

## Foreign Plugin Extraction (Claude Code/Codex)

When a plugin (like `compound-engineering-plugin`) is formatted for Claude Code but installed in Hermes:
1. Use `hermes plugins install <repo>` to clone it.
2. Locate the internal skills directory (often `plugins/<name>/skills/`).
3. Symlink those internal skill directories into the canonical `~/.agents/skills/<category>/`.
4. Mirror from canonical to `~/.hermes/skills/<category>/`.
This ensures updates via `hermes plugins update` propagate through the symlink chain.

## Rules

- Do not keep two editable copies.
- Canonical file must live in user-chosen root.
- Other trees must be symlinks unless tool cannot follow links.
- If symlink support is weak, prefer wrapper/config that reads canonical root directly.

## Verification

```bash
python - <<'PY'
from pathlib import Path
paths = [
    Path.home()/'.agents'/'skills',
    Path.home()/'.hermes'/'skills',
]
for base in paths:
    print(base, base.exists())
PY
```

Check each skill file:
- canonical file: `is_symlink() == False`
- mirrored file: `is_symlink() == True` and `.resolve()` points to canonical file

## Pitfalls

- **Plugin format mismatch**: Not all agent plugins are Hermes-native. Claude Code/Codex plugins land in `~/.hermes/plugins/<repo>/` — their skills need manual extraction via the symlink workflow above. Check with `ls ~/.hermes/plugins/<plugin>/plugins/<name>/skills/`.
- **Symlink chain breaks on update**: If `hermes plugins update` replaces the source dir (not just contents), relink from plugin source to canonical.

## Notes

If user later wants every CLI to share same skill source, point each CLI at canonical tree or generate symlinks from it.

See references/claude-code-plugin-migration.md for a concrete session pattern.
