#!/bin/sh

xrdb merge ~/.Xresources
xbacklight -set 10 &
feh --bg-fill /home/khoahoc/Pictures/images/personal-image.jpg &
xset r rate 200 50 &
greenclip daemon &
picom &
fcitx5 &
vesktop &


dash ~/.config/chadwm/scripts/bar.sh &
while type chadwm >/dev/null; do chadwm && continue || break; done
