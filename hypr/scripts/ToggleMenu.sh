#!/bin/bash

case "${HYPRLAND_SHELL:-waybar}" in
    caelestia|quickshell|qs)
        exec caelestia shell drawers toggle launcher
        ;;
    *)
        exec rofi -show drun -modi drun,filebrowser,run,window
        ;;
esac
