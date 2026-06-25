#!/usr/bin/env bash
# sync-opencode.sh — Sync ~/.config/opencode config với dotfiles repo
# Usage: sync-opencode.sh [push|pull]
#
# Notes:
# - API keys trong opencode.json được tự động strip khi push (tránh leak)
# - Paths tuyệt đối được chuyển thành $HOME khi push và expand khi pull
# - Agents/ skills/ không được sync (do plugin compound-engineering tự cài)

set -euo pipefail

DOTFILES_DIR="$HOME/Dev-Work/dotfiles"
OPENCODE_DIR="$HOME/.config/opencode"
OPENCODE_DOTFILES="$DOTFILES_DIR/opencode"

# Files/dirs cần sync
SYNC_ITEMS=(
  "opencode.json"
  "oh-my-opencode-slim.json"
  "tui.json"
  "plugins/rtk.ts"
  ".claude/settings.local.json"
)

sync_copy() {
  local src="$1"
  local dst="$2"
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

push() {
  echo "[opencode-sync] Copying ~/.config/opencode → dotfiles/opencode..."

  for item in "${SYNC_ITEMS[@]}"; do
    src="$OPENCODE_DIR/$item"
    dst="$OPENCODE_DOTFILES/$item"
    if [ -e "$src" ]; then
      sync_copy "$src" "$dst"
      echo "  ✓ $item"
    else
      echo "  - $item (không tồn tại, bỏ qua)"
    fi
  done

  # Strip API keys khỏi opencode.json trong dotfiles (tránh commit secret)
  if [ -f "$OPENCODE_DOTFILES/opencode.json" ]; then
    # Dùng tmp file để tránh sed cross-platform issues
    python3 -c "
import json, re

with open('$OPENCODE_DOTFILES/opencode.json', 'r') as f:
    content = f.read()

# Strip apiKey fields
data = json.loads(content)
for provider in data.get('provider', {}).values():
    opts = provider.get('options', {})
    if 'apiKey' in opts:
        del opts['apiKey']
        print('  → Stripped apiKey from provider')

# Rewrite absolute paths to \$HOME
content_new = json.dumps(data, indent=2)
content_new = content_new.replace('$HOME', '\$HOME')
# Convert Windows backslash paths
content_new = content_new.replace('C:/Users/' + '$HOME'.split('/')[-1], '\$HOME')

with open('$OPENCODE_DOTFILES/opencode.json', 'w', newline='\n') as f:
    f.write(content_new + '\n')
"
    echo "  ✓ opencode.json sanitized (keys stripped, paths normalized)"
  fi

  cd "$DOTFILES_DIR"
  if git diff --quiet && git diff --cached --quiet; then
    echo "[opencode-sync] Không có thay đổi."
  else
    git add opencode/
    git commit -m "opencode: sync config $(date '+%Y-%m-%d %H:%M')"
    git push
    echo "[opencode-sync] Đã push lên GitHub."
  fi
}

pull() {
  echo "[opencode-sync] Pulling dotfiles từ GitHub..."
  cd "$DOTFILES_DIR"
  git pull

  echo "[opencode-sync] Copying dotfiles/opencode → ~/.config/opencode..."
  for item in "${SYNC_ITEMS[@]}"; do
    src="$OPENCODE_DOTFILES/$item"
    dst="$OPENCODE_DIR/$item"
    if [ -e "$src" ]; then
      sync_copy "$src" "$dst"
      echo "  ✓ $item"
    else
      echo "  - $item (không tồn tại, bỏ qua)"
    fi
  done

  # Expand \$HOME back to real path khi pull
  if [ -f "$OPENCODE_DIR/opencode.json" ]; then
    python3 -c "
import json

with open('$OPENCODE_DIR/opencode.json', 'r') as f:
    content = f.read()

# Expand \$HOME back to real path
content = content.replace('\$HOME', '$HOME')

with open('$OPENCODE_DIR/opencode.json', 'w', newline='\n') as f:
    f.write(content)
"
    echo "  ✓ opencode.json paths expanded for local machine"
  fi

  echo "[opencode-sync] Pull xong. Chạy 'opencode' để kiểm tra."
}

case "${1:-}" in
  push) push ;;
  pull) pull ;;
  *)
    echo "Usage: $0 [push|pull]"
    echo "  push  — copy ~/.config/opencode → dotfiles rồi git push"
    echo "  pull  — git pull rồi copy dotfiles → ~/.config/opencode"
    exit 1
    ;;
esac
