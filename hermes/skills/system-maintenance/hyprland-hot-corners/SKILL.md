---
name: hyprland-hot-corners
description: >
  Use when setting up Hyprland hot corners (macOS-style).
version: 1.0.0
author: hermes-curator
license: MIT
metadata:
  hermes:
    tags: [hyprland, omarchy, hot-corners, hyprexpo, wayland]
    related_skills: [omarchy, hyprland-plugin-maintenance]
---

# Hyprland Hot Corners (hotcorn daemon)

## When to Use

- User wants macOS-style hot corners on Hyprland/Omarchy: cursor to a screen corner triggers an action (hyprexpo overview, workspace switch, etc.).
- Setting up or fixing the `hotcorn` daemon, or re-applying it on a new machine.
- Adding/changing which corner triggers which action.

Set up hot corners like macOS (cursor to a screen corner → run an action), e.g. open the hyprexpo overview for mouse-driven app switching.

Verified setup (Omarchy, Hyprland 0.56, Aug 2026): laptop eDP-1 + external HDMI-A-1 stacked at global offset (1280,0), hyprexpo plugin already installed by Omarchy.

## Prerequisites / checks

1. Hyprexpo installed & loaded?
   ```bash
   hyprctl plugins list            # shows "hyprexpo by sandwich"
   ls ~/.config/hypr/plugins/      # hyprexpo.conf + hyprexpo-bindings.conf
   ```
   Trigger dispatcher (NOT `hyprexpo:overview`): `hyprctl dispatch hyprexpo:expo toggle` → prints `ok`.

2. Get monitor layout (global x/y offsets matter!):
   ```bash
   hyprctl -j monitors | python3 -c "import json,sys; [print(m['name'], m['x'], m['y'], m['width'], m['height'], 'focused' if m['focused'] else '') for m in json.load(sys.stdin)]"
   ```

## Daemon choice

| Tool | Pros | Cons |
|------|------|------|
| **hotcorn** (chernyakoff/hotcorn, Rust) | `monitor_name` aware, `sticky_ms` anti-spam, Corner/Edge/Rect triggers, TOML config | build from source; Corner check assumes monitor at (0,0) |
| hyprcorners (ArnoDarkrose, Rust) | `cargo install hyprcorners` | hardcoded screen_width/height in config — breaks on non-(0,0) monitor layouts |

Use **hotcorn**. Not in AUR; build from source (cargo ~25s, needs `cargo` present).

## Install

```bash
git clone --depth 1 https://github.com/chernyakoff/hotcorn /tmp/hotcorn
cd /tmp/hotcorn && cargo build --release
install -m755 target/release/hotcorn ~/.local/bin/hotcorn   # ~/.local/bin is on PATH
```

## Config — `~/.config/hotcorn/config.toml` (confy path, create manually)

```toml
monitor_name = "HDMI-A-1"     # must exist or daemon exits silently at startup
timeout_ms = 50               # cursor poll interval
sticky_ms = 300               # min interval between re-triggers (anti-spam, edge-triggered on enter)

[[triggers]]
type = "Corner"
position = "TopLeft"          # TopLeft/TopRight/BottomLeft/BottomRight
radius = 15
action = { dispatcher = "hyprexpo:expo", args = "toggle" }
```

### ⚠️ CRITICAL PITFALL — Corner triggers and monitor offsets

`hotcorn` computes corners against `[0..width] x [0..height]` — it **assumes the monitor starts at global (0,0)** and ignores its x/y offset. On any layout where the chosen monitor is not at (0,0) (e.g. HDMI at (1280,0)):

- `TopRight` still works by accident (only lower bound `x > width - radius` is checked)
- `TopLeft`/`BottomLeft` NEVER fire (global x is never < radius)
- `BottomRight` fires in a wrong wide region

Fix: use a `Rect` trigger with the monitor's **global** coordinates (from `hyprctl -j monitors`):

```toml
[[triggers]]
type = "Rect"
x = 1280    # monitor x offset
y = 0       # monitor y offset
width = 15
height = 15
action = { dispatcher = "hyprexpo:expo", args = "toggle" }
```

## Autostart — systemd user service (preferred over exec-once)

Running the daemon as a Hermes/terminal background process is session-scoped — it dies when the session ends. Use a systemd user service instead (Omarchy/UWSM has a running user session):

