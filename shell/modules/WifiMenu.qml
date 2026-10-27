import QtQuick
import Quickshell
import Quickshell.Networking
import qs.services
import qs.components

// The Wi-Fi menu-bar extra: on/off switch, known and nearby networks, and an
// inline password prompt for secured networks.
Item {
    id: root

    property point windowOffset
    property size screenSize

    width: 290
    height: col.implicitHeight + 12

    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var networks: (wifi?.networks.values ?? [])
        .filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))
    property var askingFor: null

    Component.onCompleted: if (wifi) wifi.scannerEnabled = true
    Component.onDestruction: if (wifi) wifi.scannerEnabled = false

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
            height: 34
            Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Wi-Fi"); font.weight: Font.Bold }
            Switch {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                small: true
                checked: Networking.wifiEnabled
                onToggled: c => Networking.wifiEnabled = c
            }
        }

        MenuItem { width: parent.width; separator: true }

        MenuItem {
            width: parent.width
            header: true
            text: root.wifi ? (Networking.wifiEnabled ? "Networks" : "Wi-Fi is off") : "No Wi-Fi hardware"
        }

        Repeater {
            model: Networking.wifiEnabled ? root.networks.slice(0, 10) : []

            Item {
                id: net
                required property var modelData
                width: col.width
                height: 32

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 5
                    anchors.rightMargin: 5
                    radius: Theme.liquid ? 8 : 5
                    color: hover.containsMouse ? Theme.hover : "transparent"
                }

                Rectangle {
                    id: badge
                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24; height: 24; radius: 12
                    color: net.modelData.connected ? Theme.accent : Theme.controlOff
                    Icon {
                        anchors.centerIn: parent
                        size: 13
                        name: "wifi"
                        color: net.modelData.connected ? "white" : Theme.text
                        opacity: 0.4 + 0.6 * net.modelData.signalStrength
                    }
                }

                Label {
                    anchors.left: badge.right
                    anchors.leftMargin: 9
                    anchors.right: lock.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: net.modelData.name
                }

                Icon {
                    id: lock
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    size: 11
                    name: net.modelData.security === WifiSecurityType.Open ? "" : "lock"
                    color: Theme.textSecondary
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        const n = net.modelData;
                        if (n.connected) n.disconnect();
                        else if (n.known || n.security === WifiSecurityType.Open) n.connect();
                        else root.askingFor = n;
                    }
                }
            }
        }

        // Password prompt
        Item {
            visible: root.askingFor !== null
            width: parent.width
            height: visible ? 74 : 0
            Label {
                x: 14; y: 4
                text: `Password for “${root.askingFor?.name ?? ""}”`
                font.pixelSize: Theme.px(11)
                color: Theme.textSecondary
            }
            Rectangle {
                x: 12; y: 24
                width: parent.width - 24
                height: 26
                radius: 6
                color: Theme.control
                border.color: pw.activeFocus ? Theme.accent : "transparent"
                border.width: 2
                TextInput {
                    id: pw
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: TextInput.Password
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: Theme.px(13)
                    focus: root.askingFor !== null
                    onAccepted: {
                        root.askingFor.connectWithPsk(text);
                        text = "";
                        root.askingFor = null;
                    }
                }
            }
            Label {
                x: 14; y: 54
                text: I18n.tr("Press Return to join")
                font.pixelSize: Theme.px(10)
                color: Theme.textTertiary
            }
        }

        MenuItem { width: parent.width; separator: true }
        MenuItem {
            width: parent.width
            text: I18n.tr("Wi-Fi Settings…")
            onTriggered: Panels.openSettings("wifi")
        }
    }
}
