#!/bin/sh

xrdb merge ~/.Xresources
xbacklight -set 10 &
feh --bg-fill /home/khoahoc/wallpaper/birdandcat.jpg &
xset r rate 200 50 &
picom &
fcitx5 &
vesktop &


dash ~/.config/chadwm/scripts/bar.sh &
while type chadwm >/dev/null; do chadwm && continue || break; done
