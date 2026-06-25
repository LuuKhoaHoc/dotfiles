# OpenCode Config

OpenCode AI coding assistant configuration.

## Structure

```
opencode/
├── opencode.json              # Main config (provider, model, plugins, MCP, agents)
├── oh-my-opencode-slim.json   # OMO preset config (model routing per agent role)
├── tui.json                   # TUI plugin config
├── plugins/
│   └── rtk.ts                 # RTK rewrite plugin (token savings)
├── .claude/
│   └── settings.local.json    # Permission overrides
└── sync-opencode.sh           # Sync script (push/pull)
```

## Usage

### Sync từ máy local → dotfiles (sau khi chỉnh sửa config)

```bash
./opencode/sync-opencode.sh push
```

### Sync từ dotfiles → máy local (khi clone ra máy mới)

```bash
./opencode/sync-opencode.sh pull
```

## Notes

- **Agents/ và Skills/** không được track trong dotfiles — chúng được cài tự động bởi plugin `compound-engineering`.
- **API keys** bị tự động strip khi `push` để tránh leak secret lên GitHub.
- **Paths tuyệt đối** (VD: `C:/Users/<user>/...`) được chuyển thành `$HOME` khi push và expand lại khi pull, giúp portable giữa các máy.
