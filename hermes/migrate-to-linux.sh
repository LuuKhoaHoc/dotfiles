#!/usr/bin/env bash
# migrate-to-linux.sh — Đóng gói những gì Hermes cần để tiếp tục trên Linux.
# Chạy trên WINDOWS (git-bash) trước khi sang Linux. Token KHÔNG đi qua GitHub.
# Usage: bash hermes/migrate-to-linux.sh [đích]   (mặc định: ~/hermes-migration/)

set -euo pipefail

DEST="${1:-$HOME/hermes-migration}"
HERMES_DIR="$HOME/AppData/Local/hermes"

echo "==> Đóng gói vào: $DEST"
mkdir -p "$DEST/mcp-tokens" "$DEST/gcloud"

# 1) OAuth tokens Google Workspace MCP (8 server) — refresh token tự sống chéo OS
if [ -d "$HERMES_DIR/mcp-tokens" ]; then
  cp -r "$HERMES_DIR/mcp-tokens/"* "$DEST/mcp-tokens/" 2>/dev/null || true
  echo "  ✓ mcp-tokens: $(ls "$DEST/mcp-tokens" | wc -l) files"
else
  echo "  - mcp-tokens: KHÔNG TÌM THẤY (chưa cấu hình Google MCP?)"
fi

# 2) Script re-auth OAuth (hermes mcp login không chạy được với Google MCP)
#    Bản mới nhất đã nằm trong repo (hermes/gws_mcp_oauth.py) — copy phòng hờ
if [ -f "$HOME/gws_mcp_oauth.py" ]; then
  cp "$HOME/gws_mcp_oauth.py" "$DEST/"
  echo "  ✓ gws_mcp_oauth.py"
fi

# LƯU Ý: config.yaml KHÔNG nằm trong bundle — sync qua repo (config.windows.yaml / config.linux.yaml).
# Secrets nằm trong .env per-OS — bạn tự mang qua kênh bảo mật.

# 3) gcloud credentials + config (giữ login + project đã chọn)
if [ -d "$HOME/.config/gcloud" ]; then
  cp -r "$HOME/.config/gcloud/"* "$DEST/gcloud/" 2>/dev/null || true
  echo "  ✓ gcloud config: $(ls "$DEST/gcloud" | wc -l) files"
else
  echo "  - gcloud config không có (bỏ qua, cài lại + gcloud auth login trên Linux)"
fi

# 4) Hermes backup đầy đủ (sessions, cron, plugins, memories) — tùy chọn
H="$HERMES_DIR/hermes-agent/venv/Scripts/hermes"
if [ -x "$H" ] || [ -f "$H" ]; then
  echo "==> Tạo hermes backup (sessions/cron/plugins)..."
  "$H" backup -o "$DEST/hermes-backup.zip" >/dev/null 2>&1 && echo "  ✓ hermes-backup.zip" || echo "  - backup lỗi (bỏ qua, có thể chạy thủ công)"
fi

cat <<'EOF'

=====================================================
 DONE. Mang thư mục này sang Linux (USB/scp).
 TRÊN LINUX (sau khi cài Hermes):
=====================================================
1. hermes-sync pull                       # config (config.linux.yaml) + skills + memories + SOUL
2. Nhập secrets vào ~/.hermes/.env (qua kênh bảo mật):
   GITLAB_PAT=...   GWS_MCP_CLIENT_SECRET=...
3. cp -r mcp-tokens/* ~/.hermes/mcp-tokens/   # token Google MCP (hoặc chạy gws_mcp_oauth.py để re-auth mới)
4. cp gws_mcp_oauth.py ~/                  # re-auth sau này nếu cần
5. gcloud: cài google-cloud-sdk (pacman -S google-cloud-sdk)
   cp -r gcloud/* ~/.config/gcloud/        # giữ login + project
6. (tùy chọn) hermes import hermes-backup.zip   # sessions/cron/plugins
7. Restart Hermes → kiểm tra mcp_gmail_* etc.
=====================================================
 LƯU Ý:
 - Repo công khai → secret KHÔNG bao giờ commit (config dùng ${VAR}, giá trị
   thật nằm trong .env per-OS). GitHub push protection sẽ chặn nếu lỡ.
 - config.yaml per-OS: sync-hermes.sh tự chọn config.windows.yaml /
   config.linux.yaml — không ghi đè chéo.
 - Redirect URI 127.0.0.1:8765/callback hoạt động cả 2 OS — không cần
   sửa gì trên Google Cloud Console.
EOF
