#!/bin/bash
COLORS_DIR="$HOME/.config/rice-themes/rofi-colors"
CURRENT_LAUNCHER="$HOME/.config/rofi/launcher.rasi"

if pgrep -x "rofi" >/dev/null; then
    pkill rofi
fi

current_name=$(grep -l "$(head -5 "$CURRENT_LAUNCHER")" "$COLORS_DIR"/*.rasi 2>/dev/null | head -1)
current_name=$(basename "${current_name%.rasi}" 2>/dev/null)

mapfile -t options < <(find "$COLORS_DIR" -maxdepth 1 -name "*.rasi" -printf '%f\n' | sed 's/\.rasi$//' | sort)

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
           -p "Rofi Color" \
           -theme "$HOME/.config/rofi/launcher.rasi" \
           -mesg " Choose Rofi Color Scheme" \
           -selected-row "$default_row")

[[ -z "$SELECTED" ]] && exit 0
SELECTED="${SELECTED#"$MARKER "}"

[[ ! -f "$COLORS_DIR/$SELECTED.rasi" ]] && { notify-send "Rofi" "Color not found: $SELECTED"; exit 1; }

# Inject color into all active rofi style files
for rasi in "$HOME/.config/rofi/launcher.rasi" "$HOME/.config/rice-themes/rofi-styles/"*.rasi; do
    # Remove existing color block
    sed -i '/^\/\*\*/,/^}/{ /background:/d; /background-alt:/d; /foreground:/d; /selected:/d; /active:/d; /urgent:/d }' "$rasi" 2>/dev/null
    # Prepend new color
    cat "$COLORS_DIR/$SELECTED.rasi" "$rasi" > /tmp/_rofi_tmp.rasi && mv /tmp/_rofi_tmp.rasi "$rasi"
done

notify-send "Rofi" "Color applied: $SELECTED"
