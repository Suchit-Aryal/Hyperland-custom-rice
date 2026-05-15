#!/bin/bash
if pgrep -f wifi-popup.py > /dev/null; then
    pkill -f wifi-popup.py
else
    GI_TYPELIB_PATH=/usr/lib/x86_64-linux-gnu/girepository-1.0 \
    nohup /usr/bin/python3 $HOME/.config/hypr/scripts/wifi-popup.py > /dev/null 2>&1 &
    disown
fi
