# Hyprland hot corners → hyprexpo overview (2026-08-14)

Task: macOS-style hot corner — cursor into the top screen corner opens hyprexpo overview (Mission Control), for fast mouse-driven app switching. End result: `hotcorn` daemon on `HDMI-A-1` TopRight → `hyprexpo:expo toggle`.

## Machine state at setup time

- Hyprland 0.56.2 (Arch), hyprexpo plugin v0.56.1+3 ALREADY installed & loaded:
  - `hyprctl plugins list` → `Plugin hyprexpo by sandwich, Handle 55b75bbfa110`
  - `plugin = ~/.cache/hyprexpo-src/build/libhyprexpo.so` in `~/.config/hypr/plugins/hyprexpo.conf`
  - Bindings `~/.config/hypr/plugins/hyprexpo-bindings.conf`: `SUPER+G` + 3-finger swipe up/down
  - Loaded via `exec-once = hyprctl plugin load ~/.cache/hyprexpo-src/build/libhyprexpo.so && hyprctl reload` in autostart
- Dispatcher verification: `hyprctl dispatch hyprexpo:expo toggle` → `ok` (note: dispatcher name is `hyprexpo:expo`, NOT `hyprexpo:overview`)
- Monitor layout (stacked): HDMI-A-1 at (1280,0) focused; eDP-1 at (1280,1080); both 1920x1080.
  - `hyprctl -j monitors` in 0.56 has NO `primary` key — use `focused` to find the main monitor.

## Candidate daemons (GitHub API search `hyprland hot corners`, 2026-08)

| Daemon | Stars | Config | Monitor handling |
|---|---|---|---|
| ArnoDarkrose/hyprcorners | 28 | `~/.config/hypr/hyprcorners.toml` (auto-created) | hardcoded `screen_width`/`screen_height` (default 1920x1080), coords assumed from (0,0) — breaks on layouts where monitors aren't at origin |
| chernyakoff/hotcorn | 4 | `~/.config/hotcorn/config.toml` (confy) | `monitor_name` option, reads size via hyprctl — **chosen** |

AUR has no hot-corner package for Hyprland (`yay -Ss` + AUR RPC `/rpc/v5/search` returned only GNOME/Xfce/lead-git). Build from source; cargo 1.97.1 present (Arch `rust` pkg). Build: 24.29s, 54 crates, binary 1.9M.

## hotcorn source behavior (222 lines, src/app.rs + config.rs)

- Polls `CursorPosition::get_async()` (GLOBAL coords) every `timeout_ms` (default 30; used 50).
- Per-trigger `inside` flag → edge-trigger: fires once when cursor ENTERS zone, re-arms on leave. `sticky_ms` (default 300) = min interval between triggers for the same zone.
- `get_monitor_size` reads ONLY width/height of the named monitor — no origin. Corner checks are size-relative:
  - TopRight = `x > w - radius && y < radius` — matches the layout's outer top edge regardless of monitor offset (works for any monitor placed on the top edge).
  - BottomRight = `x > w - radius && y > h - radius` — on stacked layouts this is a WIDE STRIP (everything below h - radius), not a corner. Only TopLeft/TopRight of the topmost monitor behave exactly.
- Dispatch: `Dispatch::call_async(DispatchType::Custom(&dispatcher, &args))` → any hyprctl dispatcher, including plugin dispatchers. So `action = { dispatcher = "hyprexpo:expo", args = "toggle" }` works.
- Config via `confy::load("hotcorn", ...)` → `~/.config/hotcorn/config.toml`; must be hand-created (no auto-generate). Serde: `type`/`position` are PascalCase enums (`Corner`, `TopRight`...).
- Exit on wrong monitor: `Monitor '<name>' not found` (anyhow error) — a running daemon proves the monitor resolved.
- No `--help`/`--version`: `hotcorn --help` starts the daemon and hangs → foreground timeout is the expected signal.

## Deployed config

`~/.config/hotcorn/config.toml`:
```toml
monitor_name = "HDMI-A-1"
timeout_ms = 50
sticky_ms = 300

[[triggers]]
type = "Corner"
position = "TopRight"
radius = 15
action = { dispatcher = "hyprexpo:expo", args = "toggle" }
```

Install: `install -m755 /tmp/hotcorn/target/release/hotcorn ~/.local/bin/hotcorn` (`~/.local/bin` already in PATH on this machine).
Autostart: `exec-once = ~/.local/bin/hotcorn` appended to `~/.config/hypr/autostart.conf`.

## Verification status

- Dispatch command: verified (`ok`).
- Daemon: running, monitor resolved.
- Corner detection: NOT yet verified — no `movecursortocorner` dispatcher exists in 0.56 (`hyprctl dispatchers | grep -i cursor` empty), so end-to-end test requires a real mouse (user moves cursor to top-right of HDMI). Daemon logs `Dispatching hyprexpo:expo toggle` per trigger for confirmation.

## Alternative considered (not used)

Self-written cursor-poll script (hyprctl cursorpos + monitors) — viable KISS fallback if the daemon dies, but hotcorn already handles edge-triggering + sticky interval correctly.
