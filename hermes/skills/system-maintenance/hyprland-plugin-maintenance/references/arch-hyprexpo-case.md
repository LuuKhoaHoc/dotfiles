# Case: hyprexpo broken after Hyprland 0.56.2 update (2026-08-10, Omarchy 3.8.4)

## Error transcript (hyprctl configerrors, from screenshot)
```
Config error in file ~/.config/hypr/plugins/hyprexpo.conf at line 11:
  Invalid value 200 for finger count
Config error in file ~/.config/hypr/plugins/hyprexpo-bindings.conf at line 2:
  Invalid dispatcher, requested "hyprexpo:expo" does not exist
```
Plus: `hyprctl plugin list` → `no plugins loaded`.

The "200 for finger count" was `gesture_distance = 200` (line 11) misread by a stale
plugin's parser — NOT a real config mistake. Dispatcher error was a cascade (plugin not loaded).

## Root cause
1. Plugin built manually from source (~/.cache/hyprexpo-src, old commit 7572889) against an
   older Hyprland → ABI mismatch with 0.56.2.
2. Config used legacy `permission = /path/libhyprexpo.so, plugin, allow` (ancient Hyprland
   syntax) — no `plugin =` line existed, so nothing loaded the .so.

## hyprpm dead-end (why Route B)
- `hyprpm add <repo>` → `✖ Headers outdated, please run hyprpm update.`
- `hyprpm update` → clone ok, `✔ checked out to running ver`, build ok, then
  `✖ failed to install headers with error code 4 (Headers version mismatched)`
- `hyprpm -v update` parsed the version correctly:
  `[v] parsed commit efb50993780079460b0cbed1363e2166a2de1d9f at branch v0.56.2 ...`
  yet install always fails. Upstream: hyprwm/Hyprland#7112, discussion #12232,
  Alpine aports#17576 (truncated-hash variant), Arch packaging issue #30 (fixed 0.52.1, still broken later).
- `hyprpm purge-cache` → `[ERR] Failed to run a superuser cmd` (internal sudo, no TTY).
- Conclusion: on Arch, don't fight hyprpm; build the plugin manually (system headers exist).

## sudo / SUDO_PASSWORD findings (Hermes terminal)
- `SUDO_PASSWORD=...` in `~/.hermes/.env` auto-feeds sudo for FOREGROUND commands (tested:
  `sudo -k -v` returns ELEVATED without typing; works with or without pty).
- BACKGROUND commands get NO auto-feed: `sudo: a terminal is required to read the password`.
  Fix for background: `printf 'pass\n' | sudo -S <cmd>`.
- `sudo -n` never works with the env-based feed (non-interactive, no prompt to intercept).
- hyprpm spawns sudo internally, so it also needs a foreground/pty context.

## Fix that worked (Route B)
```bash
cd ~/.cache/hyprexpo-src && git pull --ff-only   # 7572889 → 40352e2 (master, hyprexpo+)
rm -rf build && cmake -S . -B build && cmake --build build -j"$(nproc)"
# → build/libhyprexpo.so (2.0M, built against /usr/include/hyprland 0.56.2)
```
Config change in ~/.config/hypr/plugins/hyprexpo.conf:
```diff
-permission = /home/luukhoahoc/.cache/hyprexpo-src/build/libhyprexpo.so, plugin, allow
+plugin = /home/luukhoahoc/.cache/hyprexpo-src/build/libhyprexpo.so
```
Verify chain:
```
hyprctl reload
hyprctl configerrors        # empty
hyprctl plugin list         # "Plugin hyprexpo by sandwich ... Version: v0.56.1+3"
hyprctl dispatch hyprexpo:expo toggle   # ok (twice = open + close)
```
Note: `hyprctl dispatchers` needs an arg in 0.56 — don't use it to grep plugin dispatchers.

## Auto-rebuild hook (installed & seeded)
`~/.config/omarchy/hooks/post-update.d/hyprexpo-rebuild` (chmod +x; drop-in dir, `.sample`
files are inactive). Version-stamp pattern:

```bash
#!/bin/bash
SRC="$HOME/.cache/hyprexpo-src"; STAMP="$SRC/.hyprland-version"; SO="$SRC/build/libhyprexpo.so"
CUR="$(hyprctl version 2>/dev/null | head -1)"
[ -z "$CUR" ] && exit 0
if [ -f "$STAMP" ] && [ "$(cat "$STAMP")" = "$CUR" ] && [ -f "$SO" ]; then exit 0; fi
cd "$SRC" || exit 1
git pull --ff-only >/dev/null 2>&1 || true
if ! cmake --build build -j"$(nproc)" >/dev/null 2>&1; then
  rm -rf build
  cmake -S . -B build >/dev/null 2>&1 || { notify-send -u critical "hyprexpo rebuild FAILED" "cmake configure failed"; exit 1; }
  cmake --build build -j"$(nproc)" >/dev/null 2>&1 || { notify-send -u critical "hyprexpo rebuild FAILED" "build failed - check $SRC"; exit 1; }
fi
echo "$CUR" > "$STAMP"
notify-send -u low "hyprexpo rebuilt" "Plugin rebuilt for $CUR - restart Hyprland session to load it"
```
Seed the stamp after installing so the next update doesn't rebuild pointlessly:
`hyprctl version | head -1 > ~/.cache/hyprexpo-src/.hyprland-version`.

## Other facts from this session
- Omarchy hooks live at `~/.config/omarchy/hooks/<name>.d/` (post-update, theme-set, font-set,
  post-boot, battery-low). Other hook types: theme-set/font-set receive $1 (name).
- hyprexpo history: retired from hyprwm/hyprland-plugins → fork sandwichfarm/hyprexpo
  ("hyprexpo+"). Issue #624 there = same "Invalid value N for finger count" symptom after updates.
- Hyprland 0.55+ Lua config: `hl.config({...})`, `hl.bind(...)`; `.conf` removal in 0.57.
- nwg-displays now writes BOTH monitors.conf and monitors.lua; omarchy 0.56-era configs still
  source monitors.conf.
