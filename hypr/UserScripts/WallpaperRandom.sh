#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##
# Script for Random Wallpaper ( CTRL ALT W)

wallDIR="$HOME/Pictures/wallpapers"
SCRIPTSDIR="$HOME/.config/hypr/scripts"

focused_monitor=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')

PICS=($(find -L ${wallDIR} -type f \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" -o -name "*.pnm" -o -name "*.tga" -o -name "*.tiff" -o -name "*.webp" -o -name "*.bmp" -o -name "*.farbfeld" -o -name "*.gif" \)))
RANDOMPICS=${PICS[ $RANDOM % ${#PICS[@]} ]}


# Transition config
FPS=30
TYPE="random"
DURATION=1
BEZIER=".43,1.19,1,.4"
SWWW_PARAMS="--transition-fps $FPS --transition-type $TYPE --transition-duration $DURATION --transition-bezier $BEZIER"


if [ "${HYPRLAND_SHELL:-waybar}" != "caelestia" ]; then
    awww query || awww-daemon --format xrgb
    awww img -o $focused_monitor ${RANDOMPICS} $SWWW_PARAMS
fi

wait $!
cp -f "${RANDOMPICS}" "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current" &&
ln -sf "${RANDOMPICS}" "$HOME/.config/rofi/.current_wallpaper" &&
wallust run "${RANDOMPICS}" -s &&

wait $!
sleep 2
"$SCRIPTSDIR/Refresh.sh"

