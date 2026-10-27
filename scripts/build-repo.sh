#!/usr/bin/env bash
# Build the signed [foxtail] pacman repository into build/foxtail-repo.
#
#   ./scripts/build-repo.sh            (as your user, needs the signing key)
#   FOXTAIL_PKGREL=2 ./scripts/...    hotfix: rebuild without a version bump
#   FOXTAIL_UNSIGNED=1 ./scripts/...   test builds without the key (CI); never publish these
#
# Packages: foxtail-desktop, foxtail-keyring, plus the AUR themes Foxtail
# depends on (built by build-aur.sh). Everything is signed with the Foxtail
# key, as is the repo database.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$PWD
OUT="$ROOT/build/foxtail-repo"
WORK="$ROOT/build/pkgwork"
VERSION=$(cat "$ROOT/VERSION")
PKGREL=${FOXTAIL_PKGREL:-1}
UNSIGNED=${FOXTAIL_UNSIGNED:-0}
KEY=$(gpg --list-secret-keys --with-colons "Foxtail OS Package Signing" 2>/dev/null | awk -F: '/^fpr/ {print $10; exit}' || true)

[ "$(id -u)" -ne 0 ] || { echo "run build-repo.sh as a normal user" >&2; exit 1; }
[ -n "$KEY" ] || [ "$UNSIGNED" = 1 ] || { echo "Foxtail signing key not found in your keyring" >&2; exit 1; }
export GPGKEY=$KEY FOXTAIL_ROOT=$ROOT
SIGN=(--sign --key "$KEY"); [ "$UNSIGNED" = 1 ] && SIGN=()

"$ROOT/scripts/build-aur.sh"

rm -rf "$WORK" "$OUT"
mkdir -p "$WORK" "$OUT"

for p in foxtail-keyring foxtail-desktop; do
    echo ":: building $p"
    cp -a "$ROOT/pkg/$p" "$WORK/$p"
    sed -i "s|^pkgver=@VERSION@|pkgver=$VERSION|; s|^pkgrel=@PKGREL@|pkgrel=$PKGREL|" "$WORK/$p/PKGBUILD"
    (cd "$WORK/$p" && PKGDEST="$OUT" makepkg --noconfirm --clean --cleanbuild "${SIGN[@]}" --nodeps)
done

# AUR packages: copy and sign.
for f in "$ROOT"/build/repo/*.pkg.tar.zst; do
    cp "$f" "$OUT/"
    [ "$UNSIGNED" = 1 ] || gpg --batch --yes --local-user "$KEY" --detach-sign "$OUT/$(basename "$f")"
done

if [ "$UNSIGNED" = 1 ]; then repo-add "$OUT/foxtail.db.tar.gz" "$OUT"/*.pkg.tar.zst
else repo-add --sign --key "$KEY" --verify "$OUT/foxtail.db.tar.gz" "$OUT"/*.pkg.tar.zst; fi
# GitHub release assets can't be symlinks: store real files under the names pacman requests.
for f in foxtail.db foxtail.files; do
    rm -f "$OUT/$f" "$OUT/$f.sig"
    cp "$OUT/$f.tar.gz" "$OUT/$f"
    [ "$UNSIGNED" = 1 ] || cp "$OUT/$f.tar.gz.sig" "$OUT/$f.sig"
done
ls -lh "$OUT"
