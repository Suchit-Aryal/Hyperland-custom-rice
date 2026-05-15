#!/bin/bash
CAPACITY=$(cat /sys/class/power_supply/BAT0/capacity 2>/dev/null || cat /sys/class/power_supply/BAT1/capacity 2>/dev/null)
STATUS=$(cat /sys/class/power_supply/BAT0/status 2>/dev/null || cat /sys/class/power_supply/BAT1/status 2>/dev/null)

if [[ "$STATUS" == "Charging" ]]; then
    FRAME=$(( ($(date +%s) % 6 ) ))
    CLASS="c$FRAME"
elif [[ "$STATUS" == "Full" ]]; then
    CLASS="full"
else
    if [[ $CAPACITY -le 15 ]]; then CLASS="critical"
    elif [[ $CAPACITY -le 30 ]]; then CLASS="warning"
    elif [[ $CAPACITY -le 60 ]]; then CLASS="good"
    else CLASS="full"; fi
fi

echo "{\"text\": \"$CAPACITY%\", \"class\": \"$CLASS\", \"tooltip\": \"$STATUS — $CAPACITY%\"}"
