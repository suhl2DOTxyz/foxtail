#!/usr/bin/env bash
# Publish a version as a GitHub release from out/release-<version>/
# (the split ISO parts, SHA256SUMS and notes.md).
#
#   ./scripts/publish-release.sh 1.4
set -euo pipefail
cd "$(dirname "$0")/.."
REPO_SLUG=suhl2DOTxyz/foxtail
V="${1:?usage: publish-release.sh <version>}"
DIR="out/release-$V"

[ -f "$DIR/notes.md" ] || { echo "missing $DIR/notes.md" >&2; exit 1; }
gh release create "v$V" --repo "$REPO_SLUG" ${LATEST:---latest} \
    --title "Foxtail $V" --notes-file "$DIR/notes.md" \
    "$DIR"/*.iso.part* "$DIR/SHA256SUMS"
