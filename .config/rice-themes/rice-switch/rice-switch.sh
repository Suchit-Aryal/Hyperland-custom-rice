#!/bin/bash
# rice-switch.sh — cycle between kool rice (waybar+swaync), end4-pC (quickshell)
# and caelestia-shell (quickshell), via SUPER+SHIFT+T
# usage: rice-switch.sh [cycle|toggle|autostart|kool|end4|caelestia|status]

MODE_FILE="$HOME/.cache/rice-mode"
SWITCH_DIR="$HOME/.config/rice-themes/rice-switch"
QS="$HOME/.nix-profile/bin/qs"
CAEL="$HOME/.nix-profile/bin/caelestia-shell"
CAELPK="quickshell -p .*[c]aelestia-shell"
RICE_ORDER=(kool end4 caelestia)

get_mode() {
    [ -f "$MODE_FILE" ] && cat "$MODE_FILE" || echo "kool"
}

set_binds() {
    # Never point mode-binds.conf at a missing or empty binds file:
    # an empty source= + reload previously crashed Hyprland.
    if [ ! -s "$SWITCH_DIR/binds-$1.conf" ]; then
        echo "set_binds: binds-$1.conf missing or empty; keeping current binds" >&2
        return 1
    fi
    ln -sfn "$SWITCH_DIR/binds-$1.conf" "$SWITCH_DIR/mode-binds.conf"
}

# swaync runs as a systemd user unit with Restart=on-failure, so a plain
# pkill makes systemd instantly relaunch it and it claws back the
# org.freedesktop.Notifications bus from the quickshell rices. A clean
# systemctl stop marks it stopped and stays stopped; only kool mode starts it.
start_swaync() {
    systemctl --user start swaync.service 2>/dev/null || { nohup swaync >/dev/null 2>&1 & disown; }
}

stop_swaync() {
    systemctl --user stop swaync.service 2>/dev/null
    pkill -x swaync 2>/dev/null
}

kill_caelestia() {
    pkill -f "$CAELPK" 2>/dev/null
}

reload() {
    hyprctl reload >/dev/null 2>&1
}

ensure_swww() {
    # Reliably bring up swww-daemon and wait until it can serve requests.
    # swww-daemon binds its socket asynchronously; if we swww img too early it
    # silently fails and the wallpaper never applies.
    if ! pgrep -x swww-daemon >/dev/null 2>&1; then
        setsid -f swww-daemon --format xrgb </dev/null >/dev/null 2>&1
    fi
    local tries=0
    while ! swww query >/dev/null 2>&1 && [ "$tries" -lt 20 ]; do
        sleep 0.5
        tries=$((tries + 1))
        pgrep -x swww-daemon >/dev/null 2>&1 || { setsid -f swww-daemon --format xrgb </dev/null >/dev/null 2>&1; }
    done
    [ "$tries" -ge 20 ] && return 1 || return 0
}

start_kool() {
    kill_caelestia
    pkill -f "quickshell -c end4-p[C]" 2>/dev/null
    pkill -f -9 mpvpaper 2>/dev/null
    ensure_swww
    swww img "$HOME/.config/hypr/wallpaper_effects/.wallpaper_current" >/dev/null 2>&1
    sleep 0.3
    pgrep -x waybar >/dev/null || { nohup waybar >/dev/null 2>&1 & disown; }
    start_swaync
    echo "kool" > "$MODE_FILE"
    set_binds kool
    reload
    notify-send "Rice" "kool rice active (waybar + swaync)" -i preferences-desktop 2>/dev/null
}

start_end4() {
    kill_caelestia
    pkill -x waybar 2>/dev/null
    stop_swaync
    pkill -x swww-daemon 2>/dev/null
    pkill -f "quickshell -c end4-p[C]" 2>/dev/null
    echo "end4" > "$MODE_FILE"
    set_binds end4
    reload
    QT_PLUGIN_PATH="/nix/store/biwxpr2y1ba5bdk394hprcb7zi1ngzpp-qtsvg-6.11.1/lib/qt-6/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}" \
    QML2_IMPORT_PATH="$HOME/.nix-profile/lib/qt-6/qml" \
    QT_QPA_PLATFORMTHEME="xdgdesktopportal" setsid -f "$HOME/.nix-profile/bin/nixGLIntel" "$QS" -c end4-pC </dev/null >/dev/null 2>&1
    sleep 3
    if ! pgrep -f "quickshell -c end4-p[C]" >/dev/null; then
        notify-send -u critical "Rice switch" "quickshell failed to start — reverting to kool rice" 2>/dev/null
        start_kool
        return 1
    fi
}

