---
name: orca-setup
description: Use when setting up or troubleshooting the Orca ADE.
---

# Orca ADE — Setup & Ops (Linux)

Orca (Stably) = Agent Development Environment chạy coding agents (Codex, Claude, opencode...) trong isolated Git worktrees. Binary tại `/opt/stably-orca`; CLI shim tại `~/.config/orca/linux-orca-cli-shim/orca`.

## Key paths
- Binary: `/opt/stably-orca/resources/bin/orca-ide`
- CLI shim: `~/.config/orca/linux-orca-cli-shim/orca`
- Config: `~/.config/orca/` — `orca-profile-index.json` (profiles/accounts), `orca-runtime.json` (PID/socket/auth), `profiles/local-default/orca-data.json` (repos, worktrees, linked issues/MRs)
- Worktrees: `~/orca/workspaces/<repo>/<host>-<encoded-path>-work_items-<N>` (vd `...-erp-admin-work_items-200`)
- Managed Codex homes: `~/.config/orca/codex-accounts/<uuid>/home/` (không có glab config riêng — dùng chung config user)

## Setup hiện tại (đã hoàn thành)
1. PATH: `export PATH="$HOME/.config/orca/linux-orca-cli-shim:$PATH"` trong `~/.zshrc` — **user dùng zsh, không đọc `.bashrc`**
2. Verify: `orca status` → appRunning/runtimeState ready
3. `orca account list` — managed Codex accounts; `orca skills list` — skill guides bundled (orca-cli, computer-use, orchestration, orca-linear...)

## Codex OAuth trong Orca
Orca KHÔNG add được Codex OAuth account khi `~/.codex/config.toml` pin custom provider (vd `model_provider = "9router"`). Fix:
- Set `model_provider = "openai"` (hoặc xóa dòng) → Orca add OAuth OK
- Giữ nguyên block `[model_providers.9router]` để switch lại sau

## GitLab công ty (gitlab.vppos.vn)
- Orca detect GitLab qua `git remote -v` identity (SSH URL), không cần OAuth riêng
- Orca đọc Issues/MRs bằng `glab api` — glab phải auth OK
- **PITFALL**: `GITLAB_TOKEN` env var override token trong `~/.config/glab-cli/config.yml`. Env token cũ/hết hạn → Orca UI báo "Failed to load Issues; glab: 401 Unauthorized" dù config token vẫn sống. Fix: xóa `GITLAB_TOKEN` khỏi shell rc files (backup trước), glab fallback về config.yml. Chi tiết: `references/glab-gitlab-401.md`
- **PITFALL**: Orca process giữ env cũ sau khi sửa rc files — phải restart app hoàn toàn từ UI. CLI **không có** lệnh quit (`orca quit` không tồn tại).

## Verification
```bash
orca status                                      # appRunning / runtimeState / graphState
orca account list                                # managed accounts
orca skills list                                 # installed skill guides
glab auth status                                 # token source + validity (xem cảnh báo env override)
env -u GITLAB_TOKEN glab api -i "projects/vppos-team%2Ferp-admin/merge_requests?state=opened"   # test sạch
```

## Pitfalls
- Shell của user là **zsh** — rc files `~/.zshrc`/`~/.zshenv`, không `.bashrc`
- `gitlab.vppos.vn` SSH port 2222 (`ssh://git@gitlab.vppos.vn:2222/...`)
- Worktree meta (linkedGitLabIssue/MR) nằm trong `orca-data.json` — dùng để kiểm tra link issue/MR khi debug
