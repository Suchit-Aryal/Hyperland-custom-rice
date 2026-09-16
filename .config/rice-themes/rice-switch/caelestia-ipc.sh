#!/bin/bash
# caelestia-ipc.sh — forward an IPC call to the running Caelestia shell.
# The stock `caelestia-shell ipc` CLI looks for the nix-store install's socket,
# but we run a fixed local fork, so resolve the live process and talk to it by PID.
# Usage: caelestia-ipc.sh call <target> <function> [args...]
PID=$(pgrep -f "quickshell -p .*caelestia-shell" | head -n 1)
[ -z "$PID" ] && exit 1
QS=$(readlink -f "/proc/$PID/exe")
exec "$QS" ipc --pid "$PID" "$@"
