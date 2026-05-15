#!/bin/bash
CAVA_CONFIG="/tmp/waybar-cava.cfg"
cat > "$CAVA_CONFIG" << 'CAVAEOF'
[general]
bars = 8
[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
CAVAEOF

pkill cava 2>/dev/null
sleep 0.3

cava -p "$CAVA_CONFIG" 2>/dev/null | while IFS= read -r line; do
    echo "$line" > /tmp/cava-output
done &
