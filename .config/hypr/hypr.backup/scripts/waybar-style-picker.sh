#!/bin/bash
STYLES_DIR="$HOME/.config/rice-themes/waybar-styles"
CONFIGS_DIR="$HOME/.config/rice-themes/waybar-configs"
THEMES_DIR="$HOME/.config/rice-themes/themes"

SELECTED=$(ls "$STYLES_DIR" | sed 's/\.css$//' | rofi -dmenu -p "Waybar Style" -theme ~/.config/rofi/launcher.rasi)
[[ -z "$SELECTED" ]] && exit 0

cp "$STYLES_DIR/$SELECTED.css" "$HOME/.config/waybar/style.css"
[[ -f "$CONFIGS_DIR/$SELECTED.json" ]] && cp "$CONFIGS_DIR/$SELECTED.json" "$HOME/.config/waybar/config"

# Find theme whose waybar-config matches selected style
POPUP_POS=""
for theme_dir in "$THEMES_DIR"/*/; do
    waybar_config=$(cat "$theme_dir/waybar-config" 2>/dev/null)
    if [[ "$waybar_config" == "$SELECTED" ]]; then
        POPUP_POS=$(cat "$theme_dir/popup-pos" 2>/dev/null)
        break
    fi
done

if [[ -n "$POPUP_POS" ]]; then
    SOUND_POS=$(echo "$POPUP_POS" | cut -d',' -f1)
    WIFI_POS=$(echo "$POPUP_POS" | cut -d',' -f2)
    python3 - << PYEOF
content = open('$HOME/.config/hypr/UserConfigs/WindowRules.conf').read()
lines = content.split('\n')
out = []
for line in lines:
    if 'soundpopup' in line and 'move' in line:
        out.append('windowrule = match:class ^(com.hypr.soundpopup)\$, move $SOUND_POS')
    elif 'wifipopup' in line and 'move' in line:
        out.append('windowrule = match:class ^(com.hypr.wifipopup)\$, move $WIFI_POS')
    else:
        out.append(line)
open('$HOME/.config/hypr/UserConfigs/WindowRules.conf', 'w').write('\n'.join(out))
PYEOF
fi

pkill waybar; nohup waybar > /dev/null 2>&1 & disown
hyprctl reload
notify-send "Waybar" "Style applied: $SELECTED"
