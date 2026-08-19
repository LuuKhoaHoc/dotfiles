---
name: hermes-cron-jobs
description: "Use when creating, editing, or debugging Hermes cron jobs."
version: 1.0.0
author: hermes-curator
license: MIT
metadata:
  hermes:
    tags: [hermes, cron, scheduling, automation, reminders]
---

# Hermes cron jobs (scheduled agent runs)

## When to Use

- Creating recurring agent jobs for this user: GitLab review reminders, news digests,
  VM start, weekly cleanup, watchdogs.
- Debugging why a cron output never arrived ("job ran but I saw nothing").
- Adding jobs that must deliver to Telegram.

## CRITICAL: delivery trap (cost one pass)

Cron jobs created from a **desktop/CLI/TUI session default to `deliver: local`** —
output is saved but NOT delivered anywhere (those sessions have no live channel).
Symptom: job schedules and runs fine, user never sees it. Fix: pass `deliver='all'`
(or `'telegram:chat_id'`) explicitly on create/update — this user's gateway is
Telegram @picoclaw_leo_bot. Check the create/update response's `deliver` field:
`local` = invisible.

## Rules for job prompts

- **Self-contained**: the job runs in a fresh session with ZERO chat context. State the
  user, goal, exact tool instructions, output language (tiếng Việt for this user), and
  constraints inline.
- **Read-only unless told otherwise**: this user decides merges/deletes himself
  ('khoan merge'/'khoan commit' control). Cleanup/reporting jobs must explicitly say
  "CHỈ ĐỌC — không xóa/merge/đóng gì, chỉ báo cáo".
- Use `enabled_toolsets` (e.g. ["web"], ["terminal"]) when a job needs only one
  toolset; omit for MCP-heavy jobs unless certain of the toolset name.
- Give jobs explicit Vietnamese reporting style (concise, no emoji spam) and the
  exact fallback message when there is nothing to report.

## User's fleet (created 2026-08-13 — run `cronjob list` before creating new jobs to avoid duplicates)

| Job | Schedule | What |
|---|---|---|
| ai-news-digest | 08:00 daily | web_search AI news + trendshift.io; 5-8 items, links |
| gitlab-review-reminder | 08:30 daily | MRs awaiting review + assigned issues (MCP gitlab) |
| azure-vm-start-9h | 09:00 daily | runs `~/.local/bin/azure-vm-start` (VM auto-shutdown at ~0h; see skill selfhost-vm-deploy) |
| gitlab-weekly-cleanup | Fri 18:00 | merged branches + stale MRs + closed issues, report only |

User scheduling preferences: morning briefings (8:00-9:00); cleanup Friday evening or
daily evening — he rarely opens the machine on Sunday.

## Patterns

- **Watchdog**: `no_agent=True` + script; empty stdout = silent tick, non-zero exit =
  alert. Keep scripts' output byte-stable (no timestamps) or every tick looks changed.
- **Change detection**: `monitor_url` / `monitor_script` — first tick always runs;
  unchanged output suppresses the agent entirely.
- **Chains**: `context_from=<job_id>` feeds the upstream job's last output into the
  downstream job's prompt.
- After create: verify `next_run_at` in the response; test immediately with
  `action='run'` (runs in background, result re-enters the conversation).
- Jobs created from within a cron-run session need `cron.allow_agent_scheduling` in
  config.yaml.
