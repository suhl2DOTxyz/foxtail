#!/usr/bin/env python3
"""Generate Foxtail's UI glyphs (SF Symbols-like, white on transparent).

They are drawn white and recolored at runtime by components/Icon.qml.
    python3 shell/icons/gen_icons.py
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
S = 'fill="none" stroke="#fff" stroke-linecap="round" stroke-linejoin="round"'
F = 'fill="#fff"'

ICONS = {
    "wifi": f'''<path {S} d="M2.5 9.2a14 14 0 0 1 19 0"/><path {S} d="M5.6 12.6a9.5 9.5 0 0 1 12.8 0"/>
        <path {S} d="M8.7 16a5 5 0 0 1 6.6 0"/><circle {F} cx="12" cy="19.2" r="1.5"/>''',
    "wifi-off": f'''<path {S} opacity=".35" d="M2.5 9.2a14 14 0 0 1 19 0M5.6 12.6a9.5 9.5 0 0 1 12.8 0M8.7 16a5 5 0 0 1 6.6 0"/>
        <circle {F} opacity=".35" cx="12" cy="19.2" r="1.5"/><path {S} d="M4 3l16 18"/>''',
    "bluetooth": f'''<path {S} d="M7 7.5l10 9-5 4.5V3l5 4.5-10 9"/>''',
    "speaker": f'''<path {F} d="M3.5 9h3.2L11.5 4.8v14.4L6.7 15H3.5z"/>
        <path {S} d="M15 9a4.2 4.2 0 0 1 0 6"/><path {S} d="M17.8 6.2a8.2 8.2 0 0 1 0 11.6"/>''',
    "speaker-mute": f'''<path {F} d="M3.5 9h3.2L11.5 4.8v14.4L6.7 15H3.5z"/><path {S} d="M15.5 9.5l5 5m0-5l-5 5"/>''',
    "speaker-low": f'''<path {F} d="M3.5 9h3.2L11.5 4.8v14.4L6.7 15H3.5z"/><path {S} d="M15 9a4.2 4.2 0 0 1 0 6"/>''',
    "sun": f'''<circle {F} cx="12" cy="12" r="4.2"/>
        <path {S} d="M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"/>''',
    "sun-small": f'''<circle {F} cx="12" cy="12" r="3.4"/>
        <path {S} stroke-width="1.6" d="M12 4.5v1.4M12 18.1v1.4M4.5 12h1.4M18.1 12h1.4M6.7 6.7l1 1M16.3 16.3l1 1M6.7 17.3l1-1M16.3 7.7l1-1"/>''',
    "moon": f'''<path {F} d="M20 14.6A8.5 8.5 0 1 1 9.4 4a7 7 0 0 0 10.6 10.6z"/>''',
    "half-circle": f'''<circle {S} cx="12" cy="12" r="8.5"/><path {F} d="M12 3.5a8.5 8.5 0 0 1 0 17z"/>''',
    "drop": f'''<path {S} d="M12 3.2c3.8 4.6 6.2 8 6.2 11a6.2 6.2 0 0 1-12.4 0c0-3 2.4-6.4 6.2-11z"/>
        <path {S} stroke-width="1.4" opacity=".75" d="M9 14.6a3 3 0 0 0 2.6 3"/>''',
    "search": f'''<circle {S} stroke-width="2" cx="10.5" cy="10.5" r="6"/><path {S} stroke-width="2.2" d="M15 15l5 5"/>''',
    "controls": f'''<rect {S} x="3" y="5" width="18" height="6" rx="3"/><circle {F} cx="16" cy="8" r="1.8"/>
        <rect {S} x="3" y="13" width="18" height="6" rx="3"/><circle {F} cx="8" cy="16" r="1.8"/>''',
    "battery": f'''<rect {S} stroke-width="1.4" x="2.5" y="7" width="17" height="10" rx="2.6"/><path {F} d="M21 10.3v3.4a1.6 1.6 0 0 0 0-3.4z"/>''',
    "bolt": f'''<path {F} d="M13 2L5 13.5h5.5L10 22l8-11.5h-5.5z"/>''',
    "power": f'''<path {S} d="M12 3v8"/><path {S} d="M7 5.8a8 8 0 1 0 10 0"/>''',
    "restart": f'''<path {S} d="M19.5 12a7.5 7.5 0 1 1-2.2-5.3"/><path {S} d="M18 3.5v4h-4"/>''',
    "lock": f'''<rect {F} x="5" y="10.5" width="14" height="10" rx="2.4"/><path {S} d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>''',
    "sleep": f'''<path {S} d="M20 14.6A8.5 8.5 0 1 1 9.4 4a7 7 0 0 0 10.6 10.6z"/>''',
    "logout": f'''<path {S} d="M14 4H6.5A1.5 1.5 0 0 0 5 5.5v13A1.5 1.5 0 0 0 6.5 20H14"/><path {S} d="M10 12h10m-3.5-3.5L20 12l-3.5 3.5"/>''',
    "gear": f'''<path {S} d="M12 8.6a3.4 3.4 0 1 0 0 6.8 3.4 3.4 0 0 0 0-6.8z"/>
        <path {S} d="M19.4 13.2l1.6 1.2-1.8 3.1-1.9-.7a7 7 0 0 1-2 1.2l-.3 2h-3.6l-.3-2a7 7 0 0 1-2-1.2l-1.9.7-1.8-3.1 1.6-1.2a7 7 0 0 1 0-2.4L3 9.6l1.8-3.1 1.9.7a7 7 0 0 1 2-1.2l.3-2h3.6l.3 2a7 7 0 0 1 2 1.2l1.9-.7L21 9.6l-1.6 1.2a7 7 0 0 1 0 2.4z"/>''',
    "grid": f'''<g {F}><rect x="3" y="3" width="7.5" height="7.5" rx="2"/><rect x="13.5" y="3" width="7.5" height="7.5" rx="2"/>
        <rect x="3" y="13.5" width="7.5" height="7.5" rx="2"/><rect x="13.5" y="13.5" width="7.5" height="7.5" rx="2"/></g>''',
    "chevron-right": f'''<path {S} stroke-width="2" d="M9.5 5.5L16 12l-6.5 6.5"/>''',
    "chevron-left": f'''<path {S} stroke-width="2" d="M14.5 5.5L8 12l6.5 6.5"/>''',
    "chevron-down": f'''<path {S} stroke-width="2" d="M5.5 9.5L12 16l6.5-6.5"/>''',
    "check": f'''<path {S} stroke-width="2.2" d="M5 12.5l4.5 4.5L19 7.5"/>''',
    "xmark": f'''<path {S} stroke-width="2" d="M6 6l12 12M18 6L6 18"/>''',
    "play": f'''<path {F} d="M7 4.5v15l12.5-7.5z"/>''',
    "pause": f'''<rect {F} x="6" y="4.5" width="4" height="15" rx="1"/><rect {F} x="14" y="4.5" width="4" height="15" rx="1"/>''',
    "forward": f'''<path {F} d="M3 6v12l8.5-6zM12 6v12l8.5-6z"/>''',
    "backward": f'''<path {F} d="M21 6v12l-8.5-6zM12 6v12L3.5 12z"/>''',
    "bell": f'''<path {S} d="M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 2h-15z"/><path {S} d="M10 20.5a2.2 2.2 0 0 0 4 0"/>''',
    "display": f'''<rect {S} x="2.5" y="4" width="19" height="12.5" rx="2"/><path {S} d="M8.5 20h7M12 16.5V20"/>''',
    "photo": f'''<rect {S} x="3" y="4.5" width="18" height="15" rx="2.5"/><circle {F} cx="8.5" cy="9.5" r="1.8"/>
        <path {S} d="M3.5 17l5-4.5 3.5 3 3-2.5 5.5 4.5"/>''',
    "dock": f'''<rect {S} x="2.5" y="3.5" width="19" height="17" rx="3"/><rect {F} x="5.5" y="15" width="13" height="3" rx="1.5"/>''',
    "info": f'''<circle {S} cx="12" cy="12" r="9"/><path {S} stroke-width="2.2" d="M12 11v6"/><circle {F} cx="12" cy="7.6" r="1.3"/>''',
    "keyboard": f'''<rect {S} x="2.5" y="6" width="19" height="12" rx="2.5"/>
        <path {S} stroke-width="1.6" d="M6 10h.01M9.3 10h.01M12.6 10h.01M15.9 10h.01M18 10h.01M7.5 14.5h9"/>''',
    "network": f'''<circle {S} cx="12" cy="12" r="9"/><path {S} d="M3 12h18M12 3c2.6 2.6 3.8 5.6 3.8 9s-1.2 6.4-3.8 9c-2.6-2.6-3.8-5.6-3.8-9S9.4 5.6 12 3z"/>''',
    "person": f'''<circle {F} cx="12" cy="8" r="4.2"/><path {F} d="M3.8 20.5a8.2 8.2 0 0 1 16.4 0z"/>''',
    "airplane": f'''<path {F} d="M21 15.5v-2l-7.5-4.6V4a1.5 1.5 0 0 0-3 0v4.9L3 13.5v2l7.5-2.3V18l-2 1.5V21l3.5-1 3.5 1v-1.5l-2-1.5v-4.8z"/>''',
    "accessibility": f'''<circle {F} cx="12" cy="4.6" r="1.9"/><path {S} d="M4.5 8.5l7.5 1.5 7.5-1.5M12 10v4.5M12 14.5l-3.5 6.5M12 14.5l3.5 6.5"/>''',
    "calendar": f'''<rect {S} x="3" y="5" width="18" height="16" rx="2.5"/><path {S} d="M3 10h18M8 3v4M16 3v4"/>''',
    "plus": f'''<path {S} stroke-width="2" d="M12 5v14M5 12h14"/>''',
    "minus": f'''<path {S} stroke-width="2" d="M5 12h14"/>''',
    "folder": f'''<path {F} d="M3 7a2 2 0 0 1 2-2h4.5l2 2.2H19a2 2 0 0 1 2 2V18a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>''',
    "calculator": f'''<rect {S} x="5" y="2.5" width="14" height="19" rx="2.5"/><rect {F} x="8" y="5.5" width="8" height="3.5" rx=".8"/>
        <path {S} stroke-width="2" d="M8.5 13h.01M12 13h.01M15.5 13h.01M8.5 17h.01M12 17h.01M15.5 17h.01"/>''',
    "globe": f'''<circle {S} cx="12" cy="12" r="9"/><path {S} d="M3.5 9h17M3.5 15h17M12 3c-3.2 3.6-3.2 14.4 0 18M12 3c3.2 3.6 3.2 14.4 0 18"/>''',
    "fullscreen": f'''<path {S} stroke-width="2" d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>''',
    "trash": f'''<path {S} d="M4 6.5h16M9.5 6.5V4.5h5v2M6 6.5l1 13.5h10l1-13.5"/>''',
    "eye": f'''<path {S} d="M2.5 12S6 5.5 12 5.5 21.5 12 21.5 12 18 18.5 12 18.5 2.5 12 2.5 12z"/><circle {F} cx="12" cy="12" r="3"/>''',
    "arrow-right-circle": f'''<circle {S} cx="12" cy="12" r="9"/><path {S} stroke-width="2" d="M8 12h8m-3-3.5L16.5 12 13 15.5"/>''',
    "music": f'''<path {F} d="M9 17.5V6l11-2.5v11.5"/><circle {F} cx="6.5" cy="17.5" r="2.8"/><circle {F} cx="17.5" cy="15" r="2.8"/>''',
}


if __name__ == "__main__":
    for name, body in ICONS.items():
        with open(os.path.join(HERE, name + ".svg"), "w") as f:
            f.write('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" '
                    f'stroke-width="1.8">{body}</svg>\n')
    print(f"wrote {len(ICONS)} icons")
