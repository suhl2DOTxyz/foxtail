#!/usr/bin/env python3
"""Generate Foxtail wallpapers: soft layered dunes in the macOS spirit, and
the Foxtail 2.0 "Vixen" pair: flowing silk ribbons, for Light and Dark mode.

    python3 branding/gen_wallpapers.py  ->  branding/wallpapers/*.svg (+ .png via rsvg-convert)
"""
import math
import os
import subprocess

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "wallpapers")
W, H = 3840, 2400

THEMES = {
    "foxtail-dawn": {
        "sky": ["#FFE9CF", "#FFC48A", "#FF9A4D"],
        "layers": ["#FFB066", "#FF8A33", "#F26A1B", "#D9480F", "#B23A0C"],
        "glow": "#FFF4D6",
    },
    "foxtail-dusk": {
        "sky": ["#1A0B1F", "#3A1630", "#7A2E2A"],
        "layers": ["#8F3A1E", "#B4481A", "#D9571A", "#7A2410", "#3B1009"],
        "glow": "#FF9A4D",
    },
    "foxtail-ember": {
        "sky": ["#2B0A00", "#7A2100", "#E5500F"],
        "layers": ["#FF7A1A", "#E5560D", "#B33E08", "#7A2A06", "#3D1403"],
        "glow": "#FFD08A",
    },
}


def dune(i, n):
    """A smooth wave path spanning the canvas, lower layers sit lower."""
    base = H * (0.42 + 0.12 * i)
    amp = H * (0.10 - 0.012 * i)
    phase = i * 1.7
    freq = 1.1 + 0.35 * (i % 3)
    pts = []
    steps = 48
    for k in range(steps + 1):
        x = -200 + (W + 400) * k / steps
        t = x / W * math.pi * freq + phase
        y = base + amp * math.sin(t) + amp * 0.35 * math.sin(2.3 * t + i)
        pts.append((x, y))
    d = f"M-200,{H + 200} L{pts[0][0]:.0f},{pts[0][1]:.0f} "
    # Catmull-Rom -> cubic for smoothness
    for j in range(len(pts) - 1):
        p0 = pts[max(j - 1, 0)]
        p1, p2 = pts[j], pts[j + 1]
        p3 = pts[min(j + 2, len(pts) - 1)]
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        d += f"C{c1[0]:.0f},{c1[1]:.0f} {c2[0]:.0f},{c2[1]:.0f} {p2[0]:.0f},{p2[1]:.0f} "
    return d + f"L{W + 200},{H + 200} Z"


def svg(theme):
    sky = theme["sky"]
    layers = theme["layers"]
    defs = [f'''<linearGradient id="sky" x1="0" y1="0" x2="0.3" y2="1">
      <stop offset="0" stop-color="{sky[0]}"/><stop offset="0.55" stop-color="{sky[1]}"/>
      <stop offset="1" stop-color="{sky[2]}"/></linearGradient>
    <radialGradient id="glow" cx="0.72" cy="0.28" r="0.55">
      <stop offset="0" stop-color="{theme["glow"]}" stop-opacity="0.85"/>
      <stop offset="1" stop-color="{theme["glow"]}" stop-opacity="0"/></radialGradient>
    <filter id="soft" x="-5%" y="-5%" width="110%" height="110%"><feGaussianBlur stdDeviation="18"/></filter>''']
    body = ['<rect width="100%" height="100%" fill="url(#sky)"/>',
            '<rect width="100%" height="100%" fill="url(#glow)"/>']
    n = len(layers)
    for i, c in enumerate(layers):
        defs.append(f'''<linearGradient id="l{i}" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{c}" stop-opacity="0.92"/>
      <stop offset="1" stop-color="{c}" stop-opacity="1"/></linearGradient>''')
        body.append(f'<path d="{dune(i, n)}" fill="url(#l{i})" filter="url(#soft)"/>')
        # a crisp highlight ridge on top of each dune for depth
        body.append(f'<path d="{dune(i, n)}" fill="none" stroke="#FFFFFF" stroke-opacity="0.10" stroke-width="6" filter="url(#soft)"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n'
            f'  <defs>{"".join(defs)}</defs>\n  ' + "\n  ".join(body) + "\n</svg>\n")


