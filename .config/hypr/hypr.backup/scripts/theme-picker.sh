#!/bin/bash
THEMES_DIR="$HOME/.config/rice-themes/themes"
THEME=$(ls "$THEMES_DIR" | rofi -dmenu -p "Theme" -theme ~/.config/rofi/launcher.rasi)
[[ -z "$THEME" ]] && exit 0
~/.config/hypr/scripts/theme-switch.sh "$THEME"
