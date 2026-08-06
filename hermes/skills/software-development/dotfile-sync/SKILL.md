---
name: dotfile-sync
description: "Sync personal dotfiles between machines via GitHub — hermes config, neovim, shell, and other dotfiles. Clone, pull, push workflow."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [dotfiles, git, sync, hermes, config, windows]
    homepage: https://github.com/LuuKhoaHoc/dotfiles
---

# Dotfile Sync

Sync personal dotfiles between machines via GitHub. Pattern: dotfiles repo in `~/dotfiles`, individual tool folders inside (e.g. `hermes/`, `nvim/`), one sync script per tool.

## User's Setup

- Repo: `git@github.com:LuuKhoaHoc/dotfiles.git` → clone to `~/dotfiles`
- Symlink: `~/.local/bin/hermes-sync` → `~/dotfiles/hermes/sync-hermes.sh`
- SSH key auth configured (see `github-auth` skill)

## Standard Workflow

```bash
# Clone on new machine
git clone git@github.com:LuuKhoaHoc/dotfiles.git ~/dotfiles

# Initial pull → ~/.hermes, ~/.config/nvim, etc.
~/dotfiles/hermes/sync-hermes.sh pull

# Daily
hermes-sync pull   # before use (get changes from other machines)
hermes-sync push   # after use (save changes to GitHub)
```

## Hermes Config Sync Scope

Synced (version-controlled):
- `config.yaml` — main hermes config
- `SOUL.md` — personality/system prompt
- `memories/` — persistent memory (user preferences, conventions)
- `skills/` — reusable skill library

NOT synced (local-only, gitignored):
- `auth.json`, `.env` — credentials/API keys
- `state.db`, `sessions/` — runtime data
- `cache/`, `logs/` — temporary data
- `.hub/`, `.usage.json`, `.curator_state` — hub/curator state

## Windows-Specific Notes (git-bash / MSYS)

### rsync not available

`rsync` is NOT installed on Windows by default. Sync scripts must use `cp` instead:

```bash
sync_copy() {
  local src="$1" dst="$2"
  local parent_dir
  parent_dir="$(dirname "$dst")"
  if [ ! -d "$parent_dir" ]; then
    mkdir -p "$parent_dir"
  fi
  if [ -d "$src" ]; then
    rm -rf "$dst"
    cp -r "$src" "$dst"
  else
    cp "$src" "$dst"
  fi
}
```

### Path conventions

- Use `$HOME/dotfiles` (NOT `$HOME/Dev-Work/dotfiles` or similar hardcoded paths)
- On Windows/git-bash, `$HOME` = `C:/Users/<user>`
- Both forward slashes (`C:/Users/...`) and backslashes (`C:\Users\...`) work in most contexts
- `~/.local/bin/` IS in PATH on git-bash

### Symlink works on Windows git-bash

```bash
mkdir -p ~/.local/bin
ln -sf ~/dotfiles/hermes/sync-hermes.sh ~/.local/bin/hermes-sync
chmod +x ~/dotfiles/hermes/sync-hermes.sh
```

After this, `hermes-sync` works from any terminal.

**PITFALL — `ln -sf` on MSYS creates a COPY, not a symlink.** `readlink -f`/`readlink` return nothing (exit 1) on git-bash. So `${BASH_SOURCE[0]}` inside the script resolves to `~/.local/bin/hermes-sync`, and `dirname/..` points to `~/.local` — NOT the dotfiles repo. Fix: resolve `DOTFILES_DIR` with a `.git` fallback:

```bash
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
if [ ! -d "$DOTFILES_DIR/.git" ]; then
  DOTFILES_DIR="$HOME/Dev-Work/dotfiles"
fi
```

**PITFALL — Windows Hermes data lives in `~/AppData/Local/hermes`, NOT `~/.hermes`.** Auto-detect:

```bash
if [ -z "${HERMES_HOME:-}" ] && [ -d "$HOME/AppData/Local/hermes" ]; then
  HERMES_DIR="$HOME/AppData/Local/hermes"
else
  HERMES_DIR="${HERMES_HOME:-$HOME/.hermes}"
fi
```

**PITFALL — GitHub secret scanning rejects pushes containing real tokens** (e.g. `ntn_`, `figd_`, `glpat-`, `ctx7sk-` values in skill references or `config.yaml` MCP servers). Before pushing: `grep -rnE 'glpat-|ntn_|figd_|ctx7sk-|squ_|ghp_' hermes/` and redact real values to `<redacted>`. If a push is rejected, the offending commit stays in local history — squash it: `git reset --soft <good-commit> && git add -A && git commit -m ...` then push.

### Git identity

Git may not have global identity set on a fresh Windows install. Set locally in the dotfiles repo:

```bash
cd ~/dotfiles
git config user.name 'Your Name'
git config user.email 'your@email.com'
```

Do NOT use `--global` — keep identity repo-local.

## Writing a Sync Script

Each tool folder gets its own `sync-<tool>.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"
TOOL_DIR="$HOME/.toolname"
TOOL_DOTFILES="$DOTFILES_DIR/toolname"

SYNC_ITEMS=("config" "themes" "plugins")

sync_copy() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -d "$src" ]; then
    rm -rf "$dst"
    cp -r "$src" "$dst"
  else
    cp "$src" "$dst"
  fi
}

push() {
  for item in "${SYNC_ITEMS[@]}"; do
    [ -e "$TOOL_DIR/$item" ] && sync_copy "$TOOL_DIR/$item" "$TOOL_DOTFILES/$item"
  done
  cd "$DOTFILES_DIR"
  git add toolname/
  git diff --quiet && git diff --cached --quiet || {
    git commit -m "toolname: sync $(date '+%Y-%m-%d %H:%M')"
    git push
  }
}

pull() {
  cd "$DOTFILES_DIR"
  git pull
  for item in "${SYNC_ITEMS[@]}"; do
    [ -e "$TOOL_DOTFILES/$item" ] && sync_copy "$TOOL_DOTFILES/$item" "$TOOL_DIR/$item"
  done
}

case "${1:-}" in push) push ;; pull) pull ;; *)
  echo "Usage: $0 [push|pull]" ;;
esac
```

## Verifying Sync

```bash
# Verify symlink
ls -la ~/.local/bin/hermes-sync

# Test pull
hermes-sync pull

# Verify items landed
ls ~/.hermes/
```

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `rsync: command not found` | Script uses `cp` instead — check script not using rsync |
| `hermes-sync: command not found` | Symlink missing: `ln -sf ~/dotfiles/hermes/sync-hermes.sh ~/.local/bin/hermes-sync` |
| Git wants identity | `git config user.name/email` locally in dotfiles repo |
| `/.local/bin/` not in PATH | Check PATH includes `$HOME/.local/bin` on Windows git-bash |
