#!/usr/bin/env bash
# Build the Foxtail ISO.
#
#   sudo ./scripts/build-iso.sh            -> out/foxtail-<version>-x86_64.iso
#
# Assembles an archiso profile in build/profile from archiso's releng
# profile + archiso/ (Foxtail overlay) + the shell, theme and branding
# sources in this repo, then runs mkarchiso. Needs: archiso, ~10 GB free.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
BUILD="$ROOT/build"
PROFILE="$BUILD/profile"
WORK="$BUILD/work"
OUT="$ROOT/out"
RELENG=/usr/share/archiso/configs/releng

[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }
command -v mkarchiso >/dev/null || { echo "install archiso first: pacman -S archiso" >&2; exit 1; }

# ---- local repo with AUR packages (built as the invoking user) ----
if [ ! -f "$BUILD/repo/foxtail-local.db.tar.gz" ]; then
    sudo -u "${SUDO_USER:?run via sudo from your user account}" "$ROOT/scripts/build-aur.sh"
fi

echo ":: assembling profile"
rm -rf "$PROFILE"
mkdir -p "$PROFILE"
cp -a "$RELENG/." "$PROFILE/"
A="$PROFILE/airootfs"

# Drop releng's rescue-disk bits we don't want (root autologin, speech,
# sshd, systemd-networkd/iwd - Foxtail uses NetworkManager).
rm -rf \
    "$A/etc/systemd/system/getty@tty1.service.d" \
    "$A/etc/systemd/system/livecd-talk.service" \
    "$A/etc/systemd/system/livecd-alsa-unmuter.service" \
    "$A/etc/systemd/system/sound.target.wants" \
    "$A/etc/systemd/system/cloud-init.target.wants" \
    "$A/etc/systemd/system/sockets.target.wants" \
    "$A/etc/systemd/system/network-online.target.wants" \
    "$A/etc/systemd/system/systemd-networkd-wait-online.service.d" \
    "$A/etc/systemd/system/dbus-org.freedesktop.ModemManager1.service" \
    "$A/etc/systemd/system/dbus-org.freedesktop.network1.service" \
    "$A/etc/systemd/system/dbus-org.freedesktop.resolve1.service" \
    "$A/etc/systemd/network" \
    "$A/etc/systemd/networkd.conf.d" \
    "$A/etc/systemd/resolved.conf.d" \
    "$A/etc/resolv.conf" \
    "$A/etc/motd" \
    "$A/etc/ssh" \
    "$A/root/.automated_script.sh" \
    "$A/root/.zlogin" \
    "$A/usr/local/bin/Installation_guide" \
    "$A/usr/local/bin/livecd-sound" \
    "$A/usr/local/share/livecd-sound" \
    "$PROFILE/efiboot/loader/entries/01-archiso-linux.conf" \
    "$PROFILE/efiboot/loader/entries/02-archiso-speech-linux.conf" \
    "$PROFILE/packages.aarch64"
for w in livecd-talk iwd sshd systemd-networkd systemd-resolved ModemManager \
         hv_fcopy_daemon hv_kvp_daemon hv_vss_daemon vmtoolsd vmware-vmblock-fuse; do
    rm -f "$A/etc/systemd/system/multi-user.target.wants/$w.service"
done

# Foxtail overlay (profiledef, packages, pacman.conf, boot entries, airootfs).
cp -a "$ROOT/archiso/." "$PROFILE/"
mkdir -p "$BUILD/pkgcache"
sed -i "s|@LOCALREPO@|$BUILD/repo|; s|@MIRRORLIST@|$PROFILE/mirrorlist|; s|@PKGCACHE@|$BUILD/pkgcache|" "$PROFILE/pacman.conf"

# BIOS boot menu branding.
sed -i 's/Arch Linux install medium/Foxtail live/g; s/Arch Linux/Foxtail/g' "$PROFILE"/syslinux/*.cfg
magick -size 640x480 xc:black \( "$ROOT/branding/foxtail-logo.png" -resize 180x180 \) \
    -gravity center -geometry +0-60 -composite "$PROFILE/syslinux/splash.png"

# ---- Foxtail files ----
echo ":: installing Foxtail files into airootfs"
install -d "$A/usr/share/foxtail" "$A/usr/local/bin" "$A/etc/skel/.config"
cp -a "$ROOT/shell" "$A/usr/share/foxtail/shell"
rm -f "$A"/usr/share/foxtail/shell/icons/gen_icons.py
install -Dm644 "$ROOT/hypr/foxtail.lua" "$A/usr/share/foxtail/hypr/foxtail.lua"
install -Dm644 "$ROOT/hypr/hyprland.lua" "$A/etc/skel/.config/hypr/hyprland.lua"
install -m755 "$ROOT"/bin/* "$A/usr/local/bin/"

for v in gtk-3.0 gtk-4.0; do
    install -Dm644 "$ROOT/theme/$v/gtk.css" "$A/etc/skel/.config/$v/gtk.css"
    printf '@define-color accent_color #FF7A1A;\n@define-color accent_bg_color #FF7A1A;\n' \
        > "$A/etc/skel/.config/$v/foxtail-accent.css"
done
printf '[Settings]\ngtk-theme-name=adw-gtk3\ngtk-icon-theme-name=WhiteSur\ngtk-cursor-theme-name=macOS\ngtk-font-name=Inter 11\ngtk-decoration-layout=close,minimize,maximize:\n' \
    > "$A/etc/skel/.config/gtk-3.0/settings.ini"
install -Dm644 "$ROOT/theme/fontconfig/60-foxtail.conf" "$A/etc/fonts/conf.d/60-foxtail.conf"

install -d "$A/usr/share/backgrounds/foxtail"
cp "$ROOT"/branding/wallpapers/*.jpg "$A/usr/share/backgrounds/foxtail/"

install -d "$A/usr/share/sddm/themes" "$A/usr/share/plymouth/themes"
cp -a "$ROOT/sddm-theme/foxtail" "$A/usr/share/sddm/themes/foxtail"
cp -a "$ROOT/plymouth/foxtail" "$A/usr/share/plymouth/themes/foxtail"

for s in 16 22 24 32 48 64 128 256 512; do
    install -Dm644 "$ROOT/branding/icons/foxtail-$s.png" "$A/usr/share/icons/hicolor/${s}x${s}/apps/foxtail.png"
done
install -Dm644 "$ROOT/branding/foxtail-logo.png" "$A/usr/share/pixmaps/foxtail.png"
install -Dm644 "$ROOT/branding/foxtail-glyph.svg" "$A/usr/share/icons/hicolor/scalable/apps/foxtail-symbolic.svg"

# ---- build ----
echo ":: running mkarchiso"
rm -rf "$WORK"
mkdir -p "$OUT"
mkarchiso -v -r -w "$WORK" -o "$OUT" "$PROFILE"
chown -R "${SUDO_USER}:" "$OUT"
ls -lh "$OUT"/*.iso
