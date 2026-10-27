import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.services
import qs.components

// System Settings › Bluetooth: your devices with battery levels, and nearby
// devices to pair. Scanning runs while this pane is open.
Column {
    id: pane
    spacing: 14

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property var named: (adapter?.devices.values ?? Bluetooth.devices.values).filter(d => d.name && d.name !== d.address.replace(/:/g, "-"))
    readonly property var mine: named.filter(d => d.paired || d.connected)
    readonly property var nearby: named.filter(d => !d.paired && !d.connected)

    function scan(on) {
        if (adapter && adapter.enabled) adapter.discovering = on;
    }
    Component.onCompleted: scan(true)
    Component.onDestruction: scan(false)
    onOnChanged: if (on) scan(true)

    function iconFor(d) {
        const i = d.icon ?? "";
        if (i.indexOf("headset") >= 0 || i.indexOf("headphone") >= 0 || i.indexOf("audio") >= 0) return "headphones";
        if (i.indexOf("mouse") >= 0) return "mouse";
        if (i.indexOf("keyboard") >= 0) return "keyboard";
        if (i.indexOf("gaming") >= 0) return "gamepad";
        if (i.indexOf("phone") >= 0) return "phone";
        if (i.indexOf("computer") >= 0) return "display";
        return "bluetooth";
    }
    function status(d) {
        if (d.pairing) return "Pairing…";
        if (d.state === BluetoothDeviceState.Connecting) return "Connecting…";
        if (d.state === BluetoothDeviceState.Disconnecting) return "Disconnecting…";
        if (d.connected) return "Connected" + (d.batteryAvailable ? ` · ${Math.round(d.battery * 100)}% battery` : "");
        return "Not connected";
    }

    Group {
        Item {
            width: parent.width
            height: 64
            Rectangle {
                id: bicon
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 36; height: 36; radius: 18
                color: "#0A84FF"
                Icon { anchors.centerIn: parent; size: 20; name: "bluetooth"; color: "white" }
            }
            Column {
                anchors.left: bicon.right
                anchors.leftMargin: 12
                anchors.right: btSwitch.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                Label { text: I18n.tr("Bluetooth"); font.weight: Font.DemiBold }
                Label {
                    width: parent.width
                    text: !pane.adapter ? "No Bluetooth adapter found."
                        : pane.on ? `This computer is discoverable as “${pane.adapter.name}” while this pane is open.` : "Off"
                    font.pixelSize: Theme.px(11)
                    color: Theme.textSecondary
                }
            }
            Switch {
                id: btSwitch
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                enabled: pane.adapter !== null
                checked: pane.on
                onToggled: c => { if (pane.adapter) pane.adapter.enabled = c; }
            }
        }
    }

    SectionTitle { visible: pane.on; text: I18n.tr("My Devices") }
    Note { visible: pane.on && pane.mine.length === 0; text: I18n.tr("No devices yet. Put a device in pairing mode and it will show up under Nearby Devices.") }
    Group {
        visible: pane.on && pane.mine.length > 0
        Repeater {
            model: pane.mine
            SettingRow {
                id: devRow
                required property var modelData
                required property int index
                icon: pane.iconFor(modelData)
                iconColor: modelData.connected ? Theme.accent : Theme.textSecondary
                label: modelData.name
                sub: pane.status(modelData)
                last: index === pane.mine.length - 1
                Row {
                    spacing: 6
                    PushButton {
                        text: devRow.modelData.connected ? "Disconnect" : "Connect"
                        onClicked: devRow.modelData.connected ? devRow.modelData.disconnect() : devRow.modelData.connect()
                    }
                    PushButton { text: I18n.tr("Forget"); destructive: true; onClicked: devRow.modelData.forget() }
                }
            }
        }
    }

    SectionTitle { visible: pane.on; text: I18n.tr("Nearby Devices") }
    Row {
        visible: pane.on && pane.nearby.length === 0
        spacing: 8
        Icon {
            size: 14; name: "restart"; color: Theme.textSecondary
            RotationAnimation on rotation { running: pane.adapter?.discovering ?? false; from: 0; to: 360; duration: Theme.ms(1600); loops: Animation.Infinite }
        }
        Label { text: I18n.tr("Looking for devices…"); font.pixelSize: Theme.px(12); color: Theme.textSecondary }
    }
    Group {
        visible: pane.on && pane.nearby.length > 0
        Repeater {
            model: pane.nearby
            SettingRow {
                id: nearRow
                required property var modelData
                required property int index
                icon: pane.iconFor(modelData)
                iconColor: Theme.textSecondary
                label: modelData.name
                sub: modelData.pairing ? "Pairing…" : ""
                last: index === pane.nearby.length - 1
                PushButton {
                    text: nearRow.modelData.pairing ? "Cancel" : "Connect"
                    onClicked: nearRow.modelData.pairing ? nearRow.modelData.cancelPair() : nearRow.modelData.pair()
                }
                // Once paired, trust it (so it reconnects by itself) and connect.
                Connections {
                    target: nearRow.modelData
                    function onPairedChanged() {
                        if (!nearRow.modelData.paired) return;
                        nearRow.modelData.trusted = true;
                        nearRow.modelData.connect();
                    }
                }
            }
        }
    }
}
