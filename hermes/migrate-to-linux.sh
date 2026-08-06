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
if [ -f "$HOME/gws_mcp_oauth.py" ]; then
  cp "$HOME/gws_mcp_oauth.py" "$DEST/"
  echo "  ✓ gws_mcp_oauth.py"
fi

# 2b) Trích block 8 Google MCP servers từ config Windows (có client_secret —
#     KHÔNG đẩy lên GitHub, chỉ nằm trong bundle). Merge vào config Linux khi sang.
FRAGMENT="$DEST/gws-mcp-servers.yaml"
PY="$HERMES_DIR/hermes-agent/venv/Scripts/python.exe"
if [ -f "$HERMES_DIR/config.yaml" ]; then
  SRC_W="$(cygpath -w "$HERMES_DIR/config.yaml" 2>/dev/null || echo "$HERMES_DIR/config.yaml")"
  DST_W="$(cygpath -w "$FRAGMENT" 2>/dev/null || echo "$FRAGMENT")"
  "$PY" - "$SRC_W" "$DST_W" <<'PYEOF'
import sys, re
text = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"(?ms)^  gmail:\n.*?^  people:\n(?:    .*\n)*", text)
if not m:
    sys.exit("KHONG TIM THAY block gmail..people trong config")
lines = m.group(0).splitlines()
# Điểm kết thúc: hết block '  people:' (dòng kế tiếp không phải con của people)
end = None
for idx, line in enumerate(lines):
    if line.startswith("  people:"):
        end = idx
        break
for idx in range(end + 1, len(lines)):
    if lines[idx] and not lines[idx].startswith("    "):
        end = idx - 1
        break
else:
    end = len(lines) - 1
open(sys.argv[2], "w", encoding="utf-8").write("\n".join(lines[:end + 1]) + "\n")
print(f"  ✓ gws-mcp-servers.yaml ({end + 1} dòng)")
PYEOF
fi

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
1. hermes-sync pull                       # skills + memories + config (từ GitHub)
2. Merge Google MCP servers vào config:
   mở ~/.hermes/config.yaml (hoặc HERMES_HOME), dán nội dung gws-mcp-servers.yaml
   vào cuối khối mcp_servers: (trước plugins:)
3. cp -r mcp-tokens/* ~/.hermes/mcp-tokens/   # token Google MCP
4. cp gws_mcp_oauth.py ~/                  # re-auth sau này nếu cần
5. gcloud: cài google-cloud-sdk (pacman -S google-cloud-sdk)
   cp -r gcloud/* ~/.config/gcloud/        # giữ login + project
6. (tùy chọn) hermes import hermes-backup.zip   # sessions/cron/plugins
7. Restart Hermes → kiểm tra mcp_gmail_* etc.
=====================================================
 LƯU Ý:
 - client_secret bị GitHub push protection chặn → KHÔNG commit nó vào repo.
   gws-mcp-servers.yaml chỉ tồn tại trong bundle này.
 - ĐỪNG chạy 'hermes-sync push' từ Windows — nó ghi đè config.yaml
   (Windows paths) lên bản Linux trong repo. Giữ config per-OS.
 - Redirect URI 127.0.0.1:8765/callback hoạt động cả 2 OS — không cần
   sửa gì trên Google Cloud Console.
EOF
