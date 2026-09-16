#!/usr/bin/env bash
set -euo pipefail

# Hyprsunset toggle + Waybar status helper
# Usage: Hyprsunset.sh [toggle|status|init]
# Customize via env vars:
#   HYPRSUNSET_TEMP   default 4500 (K)
#   HYPRSUNSET_ICON_MODE  sunset|blue  (default: sunset)

STATE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/hyprsunset.state"
TARGET_TEMP="${HYPRSUNSET_TEMP:-4500}"
ICON_MODE="${HYPRSUNSET_ICON_MODE:-sunset}"

ensure_state() {
  [[ -f "$STATE_FILE" ]] || echo "off" > "$STATE_FILE"
}

icon_off() {
  printf "☀"
}

icon_on() {
  case "$ICON_MODE" in
    sunset) printf "🌇" ;;
    *)      printf "☀" ;;
  esac
}

is_running() {
  pgrep -x hyprsunset >/dev/null 2>&1
}

start_sunset() {
  nohup hyprsunset -t "$TARGET_TEMP" >/dev/null 2>&1 &
  disown
}

stop_sunset() {
  pkill -x hyprsunset 2>/dev/null || true
}

cmd_toggle() {
  ensure_state
  if is_running; then
    stop_sunset
    echo off > "$STATE_FILE"
    notify-send -u low "Hyprsunset: Disabled" || true
  else
    start_sunset
    echo on > "$STATE_FILE"
    notify-send -u low "Hyprsunset: Enabled" "${TARGET_TEMP}K" || true
  fi
}

cmd_status() {
  ensure_state
  # Prefer live process detection; fall back to state file
  if is_running; then
    onoff="on"
  else
    onoff="$(cat "$STATE_FILE" || echo off)"
    [[ "$onoff" == "on" ]] && { echo off > "$STATE_FILE"; onoff="off"; }
  fi

  if [[ "$onoff" == "on" ]]; then
    txt="<span size='18pt'>$(icon_on)</span>"
    cls="on"
    tip="Night light on @ ${TARGET_TEMP}K"
  else
    txt="<span size='16pt'>$(icon_off)</span>"
    cls="off"
    tip="Night light off"
  fi
  printf '{"text":"%s","class":"%s","tooltip":"%s"}\n' "$txt" "$cls" "$tip"
}

cmd_init() {
  ensure_state
  state="$(cat "$STATE_FILE" || echo off)"
  if [[ "$state" == "on" ]]; then
    start_sunset
  fi
}

case "${1:-}" in
  toggle) cmd_toggle ;;
  status) cmd_status ;;
  init)   cmd_init ;;
  *) echo "usage: $0 [toggle|status|init]" >&2; exit 2 ;;
esac
