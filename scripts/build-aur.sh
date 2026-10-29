#!/usr/bin/env bash
# Build the AUR packages Foxtail ships (icon + cursor themes) into a local
# pacman repo at build/repo. Run as a normal user (makepkg refuses root).
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
REPO="$ROOT/build/repo"
SRC="$ROOT/build/aur"
PKGS=(whitesur-icon-theme apple_cursor ttf-twemoji)

[ "$(id -u)" -ne 0 ] || { echo "run build-aur.sh as a normal user" >&2; exit 1; }
mkdir -p "$REPO" "$SRC"

for p in "${PKGS[@]}"; do
    if ls "$REPO/$p"-[0-9]*.pkg.tar.* >/dev/null 2>&1; then
        echo ":: $p already built"
        continue
    fi
    echo ":: building $p"
    if [ -d "$SRC/$p/.git" ]; then git -C "$SRC/$p" pull -q; else git clone -q "https://aur.archlinux.org/$p.git" "$SRC/$p"; fi
    (cd "$SRC/$p" && PKGDEST="$REPO" makepkg --noconfirm --clean --cleanbuild --needed --syncdeps)
done

rm -f "$REPO"/foxtail-local.db* "$REPO"/foxtail-local.files*
repo-add -q "$REPO/foxtail-local.db.tar.gz" "$REPO"/*.pkg.tar.*
echo ":: local repo ready at $REPO"
