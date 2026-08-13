---
name: hermes-device-migration
description: "Use when moving Hermes to another machine or OS."
triggers:
  - "migrate hermes"
  - "sync hermes to windows"
  - "chuyển sang windows"
  - "new machine hermes"
  - "hermes backup"
  - "hermes import"
  - "post-reset"
tags: [hermes, migration, backup, sync, cross-device, windows]
category: devops
---

# Hermes Device Migration

Transfer a working Hermes home (skills, memories, config, secrets, sessions) to another device. Validated on Linux → Windows (2026-08) and Windows → Linux post-reset restore.

## Restore onto a POPULATED home (Windows→Linux post-reset) — do NOT full-import

When the target home already has config/memories/skills (old install survived), `hermes import` is DANGEROUS: it overwrites `config.yaml` (source-OS version — machine-specific paths/commands), `.env`, and `state.db` (while the desktop app may hold it open). Instead, selectively:

1. **Config**: replace with the per-OS config from the dotfiles repo (`config.linux.yaml`), NOT the backup's `config.yaml`. Diff first — the repo version usually adds MCP servers (e.g. GWS) + `${VAR}` secret placeholders.
2. **.env**: merge ONLY missing keys from the backup's .env (keep file 0600). Then verify values actually rotated — if the bundle's key equals the value that was hardcoded in the old config, it was never rotated (flag it).
3. **state.db**: merge, don't replace — `ATTACH DATABASE` + `INSERT OR IGNORE` per table (`sessions`, `messages`, `async_delegations`, `session_model_usage`, `system_prompts`). FTS triggers auto-maintain indexes. Works while the app runs (WAL + busy_timeout). Copy `state.db` to `state.db.pre-merge-<date>` first. Skip `gateway_routing`/`state_meta` (machine-specific).
4. **Skills**: dotfiles `hermes/skills` is authoritative (usually a superset) — replace wholesale. Watch for local-only skills missing from the repo (e.g. created on one OS, never pushed): diff by skill NAME (paths/categories change), recover from old clones (`~/.dotfiles`), backup zips, or session history (skill_manage create calls are searchable), or recreate from context. Broken symlinks to `~/.agents/skills` = silently missing skills.
5. **Memories**: repo version may be newer BUT carry source-OS paths (e.g. `~/Dev-Work/Hilo/...` vs Linux paths) and drop local-only entries — diff and merge manually, keep the target OS's paths. Mind the ~2200 char budget.
6. **GWS MCP**: copy `mcp-tokens/` bundle + `gws_mcp_oauth.py`; servers use `${GWS_MCP_CLIENT_SECRET}` — needs `.env` + app RESTART to load.
7. **omp**: `sync-omp.sh pull` strips secrets AND may drop MCP servers — back up `~/.omp/agent/models.yml` + `mcp.json` before pull, restore after (merge servers from backup).
8. **cron**: check `cron/jobs.json` in backup — may be empty `{"jobs": []}` (nothing to restore).
9. **9ROUTER_API_KEY**: if it appears in old config.yaml that was ever in a public repo's history, the key is burned — rotation is mandatory, not optional.

## Full backup / import (fresh target)

1. **Check cloud skill sync first**: `hermes sync status`. If `feature_enabled: false` (common — account-level opt-in), fall through to backup/import. `hermes sync` only moves opted-in skills anyway, never memory/config/sessions.
2. **Full backup**: `hermes backup -o <out>.zip` (run in background for big homes; ~44s for 1.6GB original). Known behavior (v0.20):
   - INCLUDES: `.env`, `auth.json`, `shared/nous_auth.json`, `memories/` (MEMORY.md/USER.md), `cron/`, `plugins/` (source only — venvs excluded), `state.db` (consistent `sqlite3.backup()` snapshot), kanban/projects DBs, `skills/` real files, SOUL.md, config backups.
   - EXCLUDES: `hermes-agent/` codebase (re-clone via `hermes update`), `node_modules`, `.venv`/`site-packages`, caches, `backups/`, `checkpoints`, `.db-wal/-shm/-journal`.
   - **SKIPS ALL SYMLINKS** (`_should_skip_backup_file` in `hermes_cli/backup.py` — security: zipfile.write would copy data from outside HERMES_HOME). Mirrored skills (e.g. canonical `~/.agents/skills` → symlink in `~/.hermes/skills`) are SILENTLY missing from the backup.
