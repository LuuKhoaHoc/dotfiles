---
name: skill-library-reconciliation
description: Audit skill libraries for duplicates and sync with upstream.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [skills, duplicate, upstream, sync, dotfiles, mattpocock]
    related_skills: [user-skill-maintenance, skill-library-mirroring]
---

# Skill Library Reconciliation

Detect duplicates in a skill tree (e.g. `dotfiles/agents/skills`), trace them to upstream renames, and clean up without losing user modifications. Root cause of most "duplicate" reports: **upstream repos rename/merge skills over time, and local copies keep the old names**.

## When to Use

- User asks "các skill có bị duplicate / đè lẫn nhau không" (are skills duplicated/overlapping)
- Upstream repo renamed skills and local tree has both old + new names
- Syncing a mirror (`~/.hermes/skills`) after editing the canonical tree
- Before bulk-updating skills from upstream — must check for user modifications first

## Detection Workflow

1. **Inventory + description scan.** Read frontmatter `name` + `description` of every `SKILL.md`. Identical or near-identical descriptions are the strongest duplicate signal (real case: `debug` and `diagnose` had byte-identical descriptions; `code-review` vs `review` too).
2. **Diff suspicious pairs.** `diff a/SKILL.md b/SKILL.md` — same phase/section skeleton with one clearly richer = old/new version of the same skill, not two distinct skills.
3. **Trace renames in upstream git history** (in the upstream repo, needs full history):
   ```bash
   git fetch --unshallow -q
   git log --oneline --all --diff-filter=R --name-status | grep -B2 -iE "<skillname>"
   ```
   `R0xx old/path → new/path` entries prove "old name" is a stale copy. Note: `--diff-filter=D` alone misses renames — you need `-R`.
4. **Hash-compare against upstream `main`.** Clone upstream shallow, sha256 each local `SKILL.md` vs upstream. Classify: GIỐNG HỆT (identical) / KHÁC (older or user-modified) / not-in-upstream (user-written or deleted upstream).
5. **Check for local-only files before overwriting.** Per skill dir, compare the full file tree (not just SKILL.md): `local-only` files or content diffs with user-specific markers (Vietnamese text, company names, project conventions) = user-modified — do NOT overwrite without asking. Pure wording diffs that mirror upstream's own evolution (e.g. "PRD"→"spec", "a question at a time"→"a round of questions") = safe to update wholesale.

## Cleanup Rules

- **Renamed upstream**: delete the old-name skill; the current-name version is canonical.
- **`.skill-lock.json`**: records install sources for `npx skills`. DELETE entries for removed skills — otherwise `npx skills update` restores them next run. Don't hand-craft new entries (the `skillFolderHash` format isn't a plain sha1 of SKILL.md).
- **Fix dangling references**: grep the whole tree for old skill names (`/to-prd`, `/writing-great-skills`, ...) inside OTHER skills' bodies and update to the new names (real case: `decision-mapping` → `/to-spec`). Beware false positives when grepping: "review" matches inside `code-review`/`review-pr`.
- **Mirror sync**: this user's `~/.hermes/skills` mirror is COPY-based (no symlinks). `agents-sync` only syncs `global-context.md` — it does NOT sync skills. After editing the canonical tree, manually `rm -rf` + `cp -r` the affected skill dirs into the mirror, then verify with `cmp` per skill.

## Pitfalls

- Skills may be user-modified even when names match upstream — never bulk-overwrite a dir that has local-only files or user-specific content.
- The upstream README warns: installing via plugin AND `skills.sh` leaves every skill twice — check `.skill-lock.json` `source` per skill to see which install path each came from.
- Old names can linger across MULTIPLE install generations (installed at different dates) — git log of the local repo shows "restore" commits from broken syncs; those restores can be the source of the stale copies.
- When explaining memory containers to the user: UI "projects" (e.g. `sm_project_default`) ≠ API `containerTag` — setup uses the tag, which is why the UI project looks empty. (See references/supermemory-containers.md if that topic comes up.)

## Verification

- [ ] `ls -d <deleted names>` returns nothing
- [ ] `grep -rn` for old names across remaining skills returns no skill references
- [ ] mirror files `cmp` equal to canonical files for every affected skill
- [ ] `git status` shows only intended changes; commit message lists removed/updated/added
- [ ] `.skill-lock.json` has no entries for removed skills

## References

- references/mattpocock-rename-map.md — upstream rename history (commit hashes) + the 2026-08 session outcome
- references/supermemory-containers.md — supermemory containerTag vs UI projects, container config per harness, two-tier persona/project design
