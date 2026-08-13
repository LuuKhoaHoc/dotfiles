---
name: skill-library-audit
description: Check skills for duplicates/overlaps/mirror drift.
version: 1.0.0
metadata:
  hermes:
    tags: [skills, audit, duplicates, mirror, sync]
    related_skills: [user-skill-maintenance, skill-library-mirroring]
---

# Skill Library Audit

Find duplicate/overlapping skills inside one skill tree and between mirror trees (e.g. `dotfiles/agents/skills` ↔ `~/.hermes/skills`), classify them, and decide what to keep — without deleting anything unilaterally.

## When to Use

- User asks "kiểm tra skills có duplicate/đè lẫn nhau không", "are skills duplicated", "audit the skill library"
- After a sync/restore incident (git commits like "restore N skills deleted by sync") — old versions get resurrected beside new ones
- Before consolidating or cleaning up a skill tree

## Classification Vocabulary

Classify every suspicious pair before recommending anything:

1. **TRUE DUPLICATE** — same purpose, multiple versions in one tree. Keep the newest/most complete, delete the rest. Signature: identical description text, same section skeleton, different file size.
2. **WRAPPER / ALIAS** — a tiny skill whose whole body is "Run a `/X` session" (e.g. `grill-me` → runs `/grilling`). Router pattern, by design — leave alone.
3. **COMPLEMENTARY PAIR** — same topic, different role (one executes / one plans; one creates / one maintains). NOT duplicates — say so explicitly so nobody "cleans them up" later.
4. **CROSS-TREE SHADOWING** — same `name:` in two trees with different content. Both load into the skill index; whichever wins is load-order luck. Needs a canonical-source decision, not a delete.
5. **SAME-PURPOSE, DIFFERENT NAME across trees** — `handoff` vs `session-handoff`, `tdd` vs `test-driven-development`. Each harness loads whichever tree it reads → drift guaranteed.

## Audit Steps

### 1. Enumerate + extract frontmatter descriptions

```bash
ls -d <root>/skills/*/ | wc -l
```

Extract `name` + `description` + size from every SKILL.md frontmatter (one Python script — read_file per skill is too slow for 60+ files). Dump the whole list and eyeball it; identical/near-identical descriptions are prime suspects.

### 2. Diff suspicious pairs

```bash
diff -q a/SKILL.md b/SKILL.md                          # identical → same file twice
diff a/SKILL.md b/SKILL.md | wc -l                     # tiny diff → same skill evolved
diff <(grep -E "^(#|##|###) " a/SKILL.md) \
     <(grep -E "^(#|##|###) " b/SKILL.md)              # header-skeleton comparison
```

Header diff tells the story fast: same skeleton = same skill at different maturity; different skeleton = possibly different roles (verify, don't assume).

### 3. Date the versions with git history

```bash
git -C <dotfiles-repo> log --oneline -3 --follow -- agents/skills/<name>/SKILL.md
```

Watch for **restore commits** ("restore 12 skills deleted by sync — fix broken symlinks") — they resurrect OLD versions next to the current one. The skill whose history is only "Sync ..." commits is usually the live one. `--follow` catches renames.

### 4. Cross-tree comparison (dotfiles ↔ ~/.hermes/skills)

- Same-name collisions: for each dotfiles skill present in hermes, `cmp` the contents — report GIỐNG HỆT vs KHÁC with sizes.
- Same-name-in-two-categories: `find ~/.hermes/skills -type d -name <X>` — a root copy AND a hermes-native copy (e.g. `note-taking/obsidian`) is a real shadowing conflict.
- Same-purpose-different-name twins: compare descriptions of hermes skills that don't exist under the dotfiles name (e.g. `session-handoff`, `qa-session`, `issue-to-tickets`, `product-requirements-document`, `test-driven-development`).
- Mirror mechanism: `find ~/.hermes/skills -type l | wc -l` — 0 = copy-based mirror (drifts whenever dotfiles is edited without running sync). Grep the sync script for `cp ` vs `ln -s`. Check `.skill-lock.json` at tree root — it records upstream GitHub sources (mattpocock/skills, etc.) and separates user-owned from upstream-installed.

### 5. Report in the classification vocabulary

Deliver: a table of TRUE DUPLICATES with keep/delete recommendation (keep = newest/most complete), the SHADOWING conflicts needing a canonical decision, and COMPLEMENTARY pairs explicitly cleared. Do NOT delete or commit anything without user confirmation — this user controls merges/commits.

## Pitfalls

- **`find -type d` misses symlinked dirs** — a symlinked skill dir won't match `-type d -name X`. Use `-type l` to list links and `ls -la` to see reality. (A zero symlink count in a mirror that's supposed to be symlinked is itself a finding.)
- **Long chained one-liners can get blocked** by the command parser (oversized inline payloads, heredocs). Keep audit commands short; split comparisons into separate calls or a small script file.
- **Descriptions lie** — `debug` and `diagnose` had byte-identical descriptions but different bodies; `code-review` and `review` shared description AND skeleton but one had the newer smell baseline. Always verify by diff.
- **Check file existence in scripts** — missing path → "(missing)" placeholder, not a crash; one missing file can abort a whole `&&` chain silently.
- **Same name in two category dirs is a real conflict**, not a false positive (hermes had root `obsidian` AND `note-taking/obsidian`, both `name: obsidian`).

## Verification

- [ ] Every suspicious pair classified into one of the 5 categories
- [ ] Git history checked with `--follow` to identify the newer version
- [ ] Cross-tree collisions confirmed by content comparison (cmp), not just name matching
- [ ] Report separates "delete" (true duplicates) / "decide" (shadowing) / "leave alone" (complementary, wrappers)
- [ ] Nothing deleted or committed without explicit user confirmation

## References

- references/audit-dotfiles-2026-08-12.md — concrete audit of dotfiles/agents/skills (64 skills) vs ~/.hermes/skills (272): exact duplicate pairs, shadowing conflicts, mirror findings, pending cleanup decisions.