3. **Post-process the zip** before shipping (use `scripts/prepare_backup_for_migration.py`):
   - DROP `bin/` (Linux uv/tirith launchers — target installer brings its own).
   - DROP stale `state.db.bak-*` AND `state.db.pre-*` emergency backups at HERMES_HOME root (real case: ~850MB of bloat; 658MB zip → 146MB after drop). Originals stay on the source machine.
   - DROP `state-snapshots/` (machine-local restore points).
   - RESOLVE symlinked skills into real zip entries (`--resolve skills/<name>=<src-dir>`), e.g. skills mirrored from `~/.agents/skills` or `~/.dotfiles/agents/skills`. Never ship symlink zip entries — Windows extraction needs admin/dev-mode and breaks.
4. **Package the canonical skill library separately** (`~/.agents/skills` → own zip) or via its git repo. If the repo has unpushed commits (`git status` shows ahead N), cloning on the target misses them — zip the exact current tree instead.
5. **VERIFY before delivering**: import into a scratch home and compare:
   ```bash
   HERMES_HOME=/tmp/hermes-import-test hermes import --force <zip>
   diff -q /tmp/hermes-import-test/memories/MEMORY.md ~/.hermes/memories/MEMORY.md
   find /tmp/hermes-import-test/skills -name SKILL.md | wc -l   # expect same count as source
   ls -lh /tmp/hermes-import-test/state.db
   ```
   Import preserves machine-runtime files (`processes.json`, `gateway_state.json`) — that is EXPECTED output, not an error.
6. **Target machine**: Windows native → `iex (irm https://hermes-agent.nousresearch.com/install.ps1)` in PowerShell, or the Desktop installer; WSL2 → `curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash`. Then `hermes import <backup.zip>`; `hermes --continue` resumes old sessions. Post-import: `hermes skills list`, `hermes mcp list`, `hermes plugins update` (plugin venvs were excluded).

## Pitfalls

- **Broken symlinks = silently missing skills.** If a skill is absent from `hermes skills list`, run `find ~/.hermes/skills -type l -exec readlink {} \;`. Targets pointing at a renamed/removed home (`/home/<olduser>/...`) are skipped by the scanner. Content may still exist in the canonical library (dotfiles repo) → recover from there, don't recreate.
- **Local-only skills vanish on wholesale skills replace.** Before replacing `~/.hermes/skills` from the repo, diff by NAME against the repo's list and recover the stragglers (old clones, backup zips, session history).
- **Notepad breaks config.yaml on Windows**: UTF-8 BOM → HTTP 400 "No models provided". Use `hermes config set` or a UTF-8-no-BOM editor.
- **Alt+Enter is grabbed by Windows Terminal** (fullscreen) — Ctrl+Enter inserts newline.
- **Cron jobs carry absolute source-machine paths** (workdir `/home/<user>/...`) → must be updated on the target (or run in WSL).
- **Plugins restore without venvs** → reinstall deps (`hermes plugins update`) or they error on load.
- Never hand-edit `config.yaml` — always `hermes config set KEY VAL`.
- Zip post-processing must rewrite entries (read zip → write new zip, dropping/appending) — a Python rewrite keeps entries consistent.
- `.env` + `auth.json` travel with the backup — treat the zip as a secrets file (0600); portal token may need `hermes login` / `hermes setup --portal` after import if expired.
- **`hermes import` runs `input()` when target already has config** — in a non-TTY context it aborts; use `--force` only when you really want overwrite.

## Verification

The scratch-`$HERMES_HOME` import test (step 5) is mandatory before delivering a migration package — it exercises the exact restore path (`hermes import`) and catches missing markers (config.yaml/.env/state.db), torn sqlite snapshots, and wrong entry counts.
