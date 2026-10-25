import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services

// A half-resolution snapshot of what is on screen - windows included - for
// Liquid Glass popovers to refract. Snapshots are only taken while no popover
// is showing, so the glass never ends up refracting itself; they're refreshed
// shortly after windows open, close, move or change focus.
ScreencopyView {
    id: root

    required property var screen
    // True while a surface that uses this backdrop is on screen.
    property bool inUse: false

    readonly property bool wanted: Theme.liquid && Settings.refractWindows
    readonly property bool ready: wanted && hasContent

    visible: false
    live: false
    paintCursor: false
    captureSource: wanted ? screen : null
    constraintSize: Qt.size(screen.width / 2, screen.height / 2)

    function refresh() {
        if (wanted) settle.restart();
    }

    // Let animations finish (and popovers fully disappear) before capturing.
    Timer {
        id: settle
        interval: 350
        onTriggered: if (!root.inUse) root.captureFrame()
    }

    // Slow heartbeat so the snapshot never gets very stale (videos, scrolling).
    Timer {
        interval: 3000
        repeat: true
        running: root.wanted && !root.inUse
        onTriggered: root.captureFrame()
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
