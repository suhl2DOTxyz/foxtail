# Foxtail OS
<img width="1279" height="801" alt="image" src="https://github.com/user-attachments/assets/e2600e8e-b2cc-4cea-90bf-6c07ab22531e" />

An Arch-based OS with a macOS-style desktop: a custom Quickshell shell on Hyprland, orange throughout, with a toggleable **Liquid Glass** material.

## Build the ISO

```sh
./scripts/build-aur.sh            # once: builds WhiteSur icons + macOS cursor into build/repo (as your user)
sudo pacman -S archiso            # once
sudo ./scripts/build-iso.sh       # -> out/foxtail-1.0-<date>-x86_64.iso
```

## Layout

| Path | What |
|---|---|
| `shell/` | The desktop (Quickshell/QML): menu bar, Dock, Control Center, Spotlight, Launchpad, Notification Center, lock screen, System Settings, installer |
| `shell/shaders/liquidglass.frag` | Liquid Glass shader (rebuild `.qsb` with `/usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o X.qsb X`) |
| `hypr/` | Hyprland Lua config (floating windows, macOS keybinds, blur rules) |
| `bin/` | `foxtail-*` helpers (IPC, installer backend, screenshots, appearance sync) |
| `theme/` | GTK traffic-light CSS, fontconfig |
| `sddm-theme/`, `plymouth/` | Login screen, boot splash |
| `branding/` | Logo (`fo.svg` master → `build_logo.sh`), wallpapers |
| `archiso/` | ISO profile overlay on top of archiso's releng |

## Hacking on the shell in a running Foxtail

Copy `shell/` to `~/.config/foxtail/shell` and run `foxtail-shell`. That directory takes precedence over the system copy, and Quickshell hot-reloads it on save.
