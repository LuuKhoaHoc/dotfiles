#!/bin/bash

# Require tmux and tmuxinator to be installed first
# Get the list of projects from the tmuxinator config directory (remove .yml extension)
PROJECTS=$(ls ~/.config/tmuxinator/ | grep '\.yml$' | sed 's/\.yml//')

# If there are no projects, notify and exit
if [ -z "$PROJECTS" ]; then
    notify-send "Tmuxinator" "No projects configured!"
    exit 1
fi

# Display the list via Rofi and save the user's selection
# JaKooLit's theme has configured Rofi to be very beautiful, you just need to call dmenu
SELECTED=$(echo "$PROJECTS" | rofi -dmenu -i -p "🚀 Open Project" -theme-str 'window {width: 20%;}')

# If the user selects a project (does not press Esc to exit)
if [ -n "$SELECTED" ]; then
    TERMINAL_BIN="${TERMINAL:-kitty}"
    SHELL_BIN="${DEFAULT_SHELL:-zsh}"

    case "${HYPRLAND_SHELL:-waybar}" in
        caelestia|quickshell|qs)
            TERMINAL_BIN="${TERMINAL:-foot}"
            SHELL_BIN="${DEFAULT_SHELL:-fish}"
            ;;
        *)
            TERMINAL_BIN="${TERMINAL:-kitty}"
            SHELL_BIN="${DEFAULT_SHELL:-zsh}"
            ;;
    esac

    "$TERMINAL_BIN" -e "$SHELL_BIN" -lc "tmuxinator start '$SELECTED'" &
    notify-send "Start Workspace" "Opening project: $SELECTED"
fi
