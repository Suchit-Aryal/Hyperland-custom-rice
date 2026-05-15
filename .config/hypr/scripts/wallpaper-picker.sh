#!/bin/bash
WALLPAPERS_DIR="$HOME/.config/rice-themes/wallpapers"
SELECTED=$(ls "$WALLPAPERS_DIR" | rofi -dmenu -p "Wallpaper" -theme ~/.config/rofi/launcher.rasi)
[[ -z "$SELECTED" ]] && exit 0
swww img "$WALLPAPERS_DIR/$SELECTED" --transition-type fade --transition-duration 1
