#!/bin/bash

# Trigger rescan
nmcli device wifi rescan 2>/dev/null
sleep 1

CURRENT=$(nmcli -t -f active,ssid dev wifi | grep '^yes' | cut -d: -f2)

TMPFILE=$(mktemp)

if [ -n "$CURRENT" ]; then
    echo "󰤨  $CURRENT  ● Connected" >> "$TMPFILE"
fi

nmcli -t -f ssid,signal,security dev wifi list --rescan no | sort -t: -k2 -rn | awk -F: '!seen[$1]++ && $1!=""' | while IFS=: read -r ssid signal sec; do
    [ "$ssid" = "$CURRENT" ] && continue
    if [ "$signal" -ge 75 ] 2>/dev/null; then icon="󰤨"
    elif [ "$signal" -ge 50 ] 2>/dev/null; then icon="󰤥"
    elif [ "$signal" -ge 25 ] 2>/dev/null; then icon="󰤢"
    else icon="󰤟"; fi
    [ -z "$sec" ] && sec="open"
    echo "${icon}  ${ssid}  ${signal}%  [${sec}]" >> "$TMPFILE"
done

CHOSEN=$(cat "$TMPFILE" | rofi -dmenu \
    -p "  WiFi" \
    -theme ~/.config/rofi/launcher.rasi \
    -theme-str 'window {width: 480px;} listview {lines: 8;}')

rm "$TMPFILE"
[ -z "$CHOSEN" ] && exit

SSID=$(echo "$CHOSEN" | awk '{print $2}')

if echo "$CHOSEN" | grep -q "Connected"; then
    notify-send "WiFi" "Already connected to $SSID" -i network-wireless
else
    notify-send "WiFi" "Connecting to $SSID..." -i network-wireless
    if nmcli device wifi connect "$SSID" 2>/dev/null; then
        notify-send "WiFi" "Connected to $SSID ✓" -i network-wireless
    else
        notify-send "WiFi" "Need password — opening manager" -i network-wireless
        nm-connection-editor &
    fi
fi
