import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import qs.services
import qs.components

// Control Center in the macOS Tahoe style: no container - every control is
// its own floating piece of glass on a 4-column grid. Round buttons turn
// white with a colored glyph when on; sliders are fat glass capsules.
Item {
    id: root

    property point windowOffset
    property size screenSize

    readonly property real unit: 62      // one grid cell
    readonly property real gap: 12
    readonly property real span2: unit * 2 + gap
    readonly property real span4: unit * 4 + gap * 3

    width: span4
    height: col.implicitHeight

    readonly property var player: Mpris.players.values.length ? Mpris.players.values[0] : null
    readonly property var wifiNet: {
        const d = Networking.devices.values.find(d => d.type === DeviceType.Wifi && d.connected);
        return d?.networks.values.find(n => n.connected) ?? null;
    }

    // Tahoe pops controls in with a soft spring from the menu-bar icon.
    transformOrigin: Item.TopRight
    scale: 0.92
    opacity: 0
    Component.onCompleted: { scale = 1; opacity = 1; }
    Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutBack; easing.overshoot: 1.1 } }
    Behavior on opacity { NumberAnimation { duration: Theme.anim } }

    MouseArea { anchors.fill: parent }  // clicks in the gaps don't close it

    Column {
        id: col
        width: parent.width
        spacing: root.gap

        // ---- connectivity circles + Now Playing ----
        Row {
            spacing: root.gap

            Grid {
                columns: 2
                spacing: root.gap
                Round {
                    icon: Networking.wifiEnabled ? "wifi" : "wifi-off"
                    tip: Networking.wifiEnabled ? (root.wifiNet?.name ?? "Wi-Fi: Not Connected") : "Wi-Fi: Off"
                    on: Networking.wifiEnabled
                    onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                }
                Round {
                    icon: "bluetooth"
                    tip: Bluetooth.defaultAdapter ? "Bluetooth" : "Bluetooth: Unavailable"
                    on: Bluetooth.defaultAdapter?.enabled ?? false
                    enabled: Bluetooth.defaultAdapter !== null
                    onClicked: Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                }
                Round {
                    icon: "drop"
                    tip: "Liquid Glass"
                    on: Settings.liquidGlass
                    onClicked: Settings.liquidGlass = !Settings.liquidGlass
                }
                Round {
                    icon: "half-circle"
                    tip: Settings.darkMode ? "Dark Mode" : "Light Mode"
                    on: Settings.darkMode
                    onClicked: Settings.darkMode = !Settings.darkMode
                }
            }

            // Now Playing square
            Tile {
                width: root.span2
                height: root.span2
                radius: 26

                Rectangle {
                    id: art
                    x: 14; y: 14
                    width: 44; height: 44; radius: 10
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
                    x: 14
                    anchors.top: art.bottom
                    anchors.topMargin: 8
                    width: parent.width - 28
                    Label { width: parent.width; text: root.player?.trackTitle || "Not Playing"; font.weight: Font.DemiBold; font.pixelSize: 12 }
                    Label { width: parent.width; text: root.player?.trackArtist ?? ""; color: Theme.textSecondary; font.pixelSize: 11 }
                }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 12
                    spacing: 22
                    Glyph { name: "backward"; onClicked: root.player?.previous() }
                    Glyph { name: root.player?.isPlaying ? "pause" : "play"; onClicked: root.player?.togglePlaying() }
                    Glyph { name: "forward"; onClicked: root.player?.next() }
                }
            }
        }

        // ---- Focus pill + two circles ----
        Row {
            spacing: root.gap

            Tile {
                id: focus
                width: root.span2
                height: root.unit
                radius: height / 2
                active: Settings.doNotDisturb
                Rectangle {
                    id: moon
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 46; height: 46; radius: 23
                    color: Settings.doNotDisturb ? "white" : Theme.controlOff
                    Icon { anchors.centerIn: parent; size: 18; name: "moon"; color: Settings.doNotDisturb ? "#5E5CE6" : Theme.text }
                }
                Column {
                    anchors.left: moon.right
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    Label { text: "Focus"; font.weight: Font.DemiBold; font.pixelSize: 12 }
                    Label { text: Settings.doNotDisturb ? "Do Not Disturb" : "Off"; color: Theme.textSecondary; font.pixelSize: 11 }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.doNotDisturb = !Settings.doNotDisturb }
            }
            Round {
                icon: "eye"
                tip: "Reduce Transparency"
                on: Settings.reduceTransparency
                onClicked: Settings.reduceTransparency = !Settings.reduceTransparency
            }
            Round {
                icon: Capture.recording ? "stop" : "screen-capture"
                tip: Capture.recording ? "Stop Recording" : "Screenshot"
                on: Capture.recording
                onClicked: {
                    Panels.closeAll();
                    if (Capture.recording) Capture.stop();
                    else Panels.screenshotBar = true;
                }
            }
        }

        // ---- sliders ----
        SliderTile {
            visible: Brightness.available
            label: "Display"
            icon: "sun-small"
            value: Brightness.value
            onMoved: v => Brightness.set(v)
            HeaderToggle {
                icon: "nightshift"
                text: "Night Shift"
                on: Displays.nightShiftActive
                onClicked: Settings.nightShiftNow = !Displays.nightShiftActive
            }
        }
        // Without a brightness control, Night Shift still gets a home.
        Tile {
            visible: !Brightness.available
            width: root.span4
            height: 44
            radius: 22
            Label { x: 16; anchors.verticalCenter: parent.verticalCenter; text: "Display"; font.weight: Font.DemiBold; font.pixelSize: 12 }
            HeaderToggle {
                anchors.verticalCenter: parent.verticalCenter
                icon: "nightshift"
                text: "Night Shift"
                on: Displays.nightShiftActive
                onClicked: Settings.nightShiftNow = !Displays.nightShiftActive
            }
        }
        SliderTile {
            id: soundTile
            property bool devicesOpen: false
            label: "Sound"
            icon: Audio.muted ? "speaker-mute" : "speaker"
            value: Audio.muted ? 0 : Audio.volume
            onMoved: v => Audio.setVolume(v)
            height: 74 + (devicesOpen ? deviceList.implicitHeight + 8 : 0)
            Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }
            HeaderToggle {
                visible: Audio.sinks.length > 0
                icon: Audio.deviceIcon(Audio.sink)
                text: Audio.sinks.length > 1 ? "Output" : Audio.deviceName(Audio.sink)
                chevron: true
                on: soundTile.devicesOpen
                onClicked: soundTile.devicesOpen = !soundTile.devicesOpen
            }
            Column {
                id: deviceList
                visible: soundTile.devicesOpen
                x: 12
                y: 74
                width: parent.width - 24
                Repeater {
                    model: Audio.sinks
                    Rectangle {
                        id: dev
                        required property var modelData
                        readonly property bool current: Audio.sink === modelData
                        width: deviceList.width
                        height: 32
                        radius: 10
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
                            font.pixelSize: 12
                        }
                        MouseArea { id: devMouse; anchors.fill: parent; hoverEnabled: true; onClicked: Audio.setSink(dev.modelData) }
                    }
                }
            }
        }
    }

    // ================= pieces =================

    // A floating glass tile.
    component Tile: Item {
        id: tile
        property real radius: 22
        property bool active: false
        default property alias content: inner.data
        Glass {
            anchors.fill: parent
            radius: tile.radius
            screenSize: root.screenSize
            windowOffset: root.windowOffset
            rimOpacity: 0.55
            bezel: Math.min(16, tile.height * 0.3)
            refraction: 12
            shadowStrength: 0.6
        }
        Item { id: inner; anchors.fill: parent }
    }

    // Round toggle: glass when off, solid white with a colored glyph when on.
    component Round: Item {
        id: rb
        property string icon
        property string tip
        property bool on: false
        signal clicked()
        width: root.unit
        height: root.unit
        opacity: enabled ? 1 : 0.45

        Tile {
            anchors.fill: parent
            radius: width / 2
            visible: !rb.on
        }
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            visible: rb.on
            color: "white"
            Rectangle {   // soft drop under the white puck
                z: -1
                anchors.fill: parent
                anchors.topMargin: 3
                radius: width / 2
                color: Qt.rgba(0, 0, 0, 0.12)
            }
        }
        Icon {
            anchors.centerIn: parent
            size: 22
            name: rb.icon
            color: rb.on ? Theme.accent : Theme.text
        }
        scale: tap.pressed ? 0.92 : (tap.containsMouse ? 1.04 : 1.0)
        Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutBack } }

        Rectangle {
            visible: tap.containsMouse && rb.tip !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 4
            z: 10
            width: tipLabel.implicitWidth + 16
            height: 22
            radius: 11
            color: Theme.glassStrong
            Label { id: tipLabel; anchors.centerIn: parent; text: rb.tip; font.pixelSize: 11 }
        }
        MouseArea {
            id: tap
            anchors.fill: parent
            hoverEnabled: true
            enabled: rb.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: rb.clicked()
        }
    }

    component Glyph: Item {
        id: g
        property string name
        signal clicked()
        width: 18; height: 18
        Icon { anchors.centerIn: parent; size: 16; name: g.name; color: Theme.text }
        MouseArea { anchors.fill: parent; anchors.margins: -8; onClicked: g.clicked() }
    }

    // Small pill at the top right of a slider tile (Night Shift, output device).
    component HeaderToggle: Rectangle {
        id: ht
        property string icon
        property string text
        property bool on: false
        property bool chevron: false
        signal clicked()
        anchors.right: parent?.right
        anchors.rightMargin: 12
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
                font.pixelSize: 11
                color: ht.on ? "white" : Theme.textSecondary
                width: Math.min(implicitWidth, 120)
                anchors.verticalCenter: parent.verticalCenter
            }
            Icon { visible: ht.chevron; size: 9; name: "chevron-down"; color: ht.on ? "white" : Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter; rotation: ht.on ? 180 : 0 }
        }
        MouseArea { id: htMouse; anchors.fill: parent; hoverEnabled: true; onClicked: ht.clicked() }
    }

    // Labelled capsule slider (Display, Sound).
    component SliderTile: Tile {
        id: st
        property string label
        property string icon
        property real value
        signal moved(real value)
        width: root.span4
        height: 74
        radius: 26
        Label { x: 16; y: 10; text: st.label; font.weight: Font.DemiBold; font.pixelSize: 12 }
        CCSlider {
            x: 12; y: 32
            width: parent.width - 24
            height: 30
            icon: st.icon
            value: st.value
            onMoved: v => st.moved(v)
        }
    }
}
