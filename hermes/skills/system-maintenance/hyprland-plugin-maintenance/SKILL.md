---
name: hyprland-plugin-maintenance
description: Use when Hyprland plugins break or hyprpm fails.
---

# Hyprland Plugin Maintenance

Manage Hyprland plugins (hyprexpo, hy3, ...) on Arch/Omarchy: diagnose load failures, rebuild after Hyprland updates, work around broken hyprpm.

## When to use
- Plugin errors appear after a Hyprland/`omarchy update` (config errors, "no plugins loaded", "Invalid dispatcher ... does not exist")
- Garbage config-parse errors like `Invalid value 200 for finger count` — classic ABI-mismatch symptom (a value from one key is misread as another)
- Setting up auto-rebuild so plugins survive future updates

## Golden rule: plugins are ABI-sensitive
A plugin `.so` must be built against the EXACT running Hyprland version. After any Hyprland update, every plugin must be rebuilt. Stale plugin → config block parses garbage, plugin won't load, dispatcher missing.

## Diagnose (in order)
1. `hyprctl version` — running version (compare with what the plugin was built for)
2. `hyprctl plugin list` — is the plugin loaded at all?
3. `hyprctl reload` then `hyprctl configerrors` — config parse errors
4. `hyprctl dispatch <plugin>:<dispatcher> toggle` — does the dispatcher actually run? (Returns `ok` even visually; a missing dispatcher errors)

## Route A: hyprpm (preferred where it works)
```
hyprpm update && hyprpm add <repo-url> && hyprpm enable <name> && hyprpm reload
```
Pitfalls:
- **hyprpm refuses root**: "Don't run hyprpm as a superuser" — never `sudo hyprpm`. Its internal elevation ("Failed to run a superuser cmd") means a TTY is required.
- **Broken on Arch**: known bug `failed to install headers with error code 4 (Headers version mismatched)` — hyprwm/Hyprland#7112, discussion #12232, Alpine aports#17576. Version parses fine in verbose mode (`parsed commit ... at branch ...`) yet headers install always fails; no workaround except downgrade. Hit this → go Route B.
- `hyprpm purge-cache` also needs the internal sudo (same failure).

## Route B: manual source build (works on Arch, no root)
Arch's `hyprland` package ships headers: `pkg-config --modversion hyprland` → e.g. `0.56.2`. Build deps: cmake, g++, lua5.4, pixman-1, libdrm, pangocairo, libinput, libudev, wayland-server, xkbcommon (check with `pkg-config --exists ...`).

```bash
cd ~/.cache/hyprexpo-src            # or clone the plugin repo there
git pull --ff-only
rm -rf build && cmake -S . -B build && cmake --build build -j"$(nproc)"
```

Config line — **modern syntax** (legacy `permission = <path>, plugin, allow` silently no longer loads the plugin in 0.56+):
```
plugin = /home/<user>/.cache/hyprexpo-src/build/libhyprexpo.so
```
The `plugin { <name> { ... } }` config block below it uses the classic keys.

Verify: `hyprctl reload` → `hyprctl configerrors` empty → `hyprctl plugin list` shows the plugin → `hyprctl dispatch <plugin>:<disp> toggle` → `ok`.

## Auto-rebuild: omarchy post-update hook
`~/.config/omarchy/hooks/post-update.d/` is a **drop-in dir** of bash scripts (files named `*.sample` are inactive — rename to activate; `chmod +x`).
Pattern: stamp file holding `hyprctl version | head -1`; if changed → git pull + rebuild + `notify-send`. Full working script: `references/arch-hyprexpo-case.md`.
**Do NOT `hyprctl reload` inside the hook**: the running session is still the OLD Hyprland binary; the new `.so` matches new headers and only loads at next login.

## Hyprland Lua transition (context)
- 0.55+ moved config to Lua (`hyprland.lua`); `.conf` deprecated, **removed in 0.57** → a warning toast appears on 0.56.x
- Omarchy 3.8.4 (2026-08) still ships `.conf` — the toast is cosmetic; do NOT hand-migrate user configs to Lua (omarchy refresh would overwrite/conflict)

## Pitfalls
- After rebuilding for NEW headers while an OLD session still runs: don't reload the plugin mid-session — ABI mismatch errors until re-login
- `hyprctl dispatchers` in 0.56 requires an argument ("Not enough arguments in '/dispatchers'") — verify via `hyprctl dispatch ... toggle` instead
- hyprexpo specifics: maintained at sandwichfarm/hyprexpo (hyprexpo+, v0.56.x). Classic keys (columns, gaps_in, gaps_out, bg_col, workspace_method, gesture_distance, cancel_key, show_cursor, show_pinned_windows) still valid; removed keys: `gesture_positive`, `enable_gesture`

## References
- `references/arch-hyprexpo-case.md` — 2026-08-10 case: exact error transcript, issue links, hook script, command cheat-sheet
