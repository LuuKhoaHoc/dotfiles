#!/usr/bin/env bash
# sync-agents.sh — Đồng bộ GLOBAL-CONTEXT (canonical) vào mọi harness agent
# Usage: sync-agents.sh [apply|push|pull]
#   apply  — inject canonical block (dotfiles/agents/global-context.md) vào các file harness local
#   push   — apply + copy file harness vào repo dotfiles + git commit + push
#   pull   — copy file harness từ repo về local
#
# Canonical block được đánh dấu bằng <!-- GLOBAL-CONTEXT-START/END --> —
# apply() thay toàn bộ block giữa 2 marker bằng nội dung canonical (idempotent).

set -euo pipefail

DOTFILES_DIR="$HOME/Dev-Work/dotfiles"
CANONICAL="$DOTFILES_DIR/agents/global-context.md"

# Cặp: local_path|repo_path
HARNESS_FILES=(
  "$HOME/.config/opencode/AGENTS.md|opencode/AGENTS.md"
  "$HOME/.omp/agent/AGENTS.md|omp/agent/AGENTS.md"
  "$HOME/.config/zed/AGENTS.md|zed/AGENTS.md"
  "$HOME/.gemini/GEMINI.md|gemini/GEMINI.md"
  "$HOME/.codex/AGENTS.md|codex/AGENTS.md"
  "$HOME/.claude/CLAUDE.md|claude/CLAUDE.md"
)

apply() {
  [ -f "$CANONICAL" ] || { echo "Thiếu canonical: $CANONICAL"; exit 1; }
  echo "[sync-agents] Inject canonical vào harness files..."
  for entry in "${HARNESS_FILES[@]}"; do
    local_path="${entry%%|*}"
    if [ ! -f "$local_path" ]; then
      echo "  - $local_path (không tồn tại, bỏ qua)"
      continue
    fi
    python3 - "$local_path" "$CANONICAL" <<'PY'
import sys
path, canon = sys.argv[1], sys.argv[2]
block = open(canon).read().rstrip("\n")
txt = open(path).read()
start_marker, end_marker = "<!-- GLOBAL-CONTEXT-START", "<!-- GLOBAL-CONTEXT-END -->"
i, j = txt.find(start_marker), txt.find(end_marker)
if i != -1 and j != -1:
    j = txt.find("\n", j)
    while j < len(txt) and txt[j] == "\n":  # skip ALL newlines after END -> idempotent
        j += 1
    txt = txt[:i] + block + "\n\n" + txt[j:]
else:
    txt = block + "\n\n" + txt
open(path, "w").write(txt)
PY
    echo "  ✓ $(basename "$local_path")"
  done
}

push() {
  apply
  echo "[sync-agents] Copy vào repo dotfiles..."
  for entry in "${HARNESS_FILES[@]}"; do
    local_path="${entry%%|*}"; repo_path="${entry##*|}"
    [ -f "$local_path" ] || continue
    mkdir -p "$(dirname "$DOTFILES_DIR/$repo_path")"
    cp "$local_path" "$DOTFILES_DIR/$repo_path"
    echo "  ✓ $repo_path"
  done
  cd "$DOTFILES_DIR"
  git add agents/global-context.md zed/AGENTS.md gemini/GEMINI.md codex/AGENTS.md claude/CLAUDE.md opencode/AGENTS.md omp/agent/AGENTS.md
  if git diff --quiet --cached; then
    echo "[sync-agents] Không có thay đổi."
  else
    git commit -m "agents: sync global-context across harnesses $(date '+%Y-%m-%d %H:%M')"
    git push
    echo "[sync-agents] Đã push lên GitHub."
  fi
}

pull() {
  cd "$DOTFILES_DIR"
  git pull
  for entry in "${HARNESS_FILES[@]}"; do
    local_path="${entry%%|*}"; repo_path="${entry##*|}"
    [ -f "$DOTFILES_DIR/$repo_path" ] || continue
    mkdir -p "$(dirname "$local_path")"
    cp "$DOTFILES_DIR/$repo_path" "$local_path"
    echo "  ✓ $local_path"
  done
  echo "[sync-agents] Pull xong."
}

case "${1:-}" in
  apply) apply ;;
  push) push ;;
  pull) pull ;;
  *) echo "Usage: $0 [apply|push|pull]"; exit 1 ;;
esac
