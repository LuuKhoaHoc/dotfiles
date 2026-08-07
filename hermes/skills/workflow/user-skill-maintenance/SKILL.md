---
name: user-skill-maintenance
description: Use when fixing skills in ~/Dev-Work/dotfiles/agents/skills.
---

# User Skill Maintenance (dotfiles/agents library)

Maintaining skills the USER owns (not curator-managed): locating the canonical file, editing it, committing, and keeping cross-skill conventions consistent.

## When to Use

- User asks to "sửa/fix skill X", add a rule, or update a skill in `Dev-Work/dotfiles/agents/skills`
- A skill referenced in `~/.hermes/skills/` is missing, broken, or a dead symlink
- A convention must be kept consistent across several skills/templates (e.g. MR no-`Closes` rule)

## Skill tree layout (this user, verified 2026-08-05)

- **Canonical user skills:** `~/Dev-Work/dotfiles/agents/skills/<name>/SKILL.md` — source of truth, git-tracked in the `~/.dotfiles` repo. Edit the FILE directly with `patch`/`write_file`, then `git add` + `git commit`.
- **Hermes mirror:** `~/.hermes/skills/<category>/<name>/` — entries may be SYMLINKS; some are stale/broken (real case: `pr-to-branch` → `/home/khoahoc/.agents/skills/pr-to-branch` — wrong home path, target doesn't exist; real file is in `Dev-Work/dotfiles/agents/skills/`).
- `~/.agents/skills/` may also exist as a canonical root (see the user-owned `skill-library-mirroring` skill).

## Steps

1. **Locate the real file.** Check `~/Dev-Work/dotfiles/agents/skills/` first. For any `~/.hermes/skills/<name>` candidate run `readlink -f`; if it resolves to nothing → broken symlink, use the dotfiles copy. Confirm with `ls -la` on both roots.
2. **Search before editing.** `grep -rni "<term>" ~/Dev-Work/dotfiles/agents/skills/ ~/.hermes/skills/` — the rule may already exist in another skill (e.g. no-`Closes` lives in `gitlab-issue-workflow`). Also grep the project's MR templates (`.gitlab/merge_request_templates/*.md`) — they may already comply and need no change.
3. **Edit the file directly** (`patch`/`write_file` on the canonical path). Do NOT use `skill_manage` — user-owned skills refuse curator writes ("not curator-managed / created_by=None").
4. **Commit.** `cd ~/.dotfiles && git status --short` (only intended file), `git add <path>`, `git commit -m "chore(skills): <what> — <why>"`, verify with `git log --oneline -1`.
5. **Check cross-skill consistency.** Conventions like "no `Closes #N` in MR descriptions" have multiple homes: source-of-truth skill (`gitlab-issue-workflow`), workflow skills (`pr-to-branch`), and repo templates. Update every place that needs it; do not duplicate the rule in more skills than necessary.

## Pitfalls

- **Broken symlink in `~/.hermes/skills`:** points to a stale home path (e.g. `/home/khoahoc/...` vs actual `/home/luukhoahoc`) — `ls` of the target fails but the user insists the skill exists. Verify with `readlink -f`; the real file is in `~/Dev-Work/dotfiles/agents/skills/`.
- **`skill_manage` refuses user-owned skills** — edit the file with `patch`/`write_file` instead; that is the working method.
- **MR templates may already comply** — erp-admin templates use `**Issue / Ticket**: #<iid>` (non-closing) already; grep before editing.
- **Don't commit unrelated dotfiles changes** — stage only the skill file.
- **Convention duplication drift** — when patching one skill, check sibling skills covering the same workflow class so the rule doesn't diverge.

## Verification

- [ ] Patched file re-read shows the new rule in the right section(s)
- [ ] `git -C ~/.dotfiles status --short` shows only the intended file, committed (`git log -1`)
- [ ] Sibling skills / MR templates grepped for the same convention and updated if needed

## References

- references/pr-to-branch-no-closes-2026-08-05.md — concrete session: broken symlink discovery, direct-file patch, dotfiles commit, template check.
