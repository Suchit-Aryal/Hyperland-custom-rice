#!/bin/bash
GRACE_FILE="/tmp/waybar-media-grace"
for PLAYER in spotify firefox.instance_1_70; do
    STATUS=$(playerctl -p "$PLAYER" status 2>/dev/null)
    if [[ "$STATUS" == "Playing" ]]; then
        rm -f "$GRACE_FILE"
        TITLE=$(playerctl -p "$PLAYER" metadata title 2>/dev/null | cut -c1-35)
        ARTIST=$(playerctl -p "$PLAYER" metadata artist 2>/dev/null | cut -c1-20)
        [[ -n "$ARTIST" ]] && TEXT="${ARTIST} — ${TITLE}" || TEXT="${TITLE}"
        echo "{\"text\": \"$TEXT\", \"class\": \"media\"}"
        exit 0
    fi
    if [[ "$STATUS" == "Paused" ]]; then
        if [[ ! -f "$GRACE_FILE" ]]; then
            date +%s > "$GRACE_FILE"
        fi
        PAUSED_AT=$(cat "$GRACE_FILE")
        NOW=$(date +%s)
        DIFF=$((NOW - PAUSED_AT))
        if [[ "$DIFF" -lt 60 ]]; then
            TITLE=$(playerctl -p "$PLAYER" metadata title 2>/dev/null | cut -c1-35)
            ARTIST=$(playerctl -p "$PLAYER" metadata artist 2>/dev/null | cut -c1-20)
            [[ -n "$ARTIST" ]] && TEXT="${ARTIST} — ${TITLE}" || TEXT="${TITLE}"
            echo "{\"text\": \"$TEXT\", \"class\": \"media\"}"
            exit 0
        fi
    fi
done
rm -f "$GRACE_FILE"
echo '{"text": "", "class": "hidden"}'
