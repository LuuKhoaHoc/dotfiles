# pr-to-branch no-Closes fix (2026-08-05)

Concrete session that established the user-skill-maintenance workflow.

## Task

User: "sửa lại skill pr-to-branch ở `.dotfiles/agents/skills` hoặc mr template của dự án lại, không dùng closes khi tạo MR".

## Discovery path

1. `search_files` for `*pr-to-branch*` under `~/.dotfiles` → 0 matches (glob didn't hit the dir listing the way expected; the dir exists).
2. `ls ~/.dotfiles/agents/skills/` → `pr-to-branch/` present. Read `SKILL.md` → it had NO mention of `closes` at all — the skill said only "Thêm link Issue/Ticket nếu có" without prescribing the closing keyword. That vagueness was the gap.
3. Grepped MR templates `.gitlab/merge_request_templates/*.md` in both erp-admin checkouts → 0 matches for `closes`. Templates already use `**Issue / Ticket**: #` (non-closing) — no template change needed.
4. `ls ~/.hermes/skills/ | grep pr-to-branch` → `pr-to-branch -> /home/khoahoc/.agents/skills/pr-to-branch` — a **broken symlink** (target path uses wrong home dir `/home/khoahoc` vs actual `/home/luukhoahoc`; `readlink -f` returned nothing, `ls` of target failed).
5. `ls -la ~/.dotfiles/agents/skills/pr-to-branch/` → real `SKILL.md` (6.9K). That's the canonical file.

## Patch applied (two spots in the skill)

- Step 5.3 item 3: changed "Thêm link Issue/Ticket nếu có" → must use `**Issue / Ticket**: #<iid>` or `Implements #<iid>`; **never** `Closes #<iid>` / `Fixes #<iid>`.
- Step 6: added `[!WARNING]` block — `Closes #N` auto-closes the issue when the MR merges into develop, breaking the strict UAT lifecycle (issue must stay open until prod deploy); non-closing refs are enough for the `issue:lifecycle:merge` CI automation.

## Commit

```bash
cd ~/.dotfiles && git add agents/skills/pr-to-branch/SKILL.md
git commit -m "chore(skills): cấm Closes #N trong pr-to-branch — strict UAT lifecycle"
```

Result: `9b28e6e`, 1 file changed, +6/-1.

## Consistency check (what already existed)

- `workflow/gitlab-issue-workflow` (source of truth): full "NO `Closes #<iid>` — strict UAT lifecycle" rule, user correction 2026-08-05 (issue #134 / MR !545), including the API verification snippet (`/issues/<iid>/related_merge_requests`).
- erp-admin MR templates: already non-closing (`**Issue / Ticket**: #<iid>`).
- `github/github-pr-workflow` templates still contain `Closes #` — that's GitHub PR convention, out of scope for the GitLab UAT rule; user asked specifically about MR creation.
