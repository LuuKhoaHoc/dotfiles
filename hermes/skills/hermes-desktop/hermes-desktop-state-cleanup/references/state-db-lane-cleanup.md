# Hermes Desktop state.db — schema notes & sidebar lane machinery

Verified 2026-08-05 while cleaning stale lanes in the Hilo-Vppos project (session
"clear worktree" request). DB: `~/.hermes/state.db` (SQLite, WAL mode, live while
the desktop app runs).

## Relevant schema

- `sessions(id TEXT PK, source, cwd TEXT, git_branch TEXT, git_repo_root TEXT,
  started_at REAL, ended_at, message_count, ...)`
- `messages(id INTEGER PK AUTOINCREMENT, session_id TEXT NOT NULL REFERENCES
  sessions(id), role, content, timestamp, ...)` — FK enforcement is OFF by
  default (`PRAGMA foreign_keys` → 0), so manual deletes must be FK-ordered.
- `session_model_usage(session_id ...)` — secondary table referencing sessions;
  orphaned rows if forgotten.
- FTS: `messages_fts` + `messages_fts_trigram` with delete triggers
  (`messages_fts_delete`, `messages_fts_trigram_delete`) — FTS stays in sync
  automatically when rows are deleted via SQL. Verify with count comparison.

## Where the sidebar lanes come from (source map)

- Backend computes session grouping authoritatively
  (`apps/desktop/src/app/chat/sidebar/projects/workspace-groups.ts`): one lane
  per branch/worktree that has sessions, `repo -> lane -> sessions`.
- A live `git worktree list` probe injects extra *visual* lanes for worktrees
  with no sessions yet (`model.ts` → `useRepoWorktreeMap`, concurrency 4).
- Linked-worktree lanes are labeled by their checked-out branch, not dir
  (`mergeRepoWorktreeGroups`); main checkout collapses to the "home" lane
  labeled by its live branch, defaulting to `main`.
- "Remove worktree" dialog offers two paths: real `git worktree remove`
  (`removeWorktreePath` in `store/projects.ts`) or hide-lane-only
  (`dismissWorktree(id)` → `$dismissedWorktreeIds`, localStorage persistent
  atom in `store/layout.ts`). Main lanes can't be dismissed.
- i18n keys under `sidebar.projects` in `apps/desktop/src/i18n/en.ts`
  (`removeWorktree`, `removeWorktreeConfirm`, `back: 'All projects'`).

## Key behavioral facts

- **Lane survives branch deletion on remote** — sessions in `state.db` still
  carry the old `git_branch` value, so the backend keeps emitting the lane.
  Cleaning = deleting those sessions (or hiding the lane in UI, which keeps
  sessions but only works for linked worktrees).
- **Deleted worktree dirs also leave lanes** — historical sessions whose `cwd`
  pointed into the removed dir still render. Handle with
  `cwd LIKE '%<worktree-frag>%'` in the delete predicate.
- **Non-repo project folders** (e.g. `Documents/ERP` under a project whose
  primary_path is not a git repo) produce sessions with empty `git_branch` —
  they never create branch lanes and should NOT be deleted by this cleanup.
- **App caches sidebar snapshot** — after DB edits, refresh may need a project
  switch in the sidebar or an app restart.

## Session transcript (reference)

- Remote branch diff: `git ls-remote --heads origin` vs
  `SELECT git_branch, COUNT(*) ... GROUP BY git_branch` → 8 dead branches,
  13 sessions (incl. `erp-admin-review` worktree sessions).
- Deleted via the script in this skill. Verified: `integrity_check` ok, 0
  orphan messages, FTS counts equal (12416 = 12416), only `develop` lane left.
- Backup kept: `~/.hermes/state.db.bak-before-lane-clean-20260805` (294M).
- Note: user's "clear worktrees" meant the desktop sidebar, NOT `git worktree`
  — a `git worktree remove` alone does not clean the sidebar lanes. Confirm
  scope with a screenshot when ambiguous.
