#!/bin/bash

set -euo pipefail

MODE_FILE="$HOME/.config/hypr/.weather_location_mode"
ROFI_THEME="$HOME/.config/rofi/config-edit.rasi"
MSG='󰖙 Choose weather location mode'
SCRIPTSDIR="$HOME/.config/hypr/scripts"
MARKER="👉"

current_mode="current"
if [[ -f "$MODE_FILE" ]]; then
    saved_mode=$(tr '[:upper:]' '[:lower:]' < "$MODE_FILE" | tr -d '[:space:]')
    if [[ "$saved_mode" == "current" || "$saved_mode" == "hcm" ]]; then
        current_mode="$saved_mode"
    fi
fi

options=(
    "Current location"
    "Ho Chi Minh City"
)

selected_row=0
if [[ "$current_mode" == "hcm" ]]; then
    selected_row=1
fi

annotated_options=("${options[@]}")
annotated_options[$selected_row]="$MARKER ${annotated_options[$selected_row]}"

if pgrep -x rofi >/dev/null; then
    pkill rofi
fi

choice=$(printf '%s\n' "${annotated_options[@]}" | rofi -i -dmenu -config "$ROFI_THEME" -mesg "$MSG" -selected-row "$selected_row")
[[ -z "$choice" ]] && exit 0

choice=${choice#"$MARKER "}
case "$choice" in
    "Current location")
        printf 'current\n' > "$MODE_FILE"
        ;;
    "Ho Chi Minh City")
        printf 'hcm\n' > "$MODE_FILE"
        ;;
    *)
        exit 0
        ;;
esac

pkill -RTMIN+8 waybar 2>/dev/null || true
"$SCRIPTSDIR/Refresh.sh" >/dev/null 2>&1 &
