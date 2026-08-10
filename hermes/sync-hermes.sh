#!/usr/bin/env bash
# sync-hermes.sh — Sync Hermes config với dotfiles repo (dual-boot Windows/Linux)
# Usage: sync-hermes.sh [push|pull]
#
# Per-OS config: config.windows.yaml | config.linux.yaml — KHÔNG ghi đè chéo.
# Secrets (GITLAB_PAT, GWS_MCP_CLIENT_SECRET...) không bao giờ vào repo:
# chúng nằm trong ~/.hermes/.env (per-OS, không sync).

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)"
if [ ! -d "$DOTFILES_DIR/.git" ]; then
  DOTFILES_DIR="$HOME/Dev-Work/dotfiles"
fi
# Windows: Hermes data ở AppData/Local/hermes; Linux: ~/.hermes
# Lưu ý 1: HOME trong git-bash có thể là MSYS (/c/...) HOẶC Windows (C:\) — thử cả 2 dạng.
# Lưu ý 2: HERMES_HOME có thể được Hermes app set sẵn TRÊN CẢ WINDOWS (trỏ AppData) —
#          vì vậy OS_NAME phải detect độc lập, HERMES_HOME chỉ quyết định HERMES_DIR.
# Detect OS: uname -s là nguồn tin cậy nhất (git-bash trả MINGW64/MSYS, Linux trả Linux).
# KHÔNG probe path — trên Linux có thể tồn tại ~/AppData/Local/hermes (tàn dư migrate)
# khiến detect nhầm Windows và ghi đè config.yaml bằng bản windows.
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) OS_NAME="windows" ;;
  *) OS_NAME="linux" ;;
esac
if [ -n "${HERMES_HOME:-}" ]; then
  HERMES_DIR="$HERMES_HOME"
elif [ "$OS_NAME" = "windows" ]; then
  HERMES_DIR="$HOME/AppData/Local/hermes"
else
  HERMES_DIR="$HOME/.hermes"
fi
HERMES_DOTFILES="$DOTFILES_DIR/hermes"
CFG_REPO="$HERMES_DOTFILES/config.$OS_NAME.yaml"

# Files/dirs sync (config xử lý riêng theo OS)
SYNC_ITEMS=(
  "SOUL.md"
  "memories"
  "skills"
)

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

push() {
  echo "[hermes-sync] Copying ($OS_NAME) → dotfiles/hermes..."
  # Config per-OS: chỉ cập nhật file của OS hiện tại
  if [ -f "$HERMES_DIR/config.yaml" ]; then
    sync_copy "$HERMES_DIR/config.yaml" "$CFG_REPO"
    echo "  ✓ config.$OS_NAME.yaml"
  fi
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
    git commit -m "hermes: sync ($OS_NAME) $(date '+%Y-%m-%d %H:%M')"
    git push
    echo "[hermes-sync] Đã push lên GitHub."
  fi
}

pull() {
  echo "[hermes-sync] Pulling dotfiles từ GitHub..."
  cd "$DOTFILES_DIR"
  git pull

  echo "[hermes-sync] Copying dotfiles/hermes → ($OS_NAME)..."
  if [ -f "$CFG_REPO" ]; then
    sync_copy "$CFG_REPO" "$HERMES_DIR/config.yaml"
    echo "  ✓ config.yaml (từ config.$OS_NAME.yaml)"
  else
    echo "  - KHÔNG có config.$OS_NAME.yaml trong repo — chạy push từ OS này 1 lần đầu"
  fi
  for item in "${SYNC_ITEMS[@]}"; do
    src="$HERMES_DOTFILES/$item"
    dst="$HERMES_DIR/$item"
    if [ -e "$src" ]; then
      sync_copy "$src" "$dst"
      echo "  ✓ $item"
    else
      echo "  - $item (không tồn tại trong repo)"
    fi
  done
  echo "[hermes-sync] Pull xong. Lưu ý: .env + mcp-tokens không sync — nhập secret qua kênh bảo mật."
}

case "${1:-}" in
  push) push ;;
  pull) pull ;;
  *)
    echo "Usage: $0 [push|pull]"
    echo "  push  — copy config.$OS_NAME.yaml + skills/memories/SOUL → repo rồi git push"
    echo "  pull  — git pull rồi copy config.$OS_NAME.yaml + skills/memories/SOUL → HERMES_HOME"
    exit 1
    ;;
esac
