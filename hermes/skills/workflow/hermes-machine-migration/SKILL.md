---
name: hermes-machine-migration
description: "Migrate Hermes between machines/OS: backup, import, verify."
triggers:
  - "chuyển máy"
  - "sync hermes sang windows"
  - "migrate hermes"
  - "đồng bộ skills"
  - "new machine setup"
  - "hermes backup"
  - "hermes import"
tags: [hermes, migration, sync, windows, backup, skills]
category: workflow
---

# Hermes Machine Migration

Use when the user moves to a new machine or OS (Linux → Windows, new laptop, ...) and wants Hermes skills, memories, config, and data carried over.

## Core path

1. **On the source machine**: `hermes backup -o <out>/hermes-backup-<date>.zip` (full backup: config.yaml, .env, auth.json, SOUL.md, memories/, cron/, plugins/ source, kanban.db, projects.db, state.db sessions, real skill files). Cloud alternative `hermes sync` only works when `hermes sync status` shows `feature_enabled: true` — often NOT enabled for personal accounts; don't block on it, use backup/import.
2. **Post-process the zip** (Python, `zipfile` append mode — never edit source files):
   - **Resolve symlinked skills to real content.** `hermes backup` SKIPS every symlink by design (zipfile.write follows links → guarded against copying outside HERMES_HOME). Canonical libraries living outside the home (`~/.agents` → dotfiles repo, `~/.dotfiles/...`) will NOT transfer. Walk the skills tree; for each symlink entry, write the resolved file content under the same relative path.
   - **Strip bloat entries**: stale `state.db.bak-*` (old emergency backups, can be ~3× state.db size) and `bin/` (Linux-only uv/tirith launchers — Windows installer brings its own). Also excluded automatically: hermes-agent repo, node_modules, venvs, .db-wal/-shm/-journal.
3. **Copy zip to target** (scp / USB / Downloads folder). Install Hermes on target, then `hermes import <zip>` (add `--force` if anything exists).
4. **Verify after import** — do NOT trust "import succeeded". Checklist:
   - `state.db`, `kanban.db`, `projects.db` sizes match source
   - `memories/MEMORY.md` + `USER.md` content present (read them)
   - `config.yaml`, `.env` (key count), `auth.json`, `SOUL.md` exist; `.env` may need secrets re-added (e.g. GITHUB_TOKEN — `hermes doctor` reports it)
   - plugins/ dirs match source; `hermes cron list` — note Linux workdir paths in cron jobs won't work on Windows
   - skills: count `SKILL.md` files and list top-level dirs vs source; grep for user-specific skill names
5. **Skill dedup after merge** (target often has a pre-existing library): compare top-level dirs against source AND against the canonical dotfiles library (`~/Dev-Work/dotfiles/agents/skills` on Windows). Known duplicate pairs (same meaning, different md5): diagnose↔diagnosing-bugs, review↔code-review, to-prd↔product-requirements-document, to-issues+to-tickets↔issue-to-tickets, qa↔qa-session, handoff↔session-handoff, tdd↔test-driven-development, request-refactor-plan↔refactor-plan. Convention: delete the duplicate copy in `hermes/skills`, KEEP the canonical version in the dotfiles repo untouched. Empty skill dirs (no SKILL.md) are safe to delete. A few near-dup pairs are genuinely different — keep: obsidian↔obsidian-vault, plan-first↔plan, write-a-skill↔writing-great-skills, grill-me↔grilling↔grill-with-docs.

## Dual-boot / same-machine OS switching (Windows ↔ Linux)

- **Never sync ONE config.yaml across OSes** — MCP command paths differ (Windows `node.exe`/`uvx.exe`/`codegraph.cmd` vs Linux mise/`~/.local/bin` paths). Use per-OS files (`config.windows.yaml` / `config.linux.yaml`) in the sync repo; the sync script auto-selects by OS (detect `AppData/Local/hermes` → windows). A single canonical config gets clobbered on every switch.
- **Public sync repos must be secret-free.** Hermes interpolates `${VAR}` placeholders recursively over ALL `mcp_servers` fields (command/args/url/headers/env AND `oauth.client_secret`) from per-OS `~/.hermes/.env` at connect time → commit `${GITLAB_PAT}`-style placeholders, ship real values via secure channel (password manager) once per OS.
- **GitHub push protection** rejects commits containing known secrets ("push declined due to repository rule violations") — that is the desired guardrail, not a bug to route around.
- **OAuth MCP tokens** (`HERMES_HOME/mcp-tokens/*.json`, incl. refresh tokens + `*.client.json`) are OS-portable — copy via bundle/USB (see the migrate bundle script in dotfiles), never via a public repo.
- **gcloud**: `gcloud auth login` once per OS suffices (credentials at `~/.config/gcloud` Linux / `%APPDATA%\gcloud` Windows); re-pick project with `gcloud config set project`.
- **Windows/MSYS pitfall**: a NATIVE Python subprocess may resolve `bash` to WSL/System32 bash instead of git-bash (paths `/c/...` then fail). Pin `C:\Program Files\Git\bin\bash.exe` explicitly. MSYS paths (`/c/...`) work in git-bash but fail in native exes — pass Windows paths, or `cygpath -w` first.

## Windows specifics

- HERMES_HOME on the desktop app = `%LOCALAPPDATA%\hermes` (check `$HERMES_HOME`). A stale `~/.hermes` may also exist from an older install — ignore it, never verify against it.
- Symlinks are resolved to real files by import — good, Windows symlinks are fragile. Verify with `find <skills> -type l` (expect none).
- Imported sessions (state.db) resume normally; `hermes doctor` for health; npm vuln warnings are cosmetic.

## Pitfalls

- **MSYS/git-bash name comparisons silently fail**: `ls` output carries CRLF (`\r`) → `grep -qx "$name" file` never matches. Always compare names with Python `os.listdir` (see scripts/verify_skills_sync.py), or strip CR: `ls ... | tr -d '\r'`.
- **`sort` with Vietnamese/UTF-8 text** on MSYS errors ("Invalid or incomplete multibyte") → prefix `export LC_ALL=C`.
- Quoted `"$VAR"/glob` paths with backslashes mis-expand in git-bash — use forward slashes or Python.
- Never delete files on the source machine when stripping zip entries — operate on the zip only.
- Skill counts don't add up arithmetically (bundled `.hub/`, nested copies like code-review-orchestrator inside software-development/) — compare top-level dirs, not just file counts.

## Support files

- `scripts/verify_skills_sync.py` — diff two skill trees (names + SKILL.md counts) without MSYS CRLF/encoding traps.
