---
name: skill-library-audit-sync
description: Use when checking agent skills for dupes or upstream sync.
---

# Skill Library Audit & Sync

Whole-library maintenance for the user's agent skills: duplicate detection, upstream comparison, rename archaeology, cleanup, and mirror sync.

## When to Use

- User asks "các skills có bị duplicate / đè lẫn nhau không" (or similar audit)
- Sync/update skills from `mattpocock/skills` upstream after `npx skills update`
- Clean up old skill versions left behind by repeated `npx skills add` runs at different dates

## Tree layout (verified 2026-08-12)

- **Canonical:** `~/Dev-Work/dotfiles/agents/skills/<name>/SKILL.md` — git-tracked in the dotfiles repo (~60 skills)
- **Mirror:** `~/.hermes/skills/<name>/` — **plain copies, NO symlinks** (0 symlinks found). Mirror is manual: `agents-sync` does NOT sync skills.
- **`~/.local/bin/agents-sync`** → symlink to `dotfiles/agents/sync-agents.sh` — ONLY injects `global-context.md` into 6 harness files (opencode, omp, zed, gemini, codex, claude). Never touches skills.
- **Upstream:** `https://github.com/mattpocock/skills` — dirs: `engineering/`, `productivity/`, `misc/`, `in-progress/`, `deprecated/`
- **`.skill-lock.json`** (`dotfiles/agents/`) — tracks installed skill sources (`npx skills` metadata)

## Duplicate detection (fast pass)

1. List skill dirs; extract `name:` + `description:` from each SKILL.md frontmatter. Near-identical descriptions = duplicate candidates (e.g. `debug` vs `diagnose` had identical descriptions).
2. Diff candidate pairs (`diff a/SKILL.md b/SKILL.md`); check `git log --follow -- <path>` for "restore ... deleted by sync" commits — they explain resurrected old versions.
3. Compare header skeletons to classify old/new versions: `diff <(grep -E "^(#|##|###) " a/SKILL.md) <(grep -E "^(#|##|###) " b/SKILL.md)` — same phase skeleton, one shorter = old/new of the same skill.

## Upstream comparison & rename archaeology

```bash
cd /tmp && git clone --depth 1 https://github.com/mattpocock/skills
# rename history (needs full history):
git fetch --unshallow && git log --oneline --all --diff-filter=R --name-status | grep -iE "rename|R0"
```

Verified renames (full map in `references/mattpocock-skill-renames.md`):
- `review` → `code-review` (commit 14c13c5)
- `to-prd` → `to-spec`; `to-issues` merged into `to-tickets` (386d4ff, "unify planning skills")
- `diagnose` → `diagnosing-bugs` (221ffca)
- `writing-great-skills` → `writing-for-agents`

## Sync / cleanup workflow

1. **Classify each differing skill**: identical / older copy / user-modified / local-only. Compare FULL file trees (list files in both dirs), not just SKILL.md — user modifications usually ADD files or contain Vietnamese/Hilo content. No local-only files + diff is pure upstream evolution → safe to overwrite.
2. **Update:** `rm -rf <skill> && cp -r /tmp/mattpocock-skills/skills/<cat>/<skill> <skill>` — whole dir (SKILL.md + `agents/`, `scripts/`, templates, `LOGIC.md` etc.).
3. **Delete stale skills, then fix references:** `grep -rn "to-prd\|to-issues\|writing-great-skills" --include="*.md" .` — patch remaining references (this session: `decision-mapping` → `/to-spec`).
4. **`.skill-lock.json`:** REMOVE entries of deleted skills, else `npx skills update` restores them. Do NOT hand-add new entries — `skillFolderHash` is not sha1 of SKILL.md; let `npx skills add` create them.
5. **Mirror to `~/.hermes/skills`:** for each changed/added skill `rm -rf ~/.hermes/skills/<s> && cp -r <s> ~/.hermes/skills/<s>`; delete removed ones there too. Verify with `cmp -s <s>/SKILL.md ~/.hermes/skills/<s>/SKILL.md` per skill.
6. **Commit:** `cd ~/Dev-Work/dotfiles && git add agents/ && git commit -m "chore(skills): <what> — <why>"`. Dotfiles repo is PUBLIC — never commit secrets.

## Pitfalls

- `grep "review"` false-positives on `code-review`/`review-pr` — use precise tokens with word boundaries.
- Long one-liners with `( ... )` + `grep -E` can hit the terminal parser limit → split into separate commands.
- `find -type d` misses directory symlinks; when checking mirror structure use `find -type l` separately.
- Don't mass-update "different" skills without checking for user modifications first (local-only files are the tell).
- Skills in `in-progress/` and `misc/` upstream categories are still shipped — check them too, not just `engineering/`.

## References

- `references/mattpocock-skill-renames.md` — verified rename map with commits + 2026-08-12 session summary