# ---- Foxtail 2.0 "Vixen": silk ribbons sweeping across the screen ----
VIXEN = {
    "foxtail-vixen-day": {
        "bg": ["#FFF3E6", "#FFD9BF", "#FFB8A3"],
        "ribbons": [("#FF9A3C", "#FF5E3A"), ("#FF7A1A", "#E83A6B"), ("#FFB36B", "#FF7A59"),
                    ("#F2543D", "#C2347A"), ("#FFD08A", "#FF9A4D")],
        "glow": "#FFFFFF", "edge": 0.35,
    },
    "foxtail-vixen-night": {
        "bg": ["#120712", "#22091C", "#3A0E1E"],
        "ribbons": [("#FF7A1A", "#C2185B"), ("#E5500F", "#7B1FA2"), ("#FF9A4D", "#E83A6B"),
                    ("#B33E08", "#4A148C"), ("#FFB36B", "#FF5E3A")],
        "glow": "#FF7A1A", "edge": 0.22,
    },
}


def ribbon(i, n):
    """A wide S-shaped band from lower left to upper right; each one offset."""
    top, bottom = [], []
    steps = 60
    width = H * (0.16 - 0.018 * i)
    for k in range(steps + 1):
        u = k / steps
        x = -300 + (W + 600) * u
        y = H * (0.86 - 0.62 * u) + H * (0.13 + 0.03 * i) * math.sin(u * math.pi * 1.6 + i * 0.9) + (i - n / 2) * H * 0.07
        w = width * (0.55 + 0.45 * math.sin(u * math.pi * 1.2 + i))
        top.append((x, y - w / 2))
        bottom.append((x, y + w / 2))
    def smooth(pts):
        d = ""
        for j in range(len(pts) - 1):
            p0 = pts[max(j - 1, 0)]; p1, p2 = pts[j], pts[j + 1]; p3 = pts[min(j + 2, len(pts) - 1)]
            c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
            c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
            d += f"C{c1[0]:.0f},{c1[1]:.0f} {c2[0]:.0f},{c2[1]:.0f} {p2[0]:.0f},{p2[1]:.0f} "
        return d
    back = list(reversed(bottom))
    return (f"M{top[0][0]:.0f},{top[0][1]:.0f} " + smooth(top) + f"L{back[0][0]:.0f},{back[0][1]:.0f} "
            + smooth(back) + "Z")


def vixen_svg(t):
    bg = t["bg"]
    defs = [f'''<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="{bg[0]}"/><stop offset="0.55" stop-color="{bg[1]}"/>
      <stop offset="1" stop-color="{bg[2]}"/></linearGradient>
    <radialGradient id="glow" cx="0.68" cy="0.38" r="0.6">
      <stop offset="0" stop-color="{t["glow"]}" stop-opacity="0.55"/>
      <stop offset="1" stop-color="{t["glow"]}" stop-opacity="0"/></radialGradient>
    <filter id="soft" x="-10%" y="-10%" width="120%" height="120%"><feGaussianBlur stdDeviation="26"/></filter>
    <filter id="haze" x="-10%" y="-10%" width="120%" height="120%"><feGaussianBlur stdDeviation="90"/></filter>''']
    body = ['<rect width="100%" height="100%" fill="url(#bg)"/>']
    n = len(t["ribbons"])
    for i, (a, b) in enumerate(t["ribbons"]):
        defs.append(f'''<linearGradient id="r{i}" x1="0" y1="1" x2="1" y2="0">
      <stop offset="0" stop-color="{a}" stop-opacity="0.15"/><stop offset="0.45" stop-color="{a}" stop-opacity="0.9"/>
      <stop offset="1" stop-color="{b}" stop-opacity="0.85"/></linearGradient>''')
        d = ribbon(i, n)
        body.append(f'<path d="{d}" fill="url(#r{i})" filter="url(#haze)" opacity="0.6"/>')
        body.append(f'<path d="{d}" fill="url(#r{i})" filter="url(#soft)"/>')
        body.append(f'<path d="{d}" fill="none" stroke="#FFFFFF" stroke-opacity="{t["edge"]}" stroke-width="5" filter="url(#soft)"/>')
    body.append('<rect width="100%" height="100%" fill="url(#glow)"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">\n'
            f'  <defs>{"".join(defs)}</defs>\n  ' + "\n  ".join(body) + "\n</svg>\n")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    jobs = [(n, svg(t)) for n, t in THEMES.items()] + [(n, vixen_svg(t)) for n, t in VIXEN.items()]
    for name, text in jobs:
        path = os.path.join(OUT, name + ".svg")
        with open(path, "w") as f:
            f.write(text)
        png = path[:-4] + ".png"
        subprocess.run(["rsvg-convert", "-w", str(W), "-h", str(H), path, "-o", png], check=True)
        subprocess.run(["magick", png, "-quality", "92", png[:-4] + ".jpg"], check=True)
        os.remove(png)
        print("wrote", name)
