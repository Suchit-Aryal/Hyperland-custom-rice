#!/bin/bash
# Fallback simple wallpaper picker (SUPER W uses WallpaperSelect.sh instead)
WALLPAPERS_DIR="$HOME/Pictures/wallpapers"
SELECTED=$(find -L "$WALLPAPERS_DIR" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.bmp' \) -printf '%f\n' | sort | rofi -dmenu -p "Wallpaper" -theme ~/.config/rofi/launcher.rasi)
[[ -z "$SELECTED" ]] && exit 0
swww img "$WALLPAPERS_DIR/$SELECTED" --transition-type fade --transition-duration 1
"$HOME/.config/hypr/scripts/WallustSwww.sh" "$WALLPAPERS_DIR/$SELECTED"
