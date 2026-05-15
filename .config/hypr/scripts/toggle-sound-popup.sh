#!/bin/bash
# toggle-sound-popup.sh
if pgrep -f sound-popup.py > /dev/null; then
    pkill -f sound-popup.py
else
    GI_TYPELIB_PATH=/usr/lib/x86_64-linux-gnu/girepository-1.0 \
    nohup /usr/bin/python3 $HOME/.config/hypr/scripts/sound-popup.py > /dev/null 2>&1 &
    disown
fi
