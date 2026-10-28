import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

// What Liquid Glass popovers lens: a blurred, half-resolution snapshot of the
// screen - windows included - or, with "refract windows" off, the blurred
// wallpaper. Snapshots are only taken while no popover is showing, so the
// glass never ends up refracting itself; they're refreshed shortly after
// windows open, close, move or change focus.
Item {
    id: root

    required property var screen
    // True while a surface that uses this backdrop is on screen.
    property bool inUse: false

    readonly property bool wanted: Theme.liquid && Settings.refractWindows
    readonly property bool ready: wanted ? copy.hasContent : (wallpaper.item?.ready ?? false)
    readonly property Item texture: wanted ? blurred : (wallpaper.item?.texture ?? null)
    readonly property Item sharp: wanted ? copyTex : (wallpaper.item?.sharp ?? null)

    readonly property size texSize: Qt.size(Math.round(screen.width / 2), Math.round(screen.height / 2))

    // ScreencopyView isn't a texture provider: hidden with `visible: false`
    // it would hand the glass an empty (black) texture. It stays in the scene
    // and copyTex draws it into a texture instead (hideSource keeps it off
    // screen).
    ScreencopyView {
        id: copy
        width: root.texSize.width
        height: root.texSize.height
        live: false
        paintCursor: false
        captureSource: root.wanted ? root.screen : null
        constraintSize: root.texSize
    }

    ShaderEffectSource {
        id: copyTex
        visible: false
        width: copy.width
        height: copy.height
        sourceItem: copy
        hideSource: true
        smooth: true
    }

    // Blurred to roughly match the compositor's own blur, so the lensed rim
    // and the live blur in the middle of the glass meet without a seam.
    MultiEffect {
        id: fx
        width: root.texSize.width
        height: root.texSize.height
        source: copyTex
        autoPaddingEnabled: false
        blurEnabled: root.wanted
        blur: 1.0
        blurMax: Math.round(Math.min(64, Theme.glassBlur / 2))
    }

    ShaderEffectSource {
        id: blurred
        visible: false
        width: fx.width
        height: fx.height
        sourceItem: fx
        hideSource: true
        smooth: true
    }

    Loader {
        id: wallpaper
        active: Theme.liquid && !root.wanted
        sourceComponent: WallpaperBackdrop { screenSize: Qt.size(root.screen.width, root.screen.height) }
    }

    function refresh() {
        if (wanted) settle.restart();
    }

    // Let animations finish (and popovers fully disappear) before capturing.
    Timer {
        id: settle
        interval: 350
        onTriggered: if (!root.inUse) copy.captureFrame()
    }

    // Slow heartbeat so the snapshot never gets very stale (videos, scrolling).
    Timer {
        interval: 3000
        repeat: true
        running: root.wanted && !root.inUse
        onTriggered: copy.captureFrame()
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (/^(openwindow|closewindow|movewindow|activewindow|workspace|changefloatingmode|fullscreen|windowtitle)/.test(event.name))
                root.refresh();
        }
    }

    onInUseChanged: if (!inUse) refresh()
    onWantedChanged: refresh()
    Component.onCompleted: refresh()
}
