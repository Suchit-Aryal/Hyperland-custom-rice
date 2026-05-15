#!/bin/bash
WIFI=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep "^yes" | cut -d: -f2)
[[ -z "$WIFI" ]] && ICON="󰤭" || ICON="󰤨 $WIFI"
echo "{\"text\": \"$ICON\", \"class\": \"net\"}"
