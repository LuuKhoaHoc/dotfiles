---
name: hermes-configuration
description: "Diagnose and fix Hermes style, personality, and config change issues. Understands the session-snapshot model."
version: 1.0.0
---

# Hermes Configuration

Where Hermes reads style/identity from, and why changes often appear to not work.

## Style Sources (priority, but all co-exist)

| Source | Scope | Editable Via |
|--------|-------|--------------|
| `display.personality` in `config.yaml` | Communication style (kawaii, noir, etc.) | `hermes config set display.personality NAME` |
| `~/.hermes/SOUL.md` | Core identity, language preference | Direct edit |
| `AGENTS.md` / `.hermes.md` / `CLAUDE.md` (cwd or git root walk) | Project-specific rules | Direct edit in repo |
| Loaded skills | Task procedures (rarely style) | `skills_list()` |
| Active plugins | Code/workflow rules (NOT prose) | `hermes plugins list` |

## The Session Snapshot Rule

Hermes snapshots the system prompt at startup to preserve prompt caching. **Many changes require a fresh session to take effect.**

Needs `/new`, `/reset`, or close+reopen:
- `display.personality`
- Toolsets enabled/disabled
- Skills added/removed
- Plugins enabled/disabled
- `SOUL.md` edits
- `AGENTS.md` / `.hermes.md` edits

Takes effect immediately:
- `hermes config set` for runtime values (timeouts, thresholds)
- File read/write (obviously)

## Troubleshooting: "Why is my style still X?"

Ordered checklist:

1. **Restart session yet?** Most common cause.
2. Check `~/.hermes/SOUL.md` — style rules here override personality silently.
3. Check loaded skills: `skills_list()` for any injecting prose rules.
4. Check active plugins: `hermes plugins list` — e.g. ponytail injects lazy-dev rules for code, NOT terse prose, but verify anyway.
5. Check cwd for `AGENTS.md` / `.hermes.md` / `CLAUDE.md` / `.cursorrules`.
6. Verify config: `hermes config set display.personality <name>` then restart.
7. Config drift: `hermes config check` — outdated `_config_version` can suppress new features.

## Personality vs Plugin vs Skill

- **Personality** = how you talk (kawaii, caveman, noir). Snapshot at session start.
- **Plugin** = code/workflow governance (ponytail = lazy dev ladder). Injected per-turn via hooks.
- **Skill** = task procedures (how to do X). Loaded when `skill_view` called or preloaded via `-s`.

Plugins do not replace personality. Changing personality does not affect plugin code rules.

## References

See `hermes-agent` skill for full CLI reference and provider setup.