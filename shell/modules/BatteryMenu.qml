import QtQuick
import Quickshell
import qs.services
import qs.components

// The battery menu-bar extra: charge, time remaining, power source and the
// power mode (Low Power / Balanced / Performance), like macOS.
Item {
    id: root

    property point windowOffset
    property size screenSize

    width: 270
    height: col.implicitHeight + 12

    MouseArea { anchors.fill: parent }

    Glass {
        anchors.fill: parent
        radius: Theme.menuRadius + 2
        color: Theme.glassStrong
        windowOffset: root.windowOffset
        screenSize: root.screenSize
        rimOpacity: 0.55
        bezel: 12
    }

    Column {
        id: col
        y: 6
        width: parent.width

        Item {
            width: parent.width
            height: 34
            Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: "Battery"; font.weight: Font.Bold }
            Label {
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                text: Power.percent + "%"
                color: Theme.textSecondary
            }
        }

        MenuItem { width: parent.width; header: true; text: "Power Source: " + Power.source }
        MenuItem {
            width: parent.width
            header: true
            visible: Power.timeLeft !== ""
            text: Power.timeLeft
        }

        MenuItem { width: parent.width; separator: true }
        MenuItem { width: parent.width; header: true; text: "Power Mode" }

        Repeater {
            model: [
                { id: "power-saver", name: "Low Power", icon: "drop" },
                { id: "balanced", name: "Balanced", icon: "half-circle" },
                { id: "performance", name: "High Performance", icon: "bolt" }
            ]
            MenuItem {
                required property var modelData
                width: col.width
                visible: modelData.id !== "performance" || Power.hasPerformance
                text: modelData.name
                checkable: true
                checked: Power.mode === modelData.id
                onTriggered: Power.setMode(modelData.id)
            }
        }

        MenuItem { width: parent.width; separator: true }
        MenuItem {
            width: parent.width
            text: "Battery Settings…"
            onTriggered: { Panels.closeAll(); Panels.openSettings("battery"); }
        }
    }
}
