#!/bin/bash
WALLPAPERS_DIR="$HOME/.config/rice-themes/wallpapers"
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
        WALLPAPER=$(ls "$WALLPAPERS_DIR" | shuf -n1)
        swww img "$WALLPAPERS_DIR/$WALLPAPER" --transition-type fade --transition-duration 1
        sleep 360
    done
) &
disown
notify-send "Wallpaper Slideshow" "Started (6 min interval)"
