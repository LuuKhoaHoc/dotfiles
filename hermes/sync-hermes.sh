#!/usr/bin/env bash
# sync-hermes.sh — Sync ~/.hermes config với dotfiles repo
# Usage: sync-hermes.sh [push|pull]

set -euo pipefail

DOTFILES_DIR="$HOME/dotfiles"
HERMES_DIR="$HOME/.hermes"
HERMES_DOTFILES="$DOTFILES_DIR/hermes"

# Files/dirs cần sync
SYNC_ITEMS=(
  "config.yaml"
  "SOUL.md"
  "memories"
  "skills"
)

sync_copy() {
  # Copy src → dst, giữ cả file lẫn thư mục
  # Dùng rsync nếu có, không thì dùng cp
  local src="$1"
  local dst="$2"
  local parent_dir
  parent_dir="$(dirname "$dst")"
  if [ ! -d "$parent_dir" ]; then
    mkdir -p "$parent_dir"
  fi
  if [ -d "$src" ]; then
    # Copy thư mục: xóa dst trước rồi copy lại
    rm -rf "$dst"
    cp -r "$src" "$dst"
  else
    cp "$src" "$dst"
  fi
}

push() {
  echo "[hermes-sync] Copying ~/.hermes → dotfiles/hermes..."
  for item in "${SYNC_ITEMS[@]}"; do
    src="$HERMES_DIR/$item"
    dst="$HERMES_DOTFILES/$item"
    if [ -e "$src" ]; then
      sync_copy "$src" "$dst"
      echo "  ✓ $item"
    else
      echo "  - $item (không tồn tại, bỏ qua)"
    fi
  done

  cd "$DOTFILES_DIR"
  if git diff --quiet && git diff --cached --quiet; then
    echo "[hermes-sync] Không có thay đổi."
  else
    git add hermes/
    git commit -m "hermes: sync config $(date '+%Y-%m-%d %H:%M')"
    git push
    echo "[hermes-sync] Đã push lên GitHub."
  fi
}

pull() {
  echo "[hermes-sync] Pulling dotfiles từ GitHub..."
  cd "$DOTFILES_DIR"
  git pull

  echo "[hermes-sync] Copying dotfiles/hermes → ~/.hermes..."
  for item in "${SYNC_ITEMS[@]}"; do
    src="$HERMES_DOTFILES/$item"
    dst="$HERMES_DIR/$item"
    if [ -e "$src" ]; then
      sync_copy "$src" "$dst"
      echo "  ✓ $item"
    else
      echo "  - $item (không tồn tại, bỏ qua)"
    fi
  done
  echo "[hermes-sync] Pull xong."
}

case "${1:-}" in
  push) push ;;
  pull) pull ;;
  *)
    echo "Usage: $0 [push|pull]"
    echo "  push  — copy ~/.hermes → dotfiles rồi git push"
    echo "  pull  — git pull rồi copy dotfiles → ~/.hermes"
    exit 1
    ;;
esac
