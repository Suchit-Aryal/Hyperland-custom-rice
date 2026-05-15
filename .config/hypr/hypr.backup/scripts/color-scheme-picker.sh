#!/bin/bash
COLORS_DIR="$HOME/.config/rice-themes/color-schemes"
SELECTED=$(ls "$COLORS_DIR" | sed 's/\.css$//' | rofi -dmenu -p "Color Scheme" -theme ~/.config/rofi/launcher.rasi)
[[ -z "$SELECTED" ]] && exit 0
ln -sf "$COLORS_DIR/$SELECTED.css" "$HOME/.config/waybar/colors.css"
pkill waybar; nohup waybar > /dev/null 2>&1 & disown
notify-send "Colors" "Scheme applied: $SELECTED"
