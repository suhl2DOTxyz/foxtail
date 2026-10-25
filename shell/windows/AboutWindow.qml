import QtQuick
import Quickshell
import qs.services
import qs.components

// "About This Foxtail": the compact Sonoma-style card.
FloatingWindow {
    id: win

    title: "About This Foxtail"
    visible: Panels.about
    onVisibleChanged: if (!visible) Panels.about = false
    implicitWidth: 280
    implicitHeight: 470
    minimumSize: Qt.size(280, 470)
    maximumSize: Qt.size(280, 470)
    color: "transparent"

    Rectangle {
        anchors.fill: parent
        radius: Theme.windowRadius
        color: Theme.dark ? "#262628" : "#F3F3F5"
        border.color: Theme.glassOutline
    }

    MouseArea {
        anchors.fill: parent
        onPressed: { try { win._backingWindow.startSystemMove(); } catch (e) {} }
    }

    TrafficLights {
        x: 14; y: 14
        onClose: Panels.about = false
        onMinimize: Panels.about = false
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 46
        spacing: 4
        width: parent.width - 40

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 120; height: 120
            sourceSize: Qt.size(240, 240)
            source: Qt.resolvedUrl("../icons/foxtail-logo.png")
        }
        Item { width: 1; height: 8 }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Foxtail"
            font.pixelSize: 26
            font.weight: Font.Bold
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: `Version ${SystemInfo.version} “${SystemInfo.codename}”`
            font.pixelSize: 11
            color: Theme.textSecondary
        }
        Item { width: 1; height: 16 }

        Repeater {
            model: [
                ["Chip", SystemInfo.cpu],
                ["Memory", SystemInfo.memory],
                ["Graphics", SystemInfo.gpu],
                ["Kernel", SystemInfo.kernel],
                ["Machine", SystemInfo.machine]
            ]
            Row {
                required property var modelData
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8
                Label { width: 70; horizontalAlignment: Text.AlignRight; text: modelData[0]; font.pixelSize: 11; font.weight: Font.DemiBold }
                Label { width: 150; text: modelData[1]; font.pixelSize: 11; color: Theme.textSecondary }
            }
        }

        Item { width: 1; height: 16 }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: moreLabel.implicitWidth + 24
            height: 24
            radius: 12
            color: Theme.control
            border.color: Theme.separator
            Label { id: moreLabel; anchors.centerIn: parent; text: "More Info…"; font.pixelSize: 12 }
            MouseArea { anchors.fill: parent; onClicked: { Panels.about = false; Panels.openSettings("general"); } }
        }

        Item { width: 1; height: 14 }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Made with 🧡 and a lot of tail-chasing."
            font.pixelSize: 10
            color: Theme.textTertiary
        }
    }
}
