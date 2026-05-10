#!/bin/bash

PROFILE="${HYPRLAND_SHELL:-waybar}"

case "$PROFILE" in
    caelestia|quickshell|qs)
        exec foot -e fish "$@"
        ;;
    *)
        exec kitty -e zsh "$@"
        ;;
esac
