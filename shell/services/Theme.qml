pragma Singleton
import QtQuick
import Quickshell

// Design tokens. Values follow macOS proportions (13pt UI text, 24px menu bar,
// 10/14/22px radii) with the Foxtail orange accent.
Singleton {
    id: root

    readonly property bool dark: Settings.darkMode
    // Accessibility: Increase contrast implies solid (non-translucent) surfaces
    // with stronger outlines and text, like macOS.
    readonly property bool contrast: Settings.increaseContrast
    readonly property bool solid: Settings.reduceTransparency || contrast
    readonly property bool liquid: Settings.liquidGlass && !solid

    readonly property color accent: Settings.accent
    readonly property color accentText: "#FFFFFF"

    readonly property color text: dark ? "#F5F5F7" : "#1D1D1F"
    readonly property color textSecondary: dark ? Qt.rgba(1, 1, 1, contrast ? 0.85 : 0.62) : Qt.rgba(0, 0, 0, contrast ? 0.8 : 0.55)
    readonly property color textTertiary: dark ? Qt.rgba(1, 1, 1, contrast ? 0.65 : 0.38) : Qt.rgba(0, 0, 0, contrast ? 0.6 : 0.32)
    readonly property color separator: dark ? Qt.rgba(1, 1, 1, contrast ? 0.45 : 0.12) : Qt.rgba(0, 0, 0, contrast ? 0.45 : 0.10)
    readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(0, 0, 0, 0.06)
    readonly property color pressed: dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.12)
    readonly property color control: dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.07)
    readonly property color controlOff: dark ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(0, 0, 0, 0.14)

    // Glass base tint. Liquid glass is clearer; classic vibrancy is milkier.
    readonly property color glass: solid
        ? (dark ? "#2A2A2C" : "#ECECEE")
        : liquid
            ? (dark ? Qt.rgba(0.10, 0.10, 0.11, 0.34) : Qt.rgba(1, 1, 1, 0.20))
            : (dark ? Qt.rgba(0.14, 0.14, 0.15, 0.72) : Qt.rgba(0.96, 0.96, 0.97, 0.74))
    readonly property color glassStrong: solid
        ? (dark ? "#323234" : "#F4F4F6")
        : liquid
            ? (dark ? Qt.rgba(0.12, 0.12, 0.13, 0.55) : Qt.rgba(1, 1, 1, 0.52))
            : (dark ? Qt.rgba(0.16, 0.16, 0.17, 0.84) : Qt.rgba(0.97, 0.97, 0.98, 0.86))
    // Tiles inside Control Center etc.
    readonly property color tile: dark ? Qt.rgba(1, 1, 1, liquid ? 0.10 : 0.08) : Qt.rgba(1, 1, 1, liquid ? 0.38 : 0.55)
    readonly property color glassBorder: dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.55)
    readonly property color glassOutline: contrast ? (dark ? "#FFFFFF" : "#000000")
                                        : dark ? Qt.rgba(0, 0, 0, 0.55) : Qt.rgba(0, 0, 0, 0.12)

    readonly property color menuBar: solid
        ? (dark ? "#1E1E1E" : "#EDEDED")
        : liquid && !Settings.menuBarBackground ? Qt.rgba(0, 0, 0, 0.0)  // Tahoe: the bar itself is fully clear
                 : (dark ? Qt.rgba(0.12, 0.12, 0.12, 0.45) : Qt.rgba(1, 1, 1, 0.45))
    // Menu bar text sits on the wallpaper when clear, so it follows wallpaper brightness.
    readonly property color menuBarText: liquid && !Settings.menuBarBackground ? (wallpaperDark ? "#FFFFFF" : "#000000") : text
    property bool wallpaperDark: Settings.wallpaper.indexOf("dusk") >= 0 || Settings.wallpaper.indexOf("ember") >= 0

    readonly property string font: "Inter"
    readonly property string fontDisplay: "Inter Display"
    readonly property string fontMono: "JetBrains Mono"
    // Accessibility ▸ Text size scales all shell text; Reduce motion turns
    // animations into instant changes.
    readonly property real textScale: Math.max(0.9, Math.min(1.35, Settings.textScale))
    readonly property bool reduceMotion: Settings.reduceMotion
    function px(n) { return Math.round(n * textScale); }
    function ms(n) { return reduceMotion ? 0 : n; }

    readonly property int fontSize: px(13)
    readonly property int fontSizeSmall: px(11)

    readonly property int menuBarHeight: 28
    readonly property int radiusSmall: 6
    readonly property int radius: 12
    readonly property int radiusLarge: liquid ? 26 : 18
    readonly property int menuRadius: liquid ? 14 : 10
    // Foxtail's own windows (Settings, About, ...). Must match the Hyprland
    // rule "foxtail-shell-windows" rounding, which clips them to this radius.
    readonly property int windowRadius: 20

    readonly property int animFast: ms(120)
    readonly property int anim: ms(220)
    readonly property int animSlow: ms(380)
}
