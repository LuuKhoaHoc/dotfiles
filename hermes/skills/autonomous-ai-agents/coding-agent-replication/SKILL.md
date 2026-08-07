---
name: coding-agent-replication
description: "Port omp + opencode config to another machine/OS (Windows)."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Coding-Agent, omp, opencode, Multi-Machine, Windows, Replication, Model-Routing]
    related_skills: [coding-agent-setup, opencode, hermes-agent]
---

# Coding Agent Replication (multi-machine / cross-OS)

Use when the user has agents configured on one machine and wants the SAME setup on another — e.g. *"bạn vừa cấu hình trên linux, giờ tôi đang bên windows, cấu hình tương tự"*. Companion to `coding-agent-setup` (which covers the persona recipe itself); this skill covers the porting workflow and Windows-native specifics.

## Core workflow: port, don't re-type

1. **Identify WHICH machine the terminal is on first.** The terminal backend can switch mid-session (SSH box ↔ local host). Probes:
   - `ls -ld /home/<user>` exists → Linux box; `ls -ld /c/Users/<user>` exists → Windows (MSYS); `cygpath -w ~` prints the native Windows path.
   - Config written to the WRONG machine's home is invisible to the other. If paths you just wrote vanish, the backend switched.
2. **Inventory the TARGET machine before touching anything**: `~/.bun/bin/omp --version`, `cat ~/.omp/agent/config.yml`, `ls ~/.omp/agent` (AGENTS.md? RULES.md? rules/? mcp.json? models.yml?), `~/.config/opencode/`, `~/.claude/`, PowerShell `Get-Command omp,opencode`, `[Environment]::GetEnvironmentVariable('Path','User')`.
3. **Diff against the source machine; replicate ONLY the missing pieces.** Do NOT overwrite machine-specific setup — e.g. Windows may already have oh-my-opencode-slim preset + custom agents + a local router that Linux lacks; keep those, add the missing persona/MCP/memory.
4. **Copy persona files as-is** (they're machine-agnostic): `~/.omp/agent/AGENTS.md` (universal persona), `~/.omp/agent/RULES.md`, `~/.omp/agent/rules/*.md` (TTSR), `~/.config/opencode/AGENTS.md` (opencode global persona). Same on both OSes — home-relative dirs, `C:/Users/<user>/...` on Windows.
5. **Replicate memory + model roles**: `memory.backend: mnemopi`, `autolearn.enabled: true`, `modelRoles.advisor` → local router or a working provider (see Pitfalls: nested record keys need direct YAML edit).
6. **MCP servers**: prefer `npx`-based commands so the config is cross-OS. Direct binary paths (e.g. `~/.local/share/mise/.../zereight-mcp-gitlab`) do NOT exist on the other machine — swap to `npx -y zereight-mcp-gitlab ...`.
7. **Verify in the NATIVE context of the target machine**, not just the shell you're in:
   - Windows: `powershell -NoProfile -Command 'omp config get modelRoles'`, `omp ttsr list`, then one persona probe per tool (`omp -p "..."` / `opencode run "..."`). Versions + config get are free (no model call); do at least ONE real prompt per tool to prove model routing + persona.
   - Capture command output into a variable before grepping (`OUT=$(cmd 2>&1)`), never `cmd | grep -q` under `set -o pipefail` (SIGPIPE false negative — see Pitfalls).

## Windows-native pitfalls

- **PowerShell blocks npm CLI shims**: `opencode` resolves to `opencode.ps1` → "running scripts is disabled". Fix once: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force`. `opencode.cmd` exists but PowerShell prefers the .ps1.
- **Preset plugins override `opencode.json` `"model"`**: with oh-my-opencode-slim (or similar preset plugin), the active agent is the preset's `orchestrator` with the preset's model — not your top-level model. Symptom: `opencode run` uses a model you never picked (e.g. balance-gated `opencode-go/glm-5.1` → "Insufficient balance"). Fix: patch `presets.<name>.orchestrator.model` in the preset JSON. `opencode run --model X` still overrides for testing.
- **Per-model billing gating**: a coding-plan provider (opencode-go workspace) can serve some models free (deepseek-v4-flash) while others (glm-5.1, kimi-k2.7-code) need balance. Route blocked roles to a LOCAL ROUTER instead (see references/local-router-9router.md for the exact provider blocks).
- **MSYS absolute-path reads can fail**: `cat /c/Users/<user>/.../file` may throw "os error 3" while `cd <dir> && cat file` (relative) works and PowerShell `Test-Path` confirms the file exists. Workaround: cd + relative paths for reads; use write_file with `C:/Users/...` (forward slashes) for writes.
- **PATH**: `~/.bun/bin` (omp.exe) is usually already in User PATH; if `omp` is not found from PowerShell, append it with `[Environment]::SetEnvironmentVariable('Path', $env:Path + ';...', 'User')`.
- **Mise "pi" shim is the OLD agent** on both OSes — use `~/.bun/bin/omp` (17.x), never the stale 0.83 `pi` (403 RegionError from opencode-go gateway).

## Reference

- `references/local-router-9router.md` — 9router local-router pattern: omp `models.yml` + opencode `provider` blocks, advisor/orchestrator routing, verification probes (2026-08-06).
