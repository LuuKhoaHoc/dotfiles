---
name: hermes-desktop-state-cleanup
description: "Use when clearing stale Hermes desktop sidebar lanes."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [hermes-desktop, state.db, sidebar, sessions, sqlite, cleanup]
---

# Hermes Desktop State Cleanup (stale sidebar lanes)

## When to use

- User asks to "clear worktrees" / "dọn worktree" while using the Hermes desktop app.
- Sidebar shows many branch lanes (main, develop, review, release/..., feat/...) for branches already deleted from the remote — user says the list "nhìn nhiều mà dư" (looks cluttered with dead entries).
- User wants old chat sessions tied to deleted branches removed.

## Critical insight: sidebar lanes ≠ git worktrees

The Hermes desktop sidebar's branch lanes are **NOT git worktrees**. They are session groups computed by the backend from `~/.hermes/state.db`: each session records `git_branch` (plus `cwd`/`git_repo_root`), and the sidebar renders one lane per branch that has sessions. A lane survives its branch being deleted from GitLab because the old sessions still reference that branch.

**Confirm scope FIRST.** "Clear worktrees" may mean the desktop sidebar UI lanes, not `git worktree` on disk. Ask or request a screenshot before deleting anything. They are separate operations (a git worktree remove does NOT clean the sidebar lane of its historical sessions).

## Procedure

1. **List live remote branches** (from the repo, e.g. `erp-admin`):
   `git ls-remote --heads origin | awk '{print $2}' | sed 's|refs/heads/||' | sort`
2. **Find stale lanes** — sessions grouped by branch for the project:
   ```sql
   SELECT git_branch, COUNT(*) AS sessions, datetime(MAX(started_at),'unixepoch','localtime') AS last_active
   FROM sessions WHERE git_branch IS NOT NULL AND git_branch != ''
     AND (cwd LIKE '%<project>%' OR git_repo_root LIKE '%<project>%')
   GROUP BY git_branch ORDER BY last_active DESC;
   ```
   Branches NOT in the remote list = stale. Keep live branches (e.g. `develop`, `main`).
3. **Back up first** (safe while the app is running, WAL mode):
   `sqlite3 ~/.hermes/state.db ".backup '~/.hermes/state.db.bak-lane-clean-<stamp>'"`
4. **Delete in FK order**: messages → session_model_usage → sessions. Use `scripts/cleanup-stale-branch-sessions.sh` (recommended) or inline SQL from `references/state-db-lane-cleanup.md`.
5. **Verify**:
   - `PRAGMA integrity_check;` → `ok`
   - orphan messages → `0`: `SELECT COUNT(*) FROM messages m LEFT JOIN sessions s ON s.id=m.session_id WHERE s.id IS NULL;`
   - FTS in sync: `SELECT (SELECT COUNT(*) FROM messages),(SELECT COUNT(*) FROM messages_fts);` → equal (delete triggers handle FTS)
   - re-run step 2 → only live branches remain

## Pitfalls

- **Deleting sessions is permanent chat-history loss.** Always backup; confirm the branch list with the user before deleting.
- **Don't touch sessions whose cwd is the project's non-repo folder** (e.g. `Documents/ERP`) — they have no git_branch, create no lane, and are often active sessions.
- **A `git worktree remove`d directory still leaves lanes** from its historical sessions — delete those too via `cwd LIKE '%<worktree-name>%'` (pass as 4th script arg).
- **The app caches the sidebar snapshot** — after DB edits the sidebar may need a project switch or app restart to refresh.
- **`session_model_usage` references sessions** — forgetting it leaves orphan rows.
- A blue-dot row in the sidebar is the *selected session*, not a branch — don't mistake it for a lane to delete.

## Files

- `scripts/cleanup-stale-branch-sessions.sh` — backup + FK-ordered delete runner (args: state.db, project filter, comma-separated branch list, optional removed-worktree fragment).
- `references/state-db-lane-cleanup.md` — schema notes, full SQL used, source-code map of the sidebar lane machinery.
