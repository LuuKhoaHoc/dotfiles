---
name: hermes-cron-ops
description: "Use when creating or debugging Hermes cron jobs."
version: 1.0.0
author: hermes-curator
license: MIT
metadata:
  hermes:
    tags: [hermes, cron, scheduling, automation, github-actions, digest]
    related_skills: [selfhost-vm-deploy, google-workspace-mcp]
---

# Hermes cron job operations (verified 2026-08-14)

## Trigger

- User wants a recurring/scheduled agent task ("mỗi sáng", "hằng tuần", "nhắc review", "digest", "watchdog").
- A cron job isn't firing, isn't delivering, or runs while the laptop is off.
- An always-on infra task (start VM, ping service) that must run even when the local machine is asleep.

## Core facts (learned the hard way)

- **Cron jobs run on the Hermes host machine** — for this user that's the LOCAL Arch laptop, NOT the Azure VM. Laptop off/sleeping at fire time = job silently missed. User arrives at the office ~9:15 and opens Hermes after 9h → any job scheduled before ~9:30 never runs on workdays. Schedule early-morning jobs AFTER the laptop-on time.
- **Default `deliver` is `local`** (output saved, not sent anywhere). Creating a job from the desktop app gives `deliver: local` — ALWAYS update it to `deliver='all'` (this user's Telegram gateway @picoclaw_leo_bot) or nobody sees the result. Check the create response; if it says `deliver: local`, update.
- **`enabled_toolsets` restricts tools**: `["web"]` blocks MCP servers (gmail/gitlab). Jobs needing MCP tools must omit enabled_toolsets (all tools) or the MCP calls fail/permission-error.
- **Newly added MCP servers are invisible to running sessions.** The gateway daemon connects MCP servers at startup. The agent CANNOT restart the gateway itself (policy blocks `hermes gateway restart` / `systemctl --user restart hermes-gateway` from inside the gateway process — SIGTERM propagates to the agent). The USER must run `hermes gateway restart` in a separate terminal; until then, fresh cron sessions still lack the new tools.
- **Test a job immediately** with cronjob(action='run') — outcome re-enters the chat as a delegation-complete message with the job's full output.
- **Always-on infra tasks → GitHub Actions, not local cron** (e.g. start Azure VM at 9:00 while the laptop is off, weekends included). Workflow `on.schedule: - cron: "0 2 * * *"` (UTC = 9:00 ICT) + `workflow_dispatch:` for manual runs. Secrets live in repo Settings → Secrets → Actions (never in the public dotfiles repo). Push the workflow with plain git — `gh` may not be authenticated. Script reads creds from env `${{ secrets.X }}`.

## Verified job set (this user, 2026-08-14)

| Job | Schedule | Tools | Notes |
|---|---|---|---|
| ai-news-digest | `30 9 * * *` (after laptop on) | all (needs MCP gmail×3 + web) | 2-part digest: mail (3 mailboxes) + AI news (web_search + trendshift.io) |
| gitlab-review-reminder | `0 10 * * *` | all (MCP gitlab) | read-only: MRs needing review + assigned issues |
| gitlab-weekly-cleanup | `0 18 * * 5` | all (MCP gitlab) | read-only report: merged branches, stale MRs, closed issues — NEVER delete/merge (user decides) |
| azure-vm-start | GH Actions `0 2 * * *` UTC | GitHub runner | starts 9router-vm via service-principal REST (see selfhost-vm-deploy) |

## Prompt patterns that work

- State the user's role up front ("Lưu Khoa Học — người giao task và review code") — the job session has no context.
- **Read-only by default** for anything that mutates (delete branch, merge, close issue): "CHỈ ĐỌC — tuyệt đối không xóa/merge/đóng gì, user tự quyết" — this user controls destructive actions.
- Mail digest per mailbox: `search_threads` with `newer_than:2d`, filter importance keywords (urgent/invoice/deadline/meeting/review/khách hàng/hợp đồng/xác nhận), skip spam/newsletters; output: important mail ≤8 one-liners + 3-5 proposed action items; per-mailbox error → note "[hộp N: lỗi]" and continue with the rest.
- Script-backed jobs: instruct the agent to run the script, then map exit codes to a short human report (0 = ok, 1 = still starting, 2 = auth, 3 = not found).

## Pitfalls

- Creating a job and forgetting `deliver` → job "runs" but the user never sees output.
- Scheduling before the laptop-on time → silent misses (the user's workday starts ~9:15; weekends nobody is on the machine).
- `enabled_toolsets: ["web"]` on a mail digest → MCP gmail tools missing → the whole mail section errors.
- After adding MCP servers, testing in the CURRENT chat session fails (session predates the servers) — verify via a fresh cron run, not the live chat.
- GitHub Actions `schedule` is UTC: 9:00 ICT = `0 2 * * *`.
- Never put credentials in the public dotfiles repo — use repo Actions secrets.
