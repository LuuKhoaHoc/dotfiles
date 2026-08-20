# OpenHuman safe config toggles (no OAuth required)

These are operator-patchable in `~/.openhuman/users/<id>/config.toml` without
needing the user to log into any service. They were the working set applied for
this user (profile `6a85f4f7018099b972f6ae17`, OpenHuman 0.63.7).

## Memory / learning (local, no external dependency)
```
[learning]
enabled = true            # was false — self-builds user profile over sessions

[heartbeat]
enabled = true            # was false — proactive suggestions/reminders
inference_enabled = true  # was false

[subconscious]
engine = "local"
subconscious_mode = "local"   # was off

[heartbeat]
goal_continuation_enabled = true   # was false
```

## Context window
```
[context]
super_context_enabled = true   # was false — bigger context for long tasks

[[model_registry]]
id = "ocg/mimo-v2.5"
provider = "9router"
context_window = 1000000   # was 0 -> app fell back to 200K display; fix to real 1M
```

## Autonomy
```
[autonomy]
level = "autonomous"   # was "supervised" — proactive in workspace (still workspace_only)
```

## Already ON by default (just verify)
- `[tokenjuice]` router_enabled / ccr_enabled = true (tool-output compression)
- `[orchestration] enabled = true` (parallel sub-agents)
- `[mcp_client] enabled = true`
- `[scheduler] enabled = true`, `[cron] enabled = true`

## Requires USER OAuth (operator CANNOT do — leave for user, note in report)
- `[composio] enabled = true` only enables the toolkit layer; each service
  (Gmail, Calendar, Notion, Telegram, GitHub) still needs the user to authorize
  in-app. OpenHuman cannot self-pass OAuth.
- `[meet]` infra can be enabled, but calendar connect + auto-join needs OAuth.

## Do NOT enable without the agentmemory VM up
```
[memory]
backend = "agentmemory"   # user opted OUT; keep "sqlite"
```
PITFALL: backend=agentmemory + daemon down = NO sqlite fallback, every memory
op errors loudly. Only set this when `https://mem.luukhoahoc.me/agentmemory/livez`
returns 200.