`~/.config/systemd/user/hotcorn.service`:
```ini
[Unit]
Description=hotcorn daemon - Hyprland hot corners
After=graphical-session.target

[Service]
ExecStart=/home/<user>/.local/bin/hotcorn-bin
Restart=always
RestartSec=2

[Install]
WantedBy=default.target
```
```bash
systemctl --user daemon-reload
systemctl --user enable --now hotcorn.service
systemctl --user is-active hotcorn.service   # active
```
REMOVE the `exec-once = ~/.local/bin/hotcorn` line from `~/.config/hypr/autostart.conf` — otherwise two instances run. Verify restart-on-death: `kill $(pgrep -f hotcorn-bin)` → a new PID appears ~2s later.

## Verify

1. Run `hotcorn` in a tracked background process (`terminal` background=true), then `process(action='poll')` — no crash + no "Monitor not found" = config parsed.
2. Ask the user to actually move the cursor into the corner (no way to fake cursor movement: no `movecursortocorner` dispatcher in Hyprland 0.56, Wayland needs root ydotool).
3. Daemon prints `Dispatching hyprexpo:expo toggle` on every trigger — check the process log.

## Pitfalls

- **`hotcorn` exits silently on ANY transient hyprctl error.** Its loop is `CursorPosition::get_async().await?` / `Dispatch::call_async().await?` — one failed socket call (Hyprland reload, monitor unplug/plug, brief hiccup) and the `?` propagates an error → daemon dies with no log. It does NOT auto-restart. Fix: watchdog wrapper (verified):
  ```bash
  # mv ~/.local/bin/hotcorn ~/.local/bin/hotcorn-bin
  # ~/.local/bin/hotcorn becomes:
  #!/bin/bash
  while true; do
      hotcorn-bin
      sleep 2
  done
  ```
  Keep the same `exec-once = ~/.local/bin/hotcorn` in autostart (now the wrapper). Test the watchdog by killing the child: `kill <hotcorn-bin pid>` then check a fresh pid appears ~2s later. Note: if the wrapper itself fails to start with exit 126 "Permission denied", the script lost its +x bit — `chmod +x` it. **Preferred**: skip the wrapper entirely and run `hotcorn-bin` via a systemd user service with `Restart=always` (see Autostart section) — one layer of supervision, survives session teardown.
- **Hyprexpo overview is per-monitor BY DESIGN** (verified in sandwichfarm/hyprexpo source): the overview opens on the monitor under the cursor (`pMonitor` from mouse coords) and the grid is built from Hyprland's relative `r`/`m` workspace selectors, which only walk workspaces on the SAME monitor. No option (`dynamic_grid` included) shows workspaces from multiple monitors in one grid. Multi-monitor user expectation "show everything" → not possible; offer per-monitor usage (point cursor at the monitor whose workspaces you want) or an app switcher like `hyprswitch` (shows ALL windows across monitors/workspaces, mouse-selectable — closest to macOS Mission Control).
- `hotcorn --help` does NOT exist — running it just starts the loop; don't timeout-test it in foreground.
- Config is loaded via `confy` from `~/.config/hotcorn/config.toml`; there is no auto-generated default — write the file yourself.
- Corner/Edge triggers are de-duplicated (first wins); Rect triggers are not.
- **`monitor_name` must reference an ALWAYS-PRESENT monitor.** If it names an external monitor (e.g. `HDMI-A-1`) and the user boots undocked, the daemon exits at startup with `Monitor '<name>' not found` — and under a systemd user service with `Restart=always` this is a silent CRASH-LOOP (observed 78,614 restarts in one session!), NOT "harmless". The named monitor is used ONLY for (a) startup existence check and (b) width/height (hotcorn src/app.rs `get_monitor_size`) — triggers are evaluated against GLOBAL cursor coords with NO monitor-membership gating (config.rs `Trigger::check`, Rect = `x <= cx <= x+w && y <= cy <= y+h`). Robust fix: point `monitor_name` at the internal display (eDP-1, always exists) and declare Rect triggers at global coords for EVERY layout (docked + undocked + origin-fallback); dead rects in monitor-less regions simply never fire.
- Changing monitor layout (new dock, re-arranged positions) breaks hardcoded Rect coordinates — update config, mention this to the user.
- `sticky_ms` = debounce; without it, holding the cursor in the corner re-triggers repeatedly.
