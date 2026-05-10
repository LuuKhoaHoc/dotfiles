#!/bin/bash

QUICKSHELL_DIR="$HOME/.config/quickshell/caelestia"
TARGET_PROFILE="${HYPRLAND_SHELL:-waybar}"

start_waybar() {
    pkill quickshell 2>/dev/null || true
    pkill ags 2>/dev/null || true
    pkill waybar 2>/dev/null || true

    export TERMINAL=kitty
    export DEFAULT_SHELL=zsh

    dbus-update-activation-environment --systemd HYPRLAND_SHELL TERMINAL DEFAULT_SHELL >/dev/null 2>&1 || true
    systemctl --user import-environment HYPRLAND_SHELL TERMINAL DEFAULT_SHELL >/dev/null 2>&1 || true

    awww-daemon --format xrgb >/dev/null 2>&1 &
    disown || true
    waybar >/dev/null 2>&1 &
}

start_caelestia() {
    pkill waybar 2>/dev/null || true
    pkill awww-daemon 2>/dev/null || true
    pkill ags 2>/dev/null || true
    pkill quickshell 2>/dev/null || true

    export TERMINAL=foot
    export DEFAULT_SHELL=fish

    dbus-update-activation-environment --systemd HYPRLAND_SHELL TERMINAL DEFAULT_SHELL >/dev/null 2>&1 || true
    systemctl --user import-environment HYPRLAND_SHELL TERMINAL DEFAULT_SHELL >/dev/null 2>&1 || true

    quickshell -c "$QUICKSHELL_DIR" &
}

case "$TARGET_PROFILE" in
    caelestia|quickshell|qs)
        export HYPRLAND_SHELL=caelestia
        start_caelestia
        ;;
    *)
        export HYPRLAND_SHELL=waybar
        start_waybar
        ;;
esac
