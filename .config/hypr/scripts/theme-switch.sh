#!/bin/bash
THEMES_DIR="$HOME/.config/rice-themes"
THEME="$1"
THEME_PATH="$THEMES_DIR/themes/$THEME"

[[ -z "$THEME" || ! -d "$THEME_PATH" ]] && { echo "Invalid theme: $THEME"; exit 1; }

WAYBAR_STYLE=$(cat "$THEME_PATH/waybar" 2>/dev/null)
WAYBAR_CONFIG=$(cat "$THEME_PATH/waybar-config" 2>/dev/null)
WALLPAPER_NAME=$(cat "$THEME_PATH/wallpaper" 2>/dev/null)
COLORS=$(cat "$THEME_PATH/colors" 2>/dev/null)
POPUP_POS=$(cat "$THEME_PATH/popup-pos" 2>/dev/null)
ROFI_STYLE=$(cat "$THEME_PATH/rofi" 2>/dev/null)
WALLPAPER=$(find "$THEMES_DIR/wallpapers" -name "${WALLPAPER_NAME}*" | head -1)

# Apply waybar style
[[ -n "$WAYBAR_STYLE" && -f "$THEMES_DIR/waybar-styles/$WAYBAR_STYLE.css" ]] && \
    cp "$THEMES_DIR/waybar-styles/$WAYBAR_STYLE.css" "$HOME/.config/waybar/style.css"

# Apply waybar config
[[ -n "$WAYBAR_CONFIG" && -f "$THEMES_DIR/waybar-configs/$WAYBAR_CONFIG.json" ]] && \
    cp "$THEMES_DIR/waybar-configs/$WAYBAR_CONFIG.json" "$HOME/.config/waybar/config"

# Apply color scheme
[[ -n "$COLORS" && -f "$THEMES_DIR/color-schemes/$COLORS.css" ]] && \
    ln -sf "$THEMES_DIR/color-schemes/$COLORS.css" "$HOME/.config/waybar/colors.css"

# Apply rofi style
[[ -n "$ROFI_STYLE" && -f "$THEMES_DIR/rofi-styles/$ROFI_STYLE.rasi" ]] && \
    cp "$THEMES_DIR/rofi-styles/$ROFI_STYLE.rasi" "$HOME/.config/rofi/launcher.rasi"

# Apply wallpaper
[[ -f "$WALLPAPER" ]] && swww img "$WALLPAPER" --transition-type fade --transition-duration 1

# Update popup positions
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
notify-send "Theme" "Applied: $THEME"
