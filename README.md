# Hyperland Custom Rice

A portable dotfiles / rice backup that mirrors **your live system** — the current
Hyprland rice (end4-pC "kool" + caelestia-shell + Caelestia), the `rice-switch`
theme cycler that powers SUPER+SHIFT+T, and the full wallpaper collection
(incl. the end4 "Dynamic-Wallpapers" auto-switching set).

This repo is additive: it tracks `.config/` (rice-relevant dirs) and
`wallpapers/` and follows a single portability rule — **it never contains a raw
`/home/<you>` path**. Yours gets rendered at install time by the wrapper
scripts. (See "How installs work" below.)

---

## What's inside

```
Hyperland-custom-rice/
├── .config/
│   ├── hypr/                  → Hyprland compositor config (binds, rules,
│   │                            startup, animations, workspace rules)
│   ├── rice-themes/
│   │   ├── rice-switch/       → SUPER+SHIFT+T rice cycler + per-rice keybinds
│   │   ├── color-schemes/     → Kvantum (catppuccin latte/mocha, dracula,
│   │   │                        gruvbox, nord, tokyo-night, everforest,
│   │   │                        rose-pine, green-lime, red-wine, yellow…) 
│   │   ├── rice-switch/
│   │   │     binds-kool.conf  binds-end4.conf  binds-kool.conf (cycle=true)
│   │   │     mode-binds.conf  rice-switch.sh   kool + caelestia-ipc.sh
│   │   └── waybar-configs + waybar-styles/    → per-theme waybar themes
│   ├── quickshell/
│   │   ├── end4-pC/           → end4 "pC" quickshell rice (launcher,
│   │   │                        wallpaper drawer, notification center,
│   │   │                        ends4 shell: quickshell-shell + end4-pC)
│   │   └── caelestia-shell/   → the Caelestia shell (lighter quickshell rice)
│   ├── waybar/                → waybar config + styles (kool rice bar)
│   ├── wallust/               → wallpaper-driven color generator config
│   ├── swaync/  rofi/  wallust/  wlogout/  ags/  cava/  btop/  neofetch/
│   └── kitty/  ghostty/  wezterm/  gtk-3.0/  Kvantum/  qt5ct/  qt6ct/
│       nwg-look/  swappy/  fastfetch/
└── wallpapers/
    ├── Dynamic-Wallpapers/
    │   ├── Light/             → light wallpapers auto-selected at runtime
    │   └── Dark/              → dark wallpapers auto-selected at runtime
    └── (static + live GIF wallpapers — full collection)
```

## The rices (SUPER+SHIFT+T to cycle)

The whole point of this repo: you don't pick a rice, you **cycle** them live.

| Mode       | Shell                          | Bar / Notifications            |
|------------|--------------------------------|--------------------------------|
| `kool`     | — (plain Hyprland)             | waybar + swaync                |
| `end4`     | quickshell `end4-pC`          | quickshell bar + swaync        |
| `caelestia`| quickshell `caelestia-shell`  | caelestia shell + swaync       |

The active mode is stored in `~/.cache/rice-mode`. The cycler
(`.config/rice-themes/rice-switch/rice-switch.sh`) atomically:

1. swaps `mode-binds.conf` → the matching `binds-<mode>.conf`,
2. starts / stops the correct quickshell surface + bar,
3. keeps `swaync` as a **systemd user unit** so notifications never get
   killed-and-restarted (that would steal the `org.freedesktop.Notifications`
   bus from the quickshell rice).

Use `rice-switch.sh toggle` (mapped to **SUPER+SHIFT+T**) to rotate
`kool → end4 → caelestia → kool …`.

### Wallpaper / launcher binds per rice (SUPER+W)

`binds-*.conf` remaps the wallpaper-modifier per shell:

- **kool**: SUPER+W opens the wallpaper selector (QS `wallpaperSelector`) —
  wallust-driven, picks a group from `wallust pics` and regenerates the palette.
- **end4**: SUPER+W toggles the `end4-pC` wallpaper drawer
  (`qs -c end4-pC ipc call wallpaperSelector toggle`).
- **caelestia**: SUPER+W toggles the Caelestia **launcher in wallpaper mode**
  (`qs -c caelestia-shell …`), because in Caelestia the wallpaper picker lives
  in the launcher.

