#!/bin/bash
current=$(powerprofilesctl get)
if [ "$current" = "power-saver" ]; then
    powerprofilesctl set balanced
    notify-send "Power Mode" "Balanced" -i battery
elif [ "$current" = "balanced" ]; then
    powerprofilesctl set performance
    notify-send "Power Mode" "Performance 🚀" -i battery
else
    powerprofilesctl set power-saver
    notify-send "Power Mode" "Power Saver 🍃" -i battery
fi
