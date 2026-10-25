#!/usr/bin/env bash
# Publish build/foxtail-repo as the [foxtail] pacman repository: the assets of
# the GitHub release tagged "repo", which installed systems use as
#   Server = https://github.com/suhl2DOTxyz/foxtail/releases/download/repo
#
#   ./scripts/build-repo.sh && ./scripts/publish-repo.sh
#
# Uploads the database and every package (replacing same-named assets) and
# removes packages that are no longer in the database.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO_SLUG=suhl2DOTxyz/foxtail
TAG=repo
DIR=build/foxtail-repo

[ -f "$DIR/foxtail.db" ] || { echo "build the repo first: scripts/build-repo.sh" >&2; exit 1; }

if ! gh release view "$TAG" --repo "$REPO_SLUG" >/dev/null 2>&1; then
    gh release create "$TAG" --repo "$REPO_SLUG" --latest=false \
        --title "Foxtail package repository" \
        --notes "Signed pacman repository for installed Foxtail systems. Not an installer - see the latest release for the ISO."
fi

# Packages first, database last, so the database never points at a package
# that isn't uploaded yet.
mapfile -t pkgs < <(cd "$DIR" && ls -1 ./*.pkg.tar.zst ./*.pkg.tar.zst.sig | sed 's|^\./||')
(cd "$DIR" && gh release upload "$TAG" --repo "$REPO_SLUG" --clobber "${pkgs[@]}")
(cd "$DIR" && gh release upload "$TAG" --repo "$REPO_SLUG" --clobber \
    foxtail.db foxtail.db.sig foxtail.files foxtail.files.sig)

# Drop packages that the new database no longer references.
keep=" ${pkgs[*]} foxtail.db foxtail.db.sig foxtail.files foxtail.files.sig "
gh release view "$TAG" --repo "$REPO_SLUG" --json assets --jq '.assets[].name' | while read -r a; do
    case "$keep" in *" $a "*) ;; *) echo ":: removing stale $a"; gh release delete-asset "$TAG" "$a" --repo "$REPO_SLUG" --yes ;; esac
done
echo ":: published https://github.com/$REPO_SLUG/releases/tag/$TAG"
