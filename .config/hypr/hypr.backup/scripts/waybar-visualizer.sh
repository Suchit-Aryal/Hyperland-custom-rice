#!/bin/bash
BARS=("▁" "▂" "▃" "▄" "▅" "▆" "▇" "█")

STATUS=$(playerctl status 2>/dev/null)
if [[ "$STATUS" != "Playing" ]]; then
    echo "▁▁▁▁▁▁▁▁"
    exit 0
fi

[[ ! -f /tmp/cava-output ]] && { echo "▁▁▁▁▁▁▁▁"; exit 0; }

line=$(tail -5 /tmp/cava-output 2>/dev/null | grep -v "^0;0;0;0;0;0;0;0" | tail -1)
[[ -z "$line" ]] && line=$(tail -1 /tmp/cava-output)

OUT=""
IFS=';' read -ra VALS <<< "$line"
for val in "${VALS[@]}"; do
    val="${val//[^0-9]/}"
    [[ -z "$val" ]] && val=0
    [[ "$val" -gt 7 ]] && val=7
    OUT+="${BARS[$val]}"
done
[[ -z "$OUT" ]] && OUT="▁▁▁▁▁▁▁▁"
echo "$OUT"
