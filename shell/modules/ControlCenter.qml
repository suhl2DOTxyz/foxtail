import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import qs.services
import qs.components

// Control Center as in macOS 26/27: one glass panel under the menu bar
// holding module platters. Top left, the connectivity module (labelled
// circles); top right, Focus and two small toggles; then Display, Sound and
// Now Playing. Circles fill with the accent colour when on.
Item {
    id: root

    property point windowOffset
    property size screenSize

    readonly property real pad: 10
    readonly property real gap: 10
    readonly property real inner: width - pad * 2
    readonly property real half: (inner - gap) / 2
    readonly property real moduleRadius: 18    // concentric inside the panel's 28

    width: 320
    height: col.implicitHeight + pad * 2

    readonly property var player: Mpris.players.values.length ? Mpris.players.values[0] : null
    readonly property var wifiNet: {
        const d = Networking.devices.values.find(d => d.type === DeviceType.Wifi && d.connected);
        return d?.networks.values.find(n => n.connected) ?? null;
    }

    // The panel drops in from the menu-bar icon with a soft spring.
    transformOrigin: Item.TopRight
    scale: 0.94
    opacity: 0
    Component.onCompleted: { scale = 1; opacity = 1; }
    Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutBack; easing.overshoot: 1.05 } }
    Behavior on opacity { NumberAnimation { duration: Theme.anim } }

    MouseArea { anchors.fill: parent }  // clicks on the panel don't close it

    Glass {
        anchors.fill: parent
        radius: 28
        color: Theme.glassStrong
        screenSize: root.screenSize
        windowOffset: root.windowOffset
        bezel: 14
        refraction: 6
    }

    Column {
        id: col
        x: root.pad
        y: root.pad
        width: root.inner
        spacing: root.gap

        // ---- connectivity + Focus / toggles ----
        Row {
            spacing: root.gap

            Module {
                width: root.half
                height: right.height
                Column {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8
                    Toggle {
                        icon: Networking.wifiEnabled ? "wifi" : "wifi-off"
                        title: I18n.tr("Wi-Fi")
                        subtitle: !Networking.wifiEnabled ? I18n.tr("Off") : (root.wifiNet?.name ?? I18n.tr("Not Connected"))
                        on: Networking.wifiEnabled
                        onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                    }
                    Toggle {
                        icon: "bluetooth"
                        title: I18n.tr("Bluetooth")
                        subtitle: !Bluetooth.defaultAdapter ? I18n.tr("Unavailable") : (Bluetooth.defaultAdapter.enabled ? I18n.tr("On") : I18n.tr("Off"))
                        on: Bluetooth.defaultAdapter?.enabled ?? false
                        enabled: Bluetooth.defaultAdapter !== null
                        onClicked: Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                    }
                    Toggle {
                        icon: "drop"
                        title: I18n.tr("Liquid Glass")
                        subtitle: Settings.liquidGlass ? I18n.tr("On") : I18n.tr("Off")
                        on: Settings.liquidGlass
                        onClicked: Settings.liquidGlass = !Settings.liquidGlass
                    }
                }
            }

            Column {
                id: right
                spacing: root.gap

                // Focus
                Module {
                    width: root.half
                    height: 56
                    pressable: true
                    onClicked: Settings.doNotDisturb = !Settings.doNotDisturb
                    Circle {
                        id: moon
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        icon: "moon"
                        on: Settings.doNotDisturb
                        onColor: "#5E5CE6"
                    }
                    Column {
                        anchors.left: moon.right
                        anchors.leftMargin: 8
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        Label { width: parent.width; text: I18n.tr("Focus"); font.weight: Font.DemiBold; font.pixelSize: Theme.px(12) }
                        Label { width: parent.width; text: Settings.doNotDisturb ? I18n.tr("Do Not Disturb") : I18n.tr("Off"); color: Theme.textSecondary; font.pixelSize: Theme.px(11) }
                    }
                }

                Row {
                    spacing: root.gap
                    Small {
                        icon: "half-circle"
                        title: I18n.tr("Dark Mode")
                        on: Settings.darkMode
                        onClicked: { Settings.appearanceAuto = false; Settings.darkMode = !Settings.darkMode; }
                    }
                    Small {
                        icon: Capture.recording ? "stop" : "screen-capture"
                        title: Capture.recording ? I18n.tr("Stop") : I18n.tr("Screenshot")
                        on: Capture.recording
                        onClicked: {
                            Panels.closeAll();
                            if (Capture.recording) Capture.stop();
                            else Panels.screenshotBar = true;
                        }
                    }
                }
            }
        }

        // ---- Display ----
        SliderModule {
            visible: Brightness.available
            label: I18n.tr("Display")
            icon: "sun-small"
            value: Brightness.value
            onMoved: v => Brightness.set(v)
            HeaderToggle {
                icon: "nightshift"
                text: I18n.tr("Night Shift")
                on: Displays.nightShiftActive
                onClicked: Settings.nightShiftNow = !Displays.nightShiftActive
            }
        }
        // Without a brightness control, Night Shift still gets a home.
        Module {
            visible: !Brightness.available
            width: root.inner
            height: 40
            Label { x: 14; anchors.verticalCenter: parent.verticalCenter; text: I18n.tr("Display"); font.weight: Font.DemiBold; font.pixelSize: Theme.px(12) }
            HeaderToggle {
                anchors.verticalCenter: parent.verticalCenter
                icon: "nightshift"
                text: I18n.tr("Night Shift")
                on: Displays.nightShiftActive
                onClicked: Settings.nightShiftNow = !Displays.nightShiftActive
            }
        }

        // ---- Sound ----
        SliderModule {
            id: soundTile
            property bool devicesOpen: false
            label: I18n.tr("Sound")
            icon: Audio.muted ? "speaker-mute" : "speaker"
            value: Audio.muted ? 0 : Audio.volume
            onMoved: v => Audio.setVolume(v)
            height: 66 + (devicesOpen ? deviceList.implicitHeight + 8 : 0)
            Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
            HeaderToggle {
                visible: Audio.sinks.length > 0
                icon: Audio.deviceIcon(Audio.sink)
                text: Audio.sinks.length > 1 ? I18n.tr("Output") : Audio.deviceName(Audio.sink)
                chevron: true
                on: soundTile.devicesOpen
                onClicked: soundTile.devicesOpen = !soundTile.devicesOpen
            }
            Column {
                id: deviceList
                visible: soundTile.devicesOpen
                x: 10
                y: 66
                width: parent.width - 20
                Repeater {
                    model: Audio.sinks
                    Rectangle {
                        id: dev
                        required property var modelData
                        readonly property bool current: Audio.sink === modelData
                        width: deviceList.width
                        height: 32
                        radius: 9
                        color: devMouse.containsMouse ? Theme.hover : "transparent"
                        Rectangle {
                            id: devIcon
                            x: 6
                            anchors.verticalCenter: parent.verticalCenter
                            width: 24; height: 24; radius: 12
                            color: dev.current ? Theme.accent : Theme.controlOff
                            Icon { anchors.centerIn: parent; size: 13; name: Audio.deviceIcon(dev.modelData); color: dev.current ? "white" : Theme.text }
                        }
                        Label {
                            anchors.left: devIcon.right
                            anchors.leftMargin: 10
                            anchors.right: parent.right
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: Audio.deviceName(dev.modelData)
                            font.pixelSize: Theme.px(12)
                        }
                        MouseArea { id: devMouse; anchors.fill: parent; hoverEnabled: true; onClicked: Audio.setSink(dev.modelData) }
                    }
                }
            }
        }

        // ---- Now Playing ----
        Module {
            width: root.inner
            height: 64
            Rectangle {
                id: art
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 44; height: 44; radius: 9
                color: Theme.control
                clip: true
                Image {
                    anchors.fill: parent
                    source: root.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !(root.player?.trackArtUrl)
                    name: "music"; size: 20
                    color: Theme.textSecondary
                }
            }
            Column {
                anchors.left: art.right
                anchors.leftMargin: 10
                anchors.right: controls.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                Label { width: parent.width; text: root.player?.trackTitle || I18n.tr("Not Playing"); font.weight: Font.DemiBold; font.pixelSize: Theme.px(12) }
                Label { width: parent.width; visible: text !== ""; text: root.player?.trackArtist ?? ""; color: Theme.textSecondary; font.pixelSize: Theme.px(11) }
            }
            Row {
                id: controls
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 16
                Glyph { name: "backward"; onClicked: root.player?.previous() }
                Glyph { name: root.player?.isPlaying ? "pause" : "play"; onClicked: root.player?.togglePlaying() }
                Glyph { name: "forward"; onClicked: root.player?.next() }
            }
        }
    }

    // ================= pieces =================

    // A module platter on the panel; optionally clickable as a whole.
    component Module: Rectangle {
        id: mod
        property bool pressable: false
        readonly property bool hovered: modMouse.containsMouse
        signal clicked()
        radius: root.moduleRadius
        color: modMouse.containsMouse && pressable ? Qt.lighter(Theme.tile, Theme.dark ? 1.4 : 1.05) : Theme.tile
        border.width: Theme.contrast ? 1 : 0
        border.color: Theme.separator
        MouseArea {
            id: modMouse
            anchors.fill: parent
            enabled: mod.pressable
            hoverEnabled: true
            cursorShape: mod.pressable ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: mod.clicked()
        }
    }

    // A round toggle: grey when off, filled with a colour (and a white glyph)
    // when on.
    component Circle: Rectangle {
        id: c
        property string icon
        property bool on: false
        property color onColor: Theme.accent
        property bool hovered: false
        width: 30; height: 30; radius: 15
        color: on ? onColor : Theme.controlOff
        Behavior on color { ColorAnimation { duration: Theme.animFast } }
        Icon { anchors.centerIn: parent; size: 15; name: c.icon; color: c.on ? "white" : Theme.text }
    }

    // Circle + title + subtitle row (the connectivity module).
    component Toggle: Item {
        id: t
        property string icon
        property string title
        property string subtitle
        property bool on: false
        signal clicked()
        Accessible.role: Accessible.CheckBox
        Accessible.name: title
        Accessible.description: subtitle
        Accessible.checkable: true
        Accessible.checked: on
        Accessible.onPressAction: t.clicked()
        width: parent.width
        height: 30
        opacity: enabled ? 1 : 0.45
        Circle { id: tc; icon: t.icon; on: t.on; scale: tm.pressed ? 0.92 : 1; Behavior on scale { NumberAnimation { duration: Theme.ms(120) } } }
        Column {
            anchors.left: tc.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            Label { width: parent.width; text: t.title; font.weight: Font.DemiBold; font.pixelSize: Theme.px(12) }
            Label { width: parent.width; text: t.subtitle; color: Theme.textSecondary; font.pixelSize: Theme.px(10) }
        }
        MouseArea { id: tm; anchors.fill: parent; enabled: t.enabled; cursorShape: Qt.PointingHandCursor; onClicked: t.clicked() }
    }

    // A small square module holding just its circle (its name shows on hover).
    component Small: Module {
        id: s
        property string icon
        property string title
        property bool on: false
        Accessible.role: Accessible.CheckBox
        Accessible.name: title
        Accessible.checkable: true
        Accessible.checked: on
        Accessible.onPressAction: s.clicked()
        width: (root.half - root.gap) / 2
        height: width
        pressable: true
        Circle { anchors.centerIn: parent; width: 34; height: 34; radius: 17; icon: s.icon; on: s.on }
        Rectangle {
            visible: s.hovered && s.title !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 4
            z: 10
            width: tipLabel.implicitWidth + 14
            height: 20
            radius: 6
            color: Theme.glassStrong
            border.width: 1
            border.color: Theme.separator
            Label { id: tipLabel; anchors.centerIn: parent; text: s.title; font.pixelSize: Theme.px(11) }
        }
    }

    component Glyph: Item {
        id: g
        property string name
        signal clicked()
        width: 18; height: 18
        Icon { anchors.centerIn: parent; size: 15; name: g.name; color: Theme.text }
        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: g.clicked() }
    }

    // Small pill at the top right of a slider module (Night Shift, output).
    component HeaderToggle: Rectangle {
        id: ht
        property string icon
        property string text
        property bool on: false
        property bool chevron: false
        signal clicked()
        anchors.right: parent?.right
        anchors.rightMargin: 10
        y: 7
        width: Math.min(htRow.implicitWidth + 16, 170)
        height: 22
        radius: 11
        color: ht.on ? Theme.accent : (htMouse.containsMouse ? Theme.hover : "transparent")
        Row {
            id: htRow
            anchors.centerIn: parent
            spacing: 5
            Icon { size: 12; name: ht.icon; color: ht.on ? "white" : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            Label {
                text: ht.text
                font.pixelSize: Theme.px(11)
                color: ht.on ? "white" : Theme.textSecondary
                width: Math.min(implicitWidth, 120)
                anchors.verticalCenter: parent.verticalCenter
            }
            Icon { visible: ht.chevron; size: 9; name: "chevron-down"; color: ht.on ? "white" : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter; rotation: ht.on ? 180 : 0 }
        }
        MouseArea { id: htMouse; anchors.fill: parent; hoverEnabled: true; onClicked: ht.clicked() }
    }

    // Labelled slider module (Display, Sound).
    component SliderModule: Module {
        id: st
        property string label
        property string icon
        property real value
        signal moved(real value)
        width: root.inner
        height: 66
        Label { x: 14; y: 10; text: st.label; font.weight: Font.DemiBold; font.pixelSize: Theme.px(12) }
        CCSlider {
            x: 10; y: 32
            width: parent.width - 20
            height: 24
            icon: st.icon
            value: st.value
            onMoved: v => st.moved(v)
        }
    }
}
