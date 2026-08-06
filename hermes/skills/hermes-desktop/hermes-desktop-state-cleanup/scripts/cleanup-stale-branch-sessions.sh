#!/usr/bin/env bash
# Delete Hermes desktop sessions stuck on branches that no longer exist on the remote,
# so stale sidebar lanes disappear. Backs up state.db first, deletes in FK order,
# then prints verification queries.
#
# Usage:
#   cleanup-stale-branch-sessions.sh <state.db> <project-filter> <branch1,branch2,...> [worktree-fragment]
#
# Examples:
#   cleanup-stale-branch-sessions.sh ~/.hermes/state.db '%Hilo-Vppos%' \
#     'review,release/fix-120-2026-08-01,release/2026-07-31,refactor/merge-salary-features'
#   # Also drop sessions living in a removed worktree dir:
#   cleanup-stale-branch-sessions.sh ~/.hermes/state.db '%Hilo-Vppos%' 'review' 'erp-admin-review'
#
# Safety:
#   - Backs up to <state.db>.bak-lane-clean-<stamp> before touching anything.
#   - Only deletes sessions whose git_branch is in the explicit list AND whose
#     cwd/git_repo_root matches the project filter.
#   - Sessions with empty git_branch (e.g. non-repo project folders like
#     Documents/ERP) are never matched.
set -euo pipefail

DB="${1:?usage: $0 <state.db> <project-filter> <branch1,branch2,...> [worktree-fragment]}"
FILTER="${2:?project filter (SQL LIKE, e.g. %Hilo-Vppos%)}"
BRANCHES="${3:?comma-separated deleted branch list}"
WORKTREE_FRAG="${4:-}"

IFS=',' read -r -a BR <<< "$BRANCHES"
BR_QUOTED=$(printf "'%s'," "${BR[@]}")
BR_QUOTED="${BR_QUOTED%,}"

STAMP=$(date +%Y%m%d_%H%M%S)
BACKUP="${DB}.bak-lane-clean-${STAMP}"

echo "==> Backing up $DB -> $BACKUP"
sqlite3 "$DB" ".backup '${BACKUP}'"

EXTRA=""
if [[ -n "$WORKTREE_FRAG" ]]; then
  EXTRA=" OR cwd LIKE '%${WORKTREE_FRAG}%'"
  echo "==> Also deleting sessions in removed worktree dir fragment: ${WORKTREE_FRAG}"
fi

echo "==> Deleting sessions on deleted branches: ${BRANCHES}"
sqlite3 "$DB" <<SQL
BEGIN;
DELETE FROM messages WHERE session_id IN (
  SELECT id FROM sessions
  WHERE (cwd LIKE '${FILTER}' OR git_repo_root LIKE '${FILTER}')
    AND (git_branch IN (${BR_QUOTED})${EXTRA})
);
DELETE FROM session_model_usage WHERE session_id IN (
  SELECT id FROM sessions
  WHERE (cwd LIKE '${FILTER}' OR git_repo_root LIKE '${FILTER}')
    AND (git_branch IN (${BR_QUOTED})${EXTRA})
);
DELETE FROM sessions
WHERE (cwd LIKE '${FILTER}' OR git_repo_root LIKE '${FILTER}')
  AND (git_branch IN (${BR_QUOTED})${EXTRA});
COMMIT;
SQL

echo "==> Verify:"
sqlite3 "$DB" "PRAGMA integrity_check;"
sqlite3 "$DB" "SELECT 'orphan_messages', COUNT(*) FROM messages m LEFT JOIN sessions s ON s.id=m.session_id WHERE s.id IS NULL;"
sqlite3 "$DB" "SELECT 'msgs', (SELECT COUNT(*) FROM messages), 'fts', (SELECT COUNT(*) FROM messages_fts);"
echo "==> Remaining lanes (should only be live branches):"
sqlite3 "$DB" "SELECT git_branch, COUNT(*) AS sessions FROM sessions WHERE git_branch IS NOT NULL AND git_branch != '' AND (cwd LIKE '${FILTER}' OR git_repo_root LIKE '${FILTER}') GROUP BY git_branch;"