start_caelestia() {
    pkill -x waybar 2>/dev/null
    stop_swaync
    pkill -x swww-daemon 2>/dev/null
    pkill -f "quickshell -c end4-p[C]" 2>/dev/null
    kill_caelestia
    echo "caelestia" > "$MODE_FILE"
    # die if caelestia-shell isn't installed, so we never strand the user
    if [ ! -x "$HOME/.nix-profile/bin/caelestia-shell" ]; then
        notify-send -u critical "Rice switch" "caelestia-shell not installed — staying on kool rice" 2>/dev/null
        echo "kool" > "$MODE_FILE"
        start_kool
        return 1
    fi
    set_binds caelestia
    reload
    # Fixed-PAM fork: the stock nix store ships assets/pam.d/passwd requiring
    # pam_faillock, but this system has no /run/faillock tally dir, so EVERY
    # unlock attempt ends as PAM Error ("PW ERROR") even with the right password.
    # ~/.config/quickshell/caelestia-shell is a copy with faillock dropped
    # (pam_unix only, matching system common-auth). Env below replicates what
    # the caelestia-shell nix wrapper sets (QML plugins), verified working.
    QT_PLUGIN_PATH="/nix/store/biwxpr2y1ba5bdk394hprcb7zi1ngzpp-qtsvg-6.11.1/lib/qt-6/plugins:/nix/store/sx8m75cg5pr3cywr9mqay2al9b78bq89-qtbase-6.11.2-only-plugins-qml/lib/qt-6/plugins:/nix/store/avdsaqd2dw3pnc3j87q7qjli1d6ns0xp-qtbase-6.11.2/lib/qt-6/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}" \
    NIXPKGS_QT6_QML_IMPORT_PATH="/nix/store/39ymvd2hirgx01f62i6f5479w3iyxc9q-quickshell-wrapped-0.3.1/lib/qt-6/qml:/nix/store/m5wyvgs566w34lq43b268jkf983p1m04-caelestia-qml-plugin/lib/qt-6/qml${NIXPKGS_QT6_QML_IMPORT_PATH:+:$NIXPKGS_QT6_QML_IMPORT_PATH}" \
    XDG_DATA_DIRS="/nix/store/ycpqxwri865g37jqj8pyyhcy1zqj9kpq-caelestia-shell-1.0.0/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}" \
    QT_QPA_PLATFORMTHEME="xdgdesktopportal" setsid -f "$HOME/.nix-profile/bin/nixGLIntel" /nix/store/39ymvd2hirgx01f62i6f5479w3iyxc9q-quickshell-wrapped-0.3.1/bin/quickshell -p "$HOME/.config/quickshell/caelestia-shell" -n -d </dev/null >/dev/null 2>&1
    sleep 4
    if ! pgrep -f "$CAELPK" >/dev/null; then
        notify-send -u critical "Rice switch" "caelestia-shell failed to start — reverting to kool rice" 2>/dev/null
        start_kool
        return 1
    fi
}

case "${1:-toggle}" in
    toggle|cycle)
        current="$(get_mode)"
        next=""
        for i in "${!RICE_ORDER[@]}"; do
            if [ "${RICE_ORDER[$i]}" = "$current" ]; then
                next="${RICE_ORDER[$(( (i + 1) % ${#RICE_ORDER[@]} ))]}"
                break
            fi
        done
        [ -z "$next" ] && next="kool"
        "start_$next"
        ;;
    kool) start_kool ;;
    end4) start_end4 ;;
    caelestia) start_caelestia ;;
    autostart)
        case "$(get_mode)" in
            kool)
                start_swaync
                pgrep -x waybar >/dev/null || { nohup waybar >/dev/null 2>&1 & disown; }
                ;;
            end4)
                # waybar/swaync were started by default exec-once; replace them
                sleep 1
                pkill -x waybar 2>/dev/null
                stop_swaync
                QT_PLUGIN_PATH="/nix/store/biwxpr2y1ba5bdk394hprcb7zi1ngzpp-qtsvg-6.11.1/lib/qt-6/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}" \
                QML2_IMPORT_PATH="$HOME/.nix-profile/lib/qt-6/qml" \
                QT_QPA_PLATFORMTHEME="xdgdesktopportal" setsid -f "$HOME/.nix-profile/bin/nixGLIntel" "$QS" -c end4-pC </dev/null >/dev/null 2>&1
                ;;
            caelestia)
                # waybar/swaync were started by default exec-once; replace them
                sleep 1
                pkill -x waybar 2>/dev/null
                stop_swaync
                pkill -x swww-daemon 2>/dev/null
                # Same fixed-PAM fork as start_caelestia (see comment there)
                QT_PLUGIN_PATH="/nix/store/biwxpr2y1ba5bdk394hprcb7zi1ngzpp-qtsvg-6.11.1/lib/qt-6/plugins:/nix/store/sx8m75cg5pr3cywr9mqay2al9b78bq89-qtbase-6.11.2-only-plugins-qml/lib/qt-6/plugins:/nix/store/avdsaqd2dw3pnc3j87q7qjli1d6ns0xp-qtbase-6.11.2/lib/qt-6/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}" \
                NIXPKGS_QT6_QML_IMPORT_PATH="/nix/store/39ymvd2hirgx01f62i6f5479w3iyxc9q-quickshell-wrapped-0.3.1/lib/qt-6/qml:/nix/store/m5wyvgs566w34lq43b268jkf983p1m04-caelestia-qml-plugin/lib/qt-6/qml${NIXPKGS_QT6_QML_IMPORT_PATH:+:$NIXPKGS_QT6_QML_IMPORT_PATH}" \
                XDG_DATA_DIRS="/nix/store/ycpqxwri865g37jqj8pyyhcy1zqj9kpq-caelestia-shell-1.0.0/share${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}" \
                QT_QPA_PLATFORMTHEME="xdgdesktopportal" setsid -f "$HOME/.nix-profile/bin/nixGLIntel" /nix/store/39ymvd2hirgx01f62i6f5479w3iyxc9q-quickshell-wrapped-0.3.1/bin/quickshell -p "$HOME/.config/quickshell/caelestia-shell" -n -d </dev/null >/dev/null 2>&1
                ;;
        esac
        ;;
    status) echo "$(get_mode)" ;;
    *) echo "usage: rice-switch.sh [toggle|autostart|kool|end4|caelestia|status]"; exit 1 ;;
esac
