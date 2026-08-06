# agentmemory + OpenCode Setup Notes

## User's machine

- Windows 10, MSYS bash shell, Node.js v24.14.1
- OpenCode v1.15.13, installed at `/c/nvm4w/nodejs/opencode`
- Config path: `~/.config/opencode/opencode.json`
- Plugins: `~/.config/opencode/plugins/`
- Commands: `~/.config/opencode/commands/`

## Known issue: iii-engine binary missing on Windows

The `npm install -g @agentmemory/agentmemory` package alone does NOT include the `iii-engine` binary on Windows. The `iii` binary is a separate native executable from [iii-hq/iii](https://github.com/iii-hq/iii). Without it, `agentmemory` server mode fails with "Could not start iii-engine".

**Fix:** download the prebuilt Windows zip:

```bash
# Architecture
uname -m  # → x86_64 on this machine

# Download v0.11.2 (matches agentmemory v0.9.26)
cd ~/.local/bin
curl -fsSL -o iii.zip \
  https://github.com/iii-hq/iii/releases/download/iii/v0.11.2/iii-x86_64-pc-windows-msvc.zip

# Extract (use PowerShell Expand-Archive on Windows)
powershell.exe -Command "Expand-Archive -Path 'iii.zip' -DestinationPath '.' -Force"

# Add to user PATH permanently
powershell.exe -Command "[Environment]::SetEnvironmentVariable('PATH', [Environment]::GetEnvironmentVariable('PATH','User') + ';%USERPROFILE%\.local\bin', 'User')"
```

**Docker fallback:** if Docker Desktop is running, `AGENTMEMORY_USE_DOCKER=1 agentmemory` auto-starts `iiidev/iii:0.11.2`. However Docker Desktop on this machine uses `npipe://` which may not be accessible from MSYS bash — prefer the native binary approach.

## Verified working config

```json
{
  "mcp": {
    "supermemory-mcp": { "type": "remote", "url": "..." },
    "agentmemory": {
      "type": "local",
      "command": ["npx", "-y", "@agentmemory/mcp"],
      "enabled": true,
      "env": { "AGENTMEMORY_URL": "http://localhost:3111" }
    }
  },
  "plugin": [
    "opencode-agent-skills",
    "C:/Users/luukhoahoc/.config/opencode/plugins/agentmemory-capture.ts"
  ]
}
```

## Plugin file source

From `agentmemory` repo: `plugin/opencode/agentmemory-capture.ts`

Copy this to `~/.config/opencode/plugins/agentmemory-capture.ts` after each agentmemory upgrade to pick up bugfixes.

## Slash commands

From `agentmemory` repo: `plugin/opencode/commands/recall.md` and `remember.md`

Copy to `~/.config/opencode/commands/`.

## Health verification

```bash
curl http://localhost:3111/agentmemory/health
```

Expected: `"status":"healthy"`, `"version":"0.9.x"`, `viewerPort` field.

## Server lifecycle

- Start: `agentmemory` (requires `iii.exe` on PATH)
- Stop: `agentmemory stop`
- Diagnostics: `agentmemory doctor`
- Upgrade: `agentmemory upgrade`
- Version: `agentmemory --version`

## What OpenCode gets from this

| Component | Count | Notes |
|-----------|-------|-------|
| MCP tools | 53 | via `@agentmemory/mcp` |
| Hooks captured | 22 | via `agentmemory-capture.ts` plugin |
| Slash commands | 2 | `/recall`, `/remember` |
| Viewer | 1 | `http://localhost:3113` (or per health response) |
