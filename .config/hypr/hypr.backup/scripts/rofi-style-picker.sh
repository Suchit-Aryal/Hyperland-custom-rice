#!/bin/bash
STYLES_DIR="$HOME/.config/rice-themes/rofi-styles"
CURRENT="$HOME/.config/rofi/launcher.rasi"

# Kill rofi if already running
if pgrep -x "rofi" >/dev/null; then
    pkill rofi
fi

# Build list, mark current
current_name=$(basename "$(readlink -f "$CURRENT")" .rasi 2>/dev/null || basename "$CURRENT" .rasi)
mapfile -t options < <(find "$STYLES_DIR" -maxdepth 1 -name "*.rasi" -printf '%f\n' | sed 's/\.rasi$//' | sort)

MARKER="👉"
default_row=0
for i in "${!options[@]}"; do
    if [[ "${options[i]}" == "$current_name" ]]; then
        options[i]="$MARKER ${options[i]}"
        default_row=$i
        break
    fi
done

SELECTED=$(printf '%s\n' "${options[@]}" \
    | rofi -dmenu \
           -p "Rofi Style" \
           -theme "$HOME/.config/rofi/launcher.rasi" \
           -mesg " Choose Rofi Style" \
           -selected-row "$default_row")

[[ -z "$SELECTED" ]] && exit 0

# Strip marker
SELECTED="${SELECTED#"$MARKER "}"

[[ ! -f "$STYLES_DIR/$SELECTED.rasi" ]] && { notify-send "Rofi" "Style not found: $SELECTED"; exit 1; }

cp "$STYLES_DIR/$SELECTED.rasi" "$HOME/.config/rofi/launcher.rasi"
notify-send "Rofi" "Style applied: $SELECTED"
