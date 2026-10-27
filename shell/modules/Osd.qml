import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// Volume / brightness HUD: a small glass pill under the menu bar, top-right,
// as in recent macOS.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    property string kind: "volume"
    property bool showing: false
    visible: showing || hud.opacity > 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "foxtail-osd"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins { top: Theme.menuBarHeight + 8; right: 12 }
    implicitWidth: 300
    implicitHeight: 76
    color: "transparent"
    mask: Region {}

    Connections {
        target: Audio
        function onChangedByUser() { root.flash("volume"); }
    }
    Connections {
        target: Brightness
        function onChangedByUser() { root.flash("brightness"); }
    }

    function flash(k) {
        if (Panels.popover === "controlcenter") return;  // the sliders are already visible
        kind = k;
        showing = true;
        hide.restart();
    }

    Timer { id: hide; interval: 1600; onTriggered: root.showing = false }

    Item {
        id: hud
        x: 10
        y: 10
        width: 280
        height: 56
        opacity: root.showing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }

        Glass {
            anchors.fill: parent
            radius: Theme.liquid ? 28 : 16
            windowOffset: Qt.point(root.screen.width - root.width - 12, Theme.menuBarHeight + 8)
            screenSize: Qt.size(root.screen.width, root.screen.height)
        }

        Label {
            x: 18; y: 8
            text: root.kind === "volume" ? "Sound" : "Display"
            font.weight: Font.DemiBold
            font.pixelSize: Theme.px(12)
        }
        CCSlider {
            x: 16; y: 26
            width: parent.width - 32
            height: 20
            icon: root.kind === "volume" ? (Audio.muted ? "speaker-mute" : "speaker") : "sun-small"
            value: root.kind === "volume" ? (Audio.muted ? 0 : Audio.volume) : Brightness.value
            enabled: false
        }
    }
}
