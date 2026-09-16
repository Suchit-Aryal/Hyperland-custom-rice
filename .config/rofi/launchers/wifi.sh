#!/bin/bash
# Rofi WiFi menu: list networks, connect, ask for password in rofi

# Trigger rescan
nmcli device wifi rescan 2>/dev/null
sleep 1

CURRENT=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2-)

TMPFILE=$(mktemp)
SSIDFILE=$(mktemp)
trap 'rm -f "$TMPFILE" "$SSIDFILE"' EXIT

# Entry line format: "ICON  SSID  SIGNAL% [SEC]"
add_entry() {
    local icon="$1" ssid="$2" signal="$3" sec="$4"
    echo "${icon}  ${ssid}  ${signal}%  [${sec}]" >> "$TMPFILE"
    echo "$ssid" >> "$SSIDFILE"
}

if [ -n "$CURRENT" ]; then
    echo "󰤨  $CURRENT  ● Connected" >> "$TMPFILE"
    echo "$CURRENT" >> "$SSIDFILE"
fi

while IFS=: read -r ssid signal sec; do
    [ -z "$ssid" ] && continue
    [ "$ssid" = "$CURRENT" ] && continue
    if [ "$signal" -ge 75 ] 2>/dev/null; then icon="󰤨"
    elif [ "$signal" -ge 50 ] 2>/dev/null; then icon="󰤥"
    elif [ "$signal" -ge 25 ] 2>/dev/null; then icon="󰤢"
    else icon="󰤟"; fi
    [ -z "$sec" ] && sec="open"
    add_entry "$icon" "$ssid" "$signal" "$sec"
done < <(nmcli -t -f ssid,signal,security dev wifi list --rescan no | sort -t: -k2 -rn | awk -F: '!seen[$1]++')

CHOSEN=$(cat "$TMPFILE" | rofi -dmenu \
    -p "  WiFi" \
    -theme ~/.config/rofi/launcher.rasi \
    -theme-str 'window {width: 480px;} listview {lines: 8;}')

[ -z "$CHOSEN" ] && exit

# Map selected line back to its exact SSID (safe for spaces in SSIDs)
SSID=""
i=0
while IFS= read -r s; do
    if [ "$(sed -n "$((i + 1))p" "$TMPFILE")" = "$CHOSEN" ]; then
        SSID="$s"
        break
    fi
    i=$((i + 1))
done < "$SSIDFILE"

[ -z "$SSID" ] && exit

if echo "$CHOSEN" | grep -q "Connected"; then
    notify-send "WiFi" "Already connected to $SSID" -i network-wireless
    exit 0
fi

notify-send "WiFi" "Connecting to $SSID..." -i network-wireless -t 2000 &

# Open networks connect directly; secured ones ask for password in rofi
if echo "$CHOSEN" | grep -q "\[open\]"; then
    if nmcli device wifi connect "$SSID" >/dev/null 2>&1; then
        notify-send "WiFi" "Connected to $SSID ✓" -i network-wireless
    else
        notify-send -u critical "WiFi" "Failed to connect to $SSID" -i network-wireless
    fi
    exit 0
fi

# Secured network: ask up to 2 times for the password
for attempt in 1 2; do
    PASS=$(rofi -dmenu -password -p "🔑 $SSID" \
        -theme ~/.config/rofi/launcher.rasi \
        -theme-str 'window {height: 140px;} listview {lines: 0;} entry {placeholder: "type password...";}')
    [ -z "$PASS" ] && exit 0   # user cancelled

    if nmcli device wifi connect "$SSID" password "$PASS" >/dev/null 2>&1; then
        notify-send "WiFi" "Connected to $SSID ✓" -i network-wireless
        exit 0
    fi
    notify-send "WiFi" "Wrong password for $SSID — try again" -i network-wireless
done

notify-send -u critical "WiFi" "Could not connect to $SSID" -i network-wireless
