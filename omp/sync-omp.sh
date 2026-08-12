#!/usr/bin/env bash
# sync-omp.sh — Sync ~/.omp/agent config với dotfiles repo (dual-boot Windows/Linux)
# Usage: sync-omp.sh [push|pull]
#
# KHÔNG sync: memories/ (mnemopi DB), sessions/, *.db, kimi-device-id — runtime data.
# Secrets trong models.yml (apiKey) + mcp.json (glpat-/ctx7sk-/sm_) được strip → <redacted>
# khi push; khi pull user tự dán secret thật qua kênh bảo mật.

set -euo pipefail

DOTFILES_DIR="$HOME/Dev-Work/dotfiles"
OMP_DIR="$HOME/.omp/agent"
OMP_DOTFILES="$DOTFILES_DIR/omp/agent"

# Files/dirs cần sync
SYNC_ITEMS=(
  "AGENTS.md"
  "RULES.md"
  "rules"
  "config.yml"
  "models.yml"
  "mcp.json"
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

strip_secrets() {
  # models.yml: apiKey thật → <redacted> (không anchor ^ — YAML có indent)
  sed -E 's/(apiKey:[[:space:]]*).+/\1<redacted>/' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
  # mcp.json: glpat-* / ctx7sk-* / sk-* / sm_* / figd_* / ntn_* tokens → <redacted>
  sed -E 's/(glpat|ctx7sk|sk)-[A-Za-z0-9_.-]+/\1-<redacted>/g; s/(sm|figd|ntn)_[A-Za-z0-9_.-]+/\1_<redacted>/g' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

push() {
  echo "[omp-sync] Copying ~/.omp/agent → dotfiles/omp/agent..."
  for item in "${SYNC_ITEMS[@]}"; do
    src="$OMP_DIR/$item"
    dst="$OMP_DOTFILES/$item"
    if [ -e "$src" ]; then
      sync_copy "$src" "$dst"
      echo "  ✓ $item"
    else
      echo "  - $item (không tồn tại, bỏ qua)"
    fi
  done

  echo "[omp-sync] Stripping secrets..."
  [ -f "$OMP_DOTFILES/models.yml" ] && strip_secrets "$OMP_DOTFILES/models.yml" && echo "  ✓ models.yml sanitized"
  [ -f "$OMP_DOTFILES/mcp.json" ] && strip_secrets "$OMP_DOTFILES/mcp.json" && echo "  ✓ mcp.json sanitized"

  cd "$DOTFILES_DIR"
  git add omp/
  if git diff --quiet && git diff --cached --quiet; then
    echo "[omp-sync] Không có thay đổi."
  else
    git add omp/
    git commit -m "omp: sync agent config $(date '+%Y-%m-%d %H:%M')"
    git push
    echo "[omp-sync] Đã push lên GitHub."
  fi
}

pull() {
  echo "[omp-sync] Pulling dotfiles từ GitHub..."
  cd "$DOTFILES_DIR"
  git pull

  echo "[omp-sync] Copying dotfiles/omp/agent → ~/.omp/agent..."
  for item in "${SYNC_ITEMS[@]}"; do
    src="$OMP_DOTFILES/$item"
    dst="$OMP_DIR/$item"
    if [ -e "$src" ]; then
      sync_copy "$src" "$dst"
      echo "  ✓ $item"
    else
      echo "  - $item (không tồn tại trong repo)"
    fi
  done

  echo "[omp-sync] Pull xong. NHỚ dán secret thật vào ~/.omp/agent/models.yml (apiKey) + mcp.json (glpat-/ctx7sk-)!"
}

case "${1:-}" in
  push) push ;;
  pull) pull ;;
  *)
    echo "Usage: $0 [push|pull]"
    echo "  push  — copy ~/.omp/agent → dotfiles (strip secrets) rồi git push"
    echo "  pull  — git pull rồi copy dotfiles → ~/.omp/agent (cần dán lại secrets)"
    exit 1
    ;;
esac
