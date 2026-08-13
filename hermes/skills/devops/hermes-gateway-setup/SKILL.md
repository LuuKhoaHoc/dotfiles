---
name: hermes-gateway-setup
description: "Set up Hermes gateway: remote Telegram, connect debug."
version: 1.0.0
author: Hermes (luukhoahoc)
license: MIT
platforms: [linux]
---

# Hermes Gateway Setup & Remote Access

Kịch bản chính: user đi vắng, laptop ở nhà chạy gateway, dùng Telegram trên điện thoại nhờ Hermes review code / giao task. Gateway session kế thừa toàn bộ MCP (gitlab, codegraph, GWS) + `_HERMES_CORE_TOOLS` — không cần cấu hình thêm toolset.

## Cấu hình nhanh (Telegram)

1. **Token bot**: @BotFather → `/token` (lấy lại token bot cũ; token mới vô hiệu token cũ — bot cũ tái dùng được, không cần tạo mới). Validate: `curl -s https://api.telegram.org/bot<TOKEN>/getMe` → `"ok":true`. Ghi `TELEGRAM_BOT_TOKEN=<token>` vào `~/.hermes/.env` (file có sẵn dòng comment để uncomment).
2. **Cài service** — user service, KHÔNG `--system`:
   ```bash
   hermes gateway install --start-now --start-on-login
   loginctl show-user $USER -p Linger   # phải = yes (installer tự enable)
   ```
   ⚠️ **`sudo hermes gateway install --system` làm hỏng HERMES_HOME** (resolve về /root khi chạy qua sudo) — user service + linger = chạy từ boot không cần login, đúng cho laptop.
3. **Pairing**: user nhắn bot → bot trả pairing code → `hermes pairing approve telegram <CODE>`. Fail-closed: chưa allowlist = deny mọi sender. Backup allowlist: `TELEGRAM_ALLOWED_USERS=<numeric_user_id>` vào .env — ⚠️ phải là **ID số** (username không khớp; lấy từ log deny hoặc @userinfobot).
4. **Chống sleep khi đóng nắp**: `/etc/systemd/logind.conf` → `HandleLidSwitchExternalPower=ignore` (chỉ khi cắm sạc, giữ nguyên battery), reload không restart session:
   ```bash
   sudo systemctl kill -s HUP systemd-logind
   ```
5. **Bảo mật remote**: `hermes config set security.redact_secrets true` (token không lộ trong chat/log/session JSON).

## Debug: gateway kẹt "Connecting to Telegram (attempt 1/8)"

Triệu chứng: kẹt vô hạn ở attempt 1 dù `curl https://api.telegram.org` OK (mạng VN).

Chẩn đoán theo thứ tự:
1. `ss -tpn | grep <pid gateway>` — thấy **ESTAB tới IPv6** (2001:67c:4e8:f004::9 = api.telegram.org IPv6) mà TLS không xong → **IPv6 nhà mạng VN nửa chết** (SYN/ACK qua, data rớt).
2. Fix: `hermes config set network.force_ipv4 true` + `hermes gateway restart` — monkey-patch socket ép IPv4 (fix chính chủ, ghi trong hermes tips).
3. Adapter mặc định **DoH-discover fallback IPs** (chống DNS poison) — fallback IP blackhole cũng gây kẹt; tắt bằng `HERMES_TELEGRAM_DISABLE_FALLBACK_IPS=true` trong .env (chỉ khi DNS thường OK).
4. Per-attempt timeout mặc định 30s (`HERMES_TELEGRAM_INIT_TIMEOUT`) nhưng deadline **có thể không fire** khi initialize() wedged (bug path đã document trong code) → đừng ngồi chờ retry, diagnose socket ngay.

## Verify

```bash
hermes gateway status
journalctl --user -u hermes-gateway -f
hermes mcp list   # xác nhận MCP enabled trước khi kỳ vọng dùng từ gateway
```

## Pitfalls

- `sudo -S -p ''` lỗi usage trên máy này → dùng `echo "$PW" | sudo -S cmd` (không truyền `-p ''`).
- Gateway restart có thể mất ~1 phút (drain in-flight turns) — đừng tưởng treo.
- Laptop cần cắm sạc khi đi vắng (lid-close-ignore chỉ có tác dụng trên AC).
