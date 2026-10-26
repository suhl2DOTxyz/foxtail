import QtQuick
import Quickshell
import qs.services
import qs.components

// The Sound menu-bar extra, as on macOS: a volume slider and the output
// devices, with a shortcut to Sound settings.
Item {
    id: root

    property point windowOffset
    property size screenSize

    width: 280
    height: col.implicitHeight + 12

    MouseArea { anchors.fill: parent }

    Glass {
        anchors.fill: parent
        radius: Theme.menuRadius + 2
        color: Theme.glassStrong
        windowOffset: root.windowOffset
        screenSize: root.screenSize
        rimOpacity: 0.85
        bezel: 12
    }

    Column {
        id: col
        y: 6
        width: parent.width

        Item {
            width: parent.width
            height: 30
            Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Sound"; font.weight: Font.Bold }
        }
        Item {
            width: parent.width
            height: 40
            CCSlider {
                x: 12
                width: parent.width - 24
                height: 28
                anchors.verticalCenter: parent.verticalCenter
                icon: Audio.muted ? "speaker-mute" : "speaker"
                value: Audio.volume
                onMoved: v => Audio.setVolume(v)
            }
        }

        MenuItem { width: parent.width; separator: true }
        MenuItem { width: parent.width; header: true; text: "Output" }
        Repeater {
            model: Audio.sinks
            MenuItem {
                required property var modelData
                width: col.width
                text: Audio.deviceName(modelData)
                checkable: true
                checked: Audio.sink === modelData
                onTriggered: Audio.setSink(modelData)
            }
        }
        MenuItem { width: parent.width; separator: true }
        MenuItem {
            width: parent.width
            text: "Sound Settings…"
            onTriggered: { Panels.closeAll(); Panels.openSettings("sound"); }
        }
    }
}
