#!/bin/bash
if pgrep -f bluetooth-popup.py > /dev/null; then
    pkill -f bluetooth-popup.py
else
    nohup /usr/bin/python3 $HOME/.config/hypr/scripts/bluetooth-popup.py > /dev/null 2>&1 &
    disown
fi
