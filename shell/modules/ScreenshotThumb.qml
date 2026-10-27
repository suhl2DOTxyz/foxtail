import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// After a screenshot or recording, a thumbnail floats in the bottom-right
// corner for a few seconds, as on macOS: click it to open the file, swipe it
// right to dismiss. It stays while the pointer is over it.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property bool mine: modelData === Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) || (Quickshell.screens.length === 1)
    property string file: ""
    readonly property bool isVideo: file.endsWith(".mp4")
    visible: file !== "" && mine

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "foxtail-osd"
    exclusionMode: ExclusionMode.Ignore
    anchors { bottom: true; right: true }
    margins { bottom: 18; right: 18 }
    implicitWidth: 200
    implicitHeight: 140
    color: "transparent"

    Connections {
        target: Capture
        function onLastShotChanged() {
            if (!Capture.lastShot) return;
            root.file = Capture.lastShot;
            card.x = 0;
            card.opacity = 1;
            linger.restart();
        }
    }

    Timer {
        id: linger
        interval: 5000
        running: false
        onTriggered: if (!hover.hovered) root.dismiss(); else restart()
    }
    function dismiss() {
        slideOut.restart();
    }
    SequentialAnimation {
        id: slideOut
        NumberAnimation { target: card; property: "x"; to: root.width + 20; duration: Theme.ms(260); easing.type: Easing.InCubic }
        ScriptAction { script: { root.file = ""; Capture.lastShot = ""; } }
    }

    Item {
        id: card
        width: parent.width
        height: parent.height
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width, pic.paintedWidth + 8) || parent.width
            height: Math.min(parent.height, pic.paintedHeight + 8) || parent.height
            radius: 8
            color: Theme.dark ? "#3A3A3C" : "white"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.15)
            Rectangle {   // shadow
                z: -1
                anchors.fill: parent
                anchors.margins: -2
                anchors.topMargin: 2
                radius: 10
                color: Qt.rgba(0, 0, 0, 0.2)
            }
        }
        Image {
            id: pic
            anchors.centerIn: parent
            width: parent.width - 8
            height: parent.height - 8
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(400, 280)
            asynchronous: true
            visible: !root.isVideo
            source: root.file && !root.isVideo ? "file://" + root.file : ""
            cache: false
        }
        Icon {
            visible: root.isVideo
            anchors.centerIn: parent
            size: 48
            name: "play"
            color: Theme.textSecondary
        }

        HoverHandler { id: hover }
        DragHandler {
            id: swipe
            yAxis.enabled: false
            xAxis.minimum: -20
            onActiveChanged: if (!active) {
                if (card.x > 50) root.dismiss();
                else card.x = 0;
            }
        }
        TapHandler {
            onTapped: {
                Quickshell.execDetached(["xdg-open", root.file]);
                root.file = "";
                Capture.lastShot = "";
            }
        }
    }
}
