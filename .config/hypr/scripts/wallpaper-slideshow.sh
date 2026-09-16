#!/bin/bash
WALLPAPERS_DIR="$HOME/Pictures/wallpapers"
PIDFILE="/tmp/wallpaper-slideshow.pid"

if [[ -f "$PIDFILE" ]] && kill -0 $(cat "$PIDFILE") 2>/dev/null; then
    kill $(cat "$PIDFILE")
    rm "$PIDFILE"
    notify-send "Wallpaper Slideshow" "Stopped"
    exit 0
fi

(
    echo $$ > "$PIDFILE"
    while true; do
        WALLPAPER=$(find -L "$WALLPAPERS_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' \) -printf '%f\n' | shuf -n1)
        [[ -z "$WALLPAPER" ]] && sleep 360 && continue
        swww img "$WALLPAPERS_DIR/$WALLPAPER" --transition-type fade --transition-duration 1
        sleep 360
    done
) &
disown
notify-send "Wallpaper Slideshow" "Started (6 min interval)"
