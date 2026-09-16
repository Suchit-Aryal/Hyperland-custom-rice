#!/usr/bin/env bash
# /* ---- Readable Kitty Guard ---- */  #
# Ensures kitty's wallpaper-derived colors always have readable foreground/background
# contrast, while keeping a foreground tinted toward the wallpaper's own text hue.
# Run AFTER wallust regenerates ~/.config/kitty/kitty-themes/01-Wallust.conf
set -euo pipefail

CONF="$HOME/.config/kitty/kitty-themes/01-Wallust.conf"
[[ -f "$CONF" ]] || exit 0

NEW_FG=$(python3 - "$CONF" <<'PY'
import sys, re, colorsys

conf = sys.argv[1]
def get(key):
    m = re.search(rf'^{key}\s+(\S+)', open(conf).read(), re.M)
    return m.group(1) if m else None

bg = get('background')
fg = get('foreground')
if not bg or not fg:
    sys.exit(0)

def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def luminance(rgb):
    def f(v):
        v /= 255
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = rgb
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)

def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)

if contrast(rgb(bg), rgb(fg)) >= 4.5:
    sys.exit(0)

# Push foreground toward white or black along the same hue, preserving the mix.
r, g, b = rgb(fg)
h, s, v = colorsys.rgb_to_hsv(r/255, g/255, b/255)
if luminance(rgb(bg)) > 0.5:
    out = colorsys.hsv_to_rgb(h, min(s, 0.2), 0.12)   # dark fg on light bg
else:
    out = colorsys.hsv_to_rgb(h, min(s, 0.25), 0.94)  # light fg on dark bg
out = tuple(max(0, min(255, round(c * 255))) for c in out)
print('#{:02X}{:02X}{:02X}'.format(*out))
PY
)

if [[ -n "$NEW_FG" ]]; then
  sed -i -E "s/^foreground(\s+).*$/foreground\1$NEW_FG/" "$CONF"
fi

if pidof kitty >/dev/null; then
  for pid in $(pidof kitty); do kill -SIGUSR1 "$pid" 2>/dev/null || true; done
fi
