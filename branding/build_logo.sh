#!/usr/bin/env bash
# Build Foxtail logo assets from the master silhouette (fo.svg).
#   foxtail-glyph.svg  monochrome mark (menu bar, Plymouth, symbolic uses)
#   foxtail-logo.png   full color: orange gradient body, cream chest/ear
#   icons/             app icon PNGs at standard hicolor sizes
set -euo pipefail
cd "$(dirname "$0")"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cp fo.svg foxtail-glyph.svg

rsvg-convert -w 1024 -h 1024 fo.svg -o "$tmp/a.png"
magick "$tmp/a.png" -alpha extract "$tmp/mask.png"

# Cream underlay: the silhouette with its holes filled (close the gap between
# snout and tail first), pulled in from the outer fur so it only shows
# through the chest and ear.
magick "$tmp/mask.png" -morphology Close Disk:28 -bordercolor black -border 2 \
    -fill red -draw "color 0,0 floodfill" -shave 2x2 \
    -fill white +opaque red -fill black -opaque red \
    -morphology Erode Disk:18 "$tmp/cream_mask.png"

magick -size 1024x1024 gradient:'#FFB25A'-'#E0420C' -rotate -30 -gravity center -extent 1024x1024 "$tmp/grad.png"
magick -size 1024x1024 xc:'#FFF3E2' "$tmp/cream_mask.png" -alpha off -compose CopyOpacity -composite "$tmp/cream.png"
magick "$tmp/grad.png" "$tmp/mask.png" -alpha off -compose CopyOpacity -composite "$tmp/orange.png"
magick "$tmp/cream.png" "$tmp/orange.png" -compose Over -composite foxtail-logo.png

mkdir -p icons
for s in 16 22 24 32 48 64 128 256 512; do
    magick foxtail-logo.png -resize ${s}x${s} "icons/foxtail-${s}.png"
done
echo "logo assets built"
