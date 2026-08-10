# agy-acp → Zed (Windows) — session detail (2026-08-10)

Repo: https://github.com/hicder/agy-acp — ACP stdio adapter for Google Antigravity CLI (`agy`), bridging Gemini models into Zed's Agent Panel.

## Install steps (Windows, no VS)
1. Build per SKILL.md (windows-rust-build recipe).
2. Place binary on PATH:
   ```bash
   cp ~/Dev-Work/agy-acp/target/release/agy-acp.exe "$LOCALAPPDATA/agy/bin/"
   ```
   (`$LOCALAPPDATA/agy/bin/` already on PATH — same dir as agy.exe.)

## Zed config (Windows)
- Settings file: `%APPDATA%\Zed\settings.json` (NOT `~/.config/zed/` — that's Linux/macOS).
- File is **JSONC** (trailing commas everywhere) → the `patch` tool REFUSES it (JSON validation). Edit with Python text replace after `cp` backup:
  ```python
  p = r'C:\Users\<user>\AppData\Roaming\Zed\settings.json'
  s = open(p, encoding='utf-8').read()
  s = s.replace(old_block, new_block)   # exact-text replace, assert count==1
  open(p, 'w', encoding='utf-8', newline='').write(s)
  ```
- Entry to add under `"agent_servers"`:
  ```json
  "agy": { "type": "custom", "command": "agy-acp", "args": [], "env": {} }
  ```
- Restart Zed to load new agent servers. Debug: Command Palette → `dev: open acp logs`.

## ACP handshake test (what Zed sends on connect)
```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":1,"clientCapabilities":{}}}\n' \
  | "$LOCALAPPDATA/agy/bin/agy-acp.exe"
# expect: {"jsonrpc":"2.0","id":1,"result":{"agentCapabilities":{...},"agentInfo":{"name":"agy",...}}}
```

## Behavior notes
- Models: adapter runs `agy models` at startup → exposed to Zed's model selector.
- Auth: `~/.gemini/antigravity-cli/settings.json` or `GEMINI_API_KEY` (passed through).
- `AGY_EXTRA_ARGS` env var passes extra args to every agy invocation.
- Sessions persisted at `~/.openab/agy-acp/sessions.json`.
- Cross-OS note: on Linux the build is a plain `cargo build --release` (no VS workarounds); prerequisites are `agy` on PATH + Rust.

Zed agent_servers config also documented in the user-owned skill `zed-agent-integration` (skill index entry for ACP agents).
