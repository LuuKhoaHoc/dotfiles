# Removing a Hyprland plugin cleanly (2026-08: hyprexpo removal case, Omarchy v4)

A plugin is never just `rm` the `.so`. The live references live in places you don't expect.
One grep sweep first: `grep -rn <plugin-name> ~/.config/` (and `~/.local/state/omarchy/`).

## Checklist — ALL of these

1. `~/.config/hypr/plugins/<plugin>.conf` + `<plugin>-bindings.conf`
   (keybinds often live here, e.g. SUPER+G → `hyprexpo:expo toggle`)
2. `source = .../<plugin>*.conf` lines in `~/.config/hypr/hyprland.conf`
   (dead under Lua config provider but still referenced — confuses later readers)
3. `exec-once = hyprctl plugin load <path>.so` in `~/.config/hypr/autostart.conf`
   — under Omarchy this was the actual loader
4. `~/.config/omarchy/hooks/post-update.d/*` rebuild hooks (drop-in dir; `*.sample` inactive)
5. `~/.cache/<plugin>-src/` source+build dir (~20MB+)
6. **Custom daemons/services that dispatch TO plugin dispatchers** — e.g. hotcorn:
   `~/.config/hotcorn/` + `~/.config/systemd/user/hotcorn.service`, whose `.toml`
   actions look like `action = { dispatcher = "hyprexpo:expo", args = "toggle" }`.
   These fail silently (unknown dispatcher) after plugin removal.
   Ask the user before deleting a custom daemon (it may be repurposable);
   if deleted: `systemctl --user stop`, `systemctl --user disable`,
   remove unit + config + binary, `systemctl --user daemon-reload`.

## Verify after removal

```
hyprctl reload
hyprctl plugins list        # → "no plugins loaded"
hyprctl configerrors        # empty
```

## Harmless leftover matches (ignore)

- Browser profile `Preferences` JSON (site history mentions the plugin name)
- `~/.cache/yay/completion.cache` (AUR package-name cache)

## Coupling note: hyprexpo ↔ hotcorn

hotcorn exists mostly to trigger `hyprexpo:expo` from the mouse. Removing hyprexpo
makes hotcorn pointless (confirm with user before deleting the daemon); keeping
hotcorn without hyprexpo leaves dead corner triggers. Remove both or neither.