# 🤖 Hermes AI Agent Config

Config, memory và skills của [Hermes Agent](https://hermes-agent.nousresearch.com) được sync qua repo này để dùng chung giữa Arch Linux native và WSL Arch.

## Những gì được sync

- `config.yaml` — cấu hình chính (model, provider, tools...)
- `SOUL.md` — personality/system prompt
- `memories/` — persistent memory (preferences, conventions)
- `skills/` — reusable skill library

## Những gì KHÔNG sync

- `auth.json`, `.env` — credentials/API keys (nhạy cảm)
- `state.db`, `sessions/` — runtime data
- `cache/`, `logs/` — temporary data

## Setup trên máy mới (Arch Linux / WSL Arch)

```bash
# 1. Clone dotfiles
git clone git@github.com:LuuKhoaHoc/dotfiles.git ~/Dev-Work/dotfiles

# 2. Pull hermes config về ~/.hermes
~/Dev-Work/dotfiles/hermes/sync-hermes.sh pull

# 3. Tạo symlink cho script (tiện dùng)
ln -sf ~/Dev-Work/dotfiles/hermes/sync-hermes.sh ~/.local/bin/hermes-sync
```

## Workflow hàng ngày

```bash
hermes-sync pull   # trước khi dùng (lấy changes từ máy khác)
hermes-sync push   # sau khi dùng xong (lưu changes lên GitHub)
```
