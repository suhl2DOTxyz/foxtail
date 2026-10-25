#!/usr/bin/env python3
"""Render branding/foxtail-logo.png as a truecolor fastfetch logo.

Each terminal cell is an upper half block (▀) whose foreground is the top
pixel and background the bottom pixel, so one row of text shows two rows of
the image. Transparent pixels are left as the terminal background.

    python3 theme/fastfetch/gen_logo.py [width]   ->  theme/fastfetch/foxtail.ans
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "..", "branding", "foxtail-logo.png")
OUT = os.path.join(HERE, "foxtail.ans")
WIDTH = int(sys.argv[1]) if len(sys.argv) > 1 else 34
ALPHA_CUTOFF = 110


def main():
    img = Image.open(SRC).convert("RGBA")
    img = img.crop(img.getbbox())                     # trim transparent margins
    h = round(img.height * WIDTH / img.width)
    h += h % 2                                         # even: two pixels per cell
    img = img.resize((WIDTH, h), Image.LANCZOS)
    px = img.load()

    lines = []
    for y in range(0, h, 2):
        row = []
        for x in range(WIDTH):
            top, bot = px[x, y], px[x, y + 1]
            t, b = top[3] >= ALPHA_CUTOFF, bot[3] >= ALPHA_CUTOFF
            if t and b:
                row.append(f"\x1b[38;2;{top[0]};{top[1]};{top[2]}m\x1b[48;2;{bot[0]};{bot[1]};{bot[2]}m▀\x1b[0m")
            elif t:
                row.append(f"\x1b[38;2;{top[0]};{top[1]};{top[2]}m▀\x1b[0m")
            elif b:
                row.append(f"\x1b[38;2;{bot[0]};{bot[1]};{bot[2]}m▄\x1b[0m")
            else:
                row.append(" ")
        lines.append("".join(row).rstrip())
    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {OUT}: {WIDTH}x{len(lines)} cells")


if __name__ == "__main__":
    main()