All other window/workspace binds stay in `Keybinds.conf` (shared across rices)
so muscle memory carries over when you cycle.

## Dynamic-Wallpapers (auto light/dark)

`wallpapers/Dynamic-Wallpapers/{Light,Dark}/` holds two curated sets. The
quickshell IPC + wallust pick one set based on the session color mode — enable
through `qs` IPC (`wallust` sets `mode` → quickshell swaps the live wallpaper).
Point wallust at a `Dynamic-Wallpapers` group and the rice flips dark/light
wallpapers (and regenerates the whole color-scheme) with the wallpaper.

## Wallpapers

The full collection mirrors `~/Pictures/wallpapers`:

- `Dynamic-Wallpapers/{Light,Dark}` — the auto-switching pair.
- static `.png/.jpg` + a few live `.gif` wallpapers (incl. the 1979 Pontiac
  Firebird live GIF).
- **Size policy**: GitHub hard-rejects files >100 MB. The one oversized file in
  this collection (`~194 MB live GIF`) is intentionally **not** committed — it
  stays in `~/Pictures/wallpapers` only)Skip and the repo carries everything
  else. Do not `git add` >100 MB files or the push will fail.

## Requirements

Recent **Arch-based** system with:

- `hyprland` (Wayland compositor)
- `quickshell` (or the vendored `end4-pC` / `caelestia-shell` rice — expects a
  nix-built `qs` on `$PATH`, e.g. via Home Manager / `nix profile`)
- `wallust` (wallpaper → palette generator)
- `waybar`, `swaync` (+ systemd user unit for swaync)
- `rofi`, `wlogout`, `swappy`, `rofi`
- a terminal: `kitty`, `ghostty`, or `wezterm`
- Qt theming: `Kvantum`, `qt5ct` / `qt6ct`, `nwg-look`
- `ags` (optional), `cava`, `btop`, `neofetch` / `fastfetch`

## Install

```bash
# 1. clone
git clone https://github.com/Suchit-Aryal/Hyperland-custom-rice.git ~/rice

# 2. mirror the rice configs into place
cp -rTa ~/rice/.config ~/.config

# 3. make the rice cycler executable
chmod +x ~/.config/rice-themes/rice-switch/rice-switch.sh \
          ~/.config/rice-themes/rice-switch/*.sh

# 4. link wallpapers (the Dynamic + static set)
mkdir -p ~/Pictures/wallpapers
cp ~/rice/wallpapers/* ~/Pictures/wallpapers/   # omit any >100 MB .gif

# 5. start the compositor's autostart (Hyprland exec => rice-switch.sh autostart)
#    or add to hyprland.conf:
#        exec-once = ~/.config/rice-themes/rice-switch/rice-switch.sh autostart

# 6. source env: nix store paths are referenced via __HOME__ / wrappers —
#    run the rice-switch autostart once to set the right shell path.
```

New installs later: re-clone, re-mirror, re-run step 3 — the repo is pitched as
a **current-state mirror**, so your config follows your system.

## Customising / syncing back

- Edit configs in `~/.config/…`, then re-backup:
  ```bash
  cd ~/rice
  rsync -a ~/.config/hypr ~/.config/waybar ~/.config/rice-themes \
        ~/.config/quickshell ~/.config/wallust .config/
  git add -A && git commit -m "sync: update rice" && git push
  ```
- The wallpaper set is recovered the same way from `~/Pictures/wallpapers`.
- Never commit files >100 MB (GitHub limit → push will be rejected).

## Notes & conventions

- **Portability**: configs treat your home as `__HOME__`-style; meal-check that
  no `/home/<you>` literal is committed. Wrappers under
  `rice-themes/rice-switch/*.sh` resolve `~/.nix-profile/bin/qs` at runtime, so
  switching machines doesn't leak store paths.
- **`rice-themes/wallpapers`** is intentionally kept as a **git symlink** to
  `~/Pictures/wallpapers` — do not `rsync -L --delete` it, that dereferences
  500+ MB of GIFs into the tree.
- **swaync** runs as a systemd user service so the rice cycler can stop it
  cleanly (`systemctl --user stop swaync`) instead of killing a bus owner.
- **Rice-switch key**: `SUPER+SHIFT+T` cycles; `SUPER+W` opens/ toggles the
  per-rice wallpaper + launcher. Everything else is in `Keybinds.conf`.
