#!/bin/bash
OPEN=$(eww active-windows 2>/dev/null | grep "control_center")
if [[ -n "$OPEN" ]]; then
    eww close control_center
fi
