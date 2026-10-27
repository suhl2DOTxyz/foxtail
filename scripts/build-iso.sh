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

# ---- signed [foxtail] repo: foxtail-desktop, keyring, AUR themes ----
# Built as the invoking user (makepkg refuses root; the signing key is theirs).
sudo -u "${SUDO_USER:?run via sudo from your user account}" \
    env FOXTAIL_UNSIGNED="${FOXTAIL_UNSIGNED:-0}" "$ROOT/scripts/build-repo.sh"

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
# Foxtail packages are rebuilt every time under the same file names; drop the
# cached copies so pacman doesn't reject the new ones as "corrupted".
find "$BUILD/pkgcache" -maxdepth 1 -name 'foxtail-*.pkg.tar.zst*' -delete
# Version: one source of truth (VERSION at the repo root).
VERSION=$(cat "$ROOT/VERSION")
sed -i "s|@VERSION@|$VERSION|g" "$PROFILE/profiledef.sh"
sed -i "s|@LOCALREPO@|$BUILD/foxtail-repo|; s|@MIRRORLIST@|$PROFILE/mirrorlist|; s|@PKGCACHE@|$BUILD/pkgcache|" "$PROFILE/pacman.conf"

# BIOS boot menu branding.
sed -i 's/Arch Linux install medium/Foxtail live/g; s/Arch Linux/Foxtail/g' "$PROFILE"/syslinux/*.cfg
magick -size 640x480 xc:black \( "$ROOT/branding/foxtail-logo.png" -resize 180x180 \) \
    -gravity center -geometry +0-60 -composite "$PROFILE/syslinux/splash.png"

# Foxtail itself (shell, theme, branding, configs) comes from the
# foxtail-desktop package in packages.x86_64.

# ---- build ----
echo ":: running mkarchiso"
rm -rf "$WORK"
mkdir -p "$OUT"
mkarchiso -v -r -w "$WORK" -o "$OUT" "$PROFILE"
chown -R "${SUDO_USER}:" "$OUT"
ls -lh "$OUT"/*.iso
