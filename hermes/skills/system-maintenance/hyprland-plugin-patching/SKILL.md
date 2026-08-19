---
name: hyprland-plugin-patching
description: Patch Hyprland plugins from source for custom features.
---

# Hyprland Plugin Patching

## When to Use

- A Hyprland plugin is missing a config option you need
- A plugin has a bug in Lua config mode
- Building plugins from source (not via hyprpm)

## Build Workflow

```bash
git clone --depth 1 <repo-url> /tmp/plugin-name
cd /tmp/plugin-name
cmake -DCMAKE_BUILD_TYPE=Release -B build-cmake
cmake --build build-cmake -j$(nproc)
cp build-cmake/lib<plugin>.so ~/.local/lib/<plugin>.so
```

## Runtime

```bash
hyprctl plugin unload ~/.local/lib/<plugin>.so
hyprctl plugin load ~/.local/lib/<plugin>.so
hyprctl plugin list
hyprctl configerrors
```

## Key Pitfalls

1. Plugin calls reloadConfig() after loading - guard Lua bindings with nil check
2. Config values registered in PLUGIN_INIT via INT_CONF/FLOAT_CONF macros
3. hyprpm may fail with header mismatch - build manually instead
4. Binary persists but may break on upstream update - maintain fork

## Contributing Back

1. Fork repo, create feature branch
2. Minimal focused changes (one feature per PR)
3. Build, test, push, create PR with problem + solution description
