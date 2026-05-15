#!/bin/bash
WIFI=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep "^yes" | cut -d: -f2)
[[ -z "$WIFI" ]] && WIFI_ICON="󰤭" || WIFI_ICON="󰤨"

BT=$(bluetoothctl show 2>/dev/null | grep "Powered: yes")
[[ -n "$BT" ]] && BT_ICON="󰂯" || BT_ICON="󰂲"

echo "{\"text\": \"$WIFI_ICON  $BT_ICON\", \"class\": \"netbt\"}"
