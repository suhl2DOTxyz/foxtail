import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.services
import qs.components

// System Settings, modelled on macOS Ventura+: translucent sidebar with a
// search field and user card, panes of inset-grouped rows on the right.
FloatingWindow {
    id: win

    title: "System Settings"
    visible: Panels.settings
    onVisibleChanged: if (!visible) Panels.settings = false
    implicitWidth: 760
    implicitHeight: 620
    minimumSize: Qt.size(680, 480)
    color: "transparent"

    readonly property var panes: [
        { id: "wifi", name: "Wi-Fi", icon: "wifi", color: "#0A84FF" },
        { id: "bluetooth", name: "Bluetooth", icon: "bluetooth", color: "#0A84FF" },
        { id: "sep" },
        { id: "general", name: "General", icon: "gear", color: "#8E8E93" },
        { id: "updates", name: "Software Update", icon: "restart", color: "#8E8E93" },
        { id: "appearance", name: "Appearance", icon: "half-circle", color: "#1C1C1E" },
        { id: "desktop", name: "Desktop & Dock", icon: "dock", color: "#1C1C1E" },
        { id: "displays", name: "Displays", icon: "sun", color: "#0A84FF" },
        { id: "battery", name: "Battery", icon: "battery", color: "#30D158" },
        { id: "wallpaper", name: "Wallpaper", icon: "photo", color: "#30B0C7" },
        { id: "sep" },
        { id: "notifications", name: "Notifications", icon: "bell", color: "#FF3B30" },
        { id: "sound", name: "Sound", icon: "speaker", color: "#FF2D55" },
        { id: "focus", name: "Focus", icon: "moon", color: "#5E5CE6" },
        { id: "sep" },
        { id: "lock", name: "Lock Screen", icon: "lock", color: "#1C1C1E" },
        { id: "keyboard", name: "Keyboard", icon: "keyboard", color: "#8E8E93" }
    ]
    property string filter: ""

    function startMove() {
        try { win._backingWindow.startSystemMove(); } catch (e) {}
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.windowRadius
        color: Theme.dark ? "#1E1E1F" : "#FFFFFF"
        border.color: Theme.glassOutline
    }

    // ---------------- sidebar ----------------
    Item {
        id: sidebar
        width: 220
        height: parent.height

        // Tahoe: the sidebar is its own floating glass card inside the window.
        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.liquid ? 8 : 0
            radius: Theme.liquid ? 20 : 12
            color: Theme.dark ? Qt.rgba(1, 1, 1, Theme.liquid ? 0.07 : 0.05) : Qt.rgba(0, 0, 0, Theme.liquid ? 0.045 : 0.035)
            border.color: Theme.liquid ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.10) : Qt.rgba(1, 1, 1, 0.9)) : "transparent"
            Rectangle {   // soft lift
                visible: Theme.liquid
                z: -1
                anchors.fill: parent
                anchors.topMargin: 2
                radius: parent.radius
                color: Qt.rgba(0, 0, 0, Theme.dark ? 0.25 : 0.05)
            }
        }

        MouseArea { anchors.fill: parent; onPressed: win.startMove() }

        TrafficLights {
            x: Theme.liquid ? 22 : 18
            y: Theme.liquid ? 22 : 18
            onClose: Panels.settings = false
            onMinimize: Panels.settings = false
            onZoom: Hypr.dispatch("hl.dsp.window.fullscreen({ mode = \"maximized\" })")
        }

        // Search
        Rectangle {
            id: searchBox
            x: 14; y: 52
            width: parent.width - 28
            height: 30
            radius: Theme.liquid ? 15 : 7
            color: Theme.control
            Icon { id: sicon; x: 8; anchors.verticalCenter: parent.verticalCenter; size: 12; name: "search"; color: Theme.textSecondary }
            TextInput {
                id: searchInput
                anchors.left: sicon.right; anchors.leftMargin: 6
                anchors.right: parent.right; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
                font.family: Theme.font
                font.pixelSize: 13
                clip: true
                onTextChanged: win.filter = text.toLowerCase()
                Label { visible: !searchInput.text; text: "Search"; color: Theme.textTertiary }
            }
        }

        Flickable {
            anchors.top: searchBox.bottom
            anchors.topMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            width: parent.width
            contentHeight: sideCol.implicitHeight
            clip: true

            Column {
                id: sideCol
                width: parent.width

                // User card
                Item {
                    width: parent.width
                    height: 58
                    Rectangle {
                        id: avatar
                        x: 20
                        anchors.verticalCenter: parent.verticalCenter
                        width: 38; height: 38; radius: 19
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#FFB15C" }
                            GradientStop { position: 1; color: "#E5400A" }
                        }
                        Label {
                            anchors.centerIn: parent
                            text: (SystemInfo.fullName || SystemInfo.user || "?").charAt(0).toUpperCase()
                            color: "white"
                            font.pixelSize: 17
                            font.weight: Font.DemiBold
                        }
                    }
                    Column {
                        anchors.left: avatar.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        Label { text: SystemInfo.fullName || SystemInfo.user; font.weight: Font.DemiBold }
                        Label { text: "Foxtail Account"; font.pixelSize: 11; color: Theme.textSecondary }
                    }
                }

                Repeater {
                    model: win.panes.filter(p => p.id === "sep" ? !win.filter : p.name.toLowerCase().indexOf(win.filter) >= 0)

                    Item {
                        id: navItem
                        required property var modelData
                        width: sideCol.width
                        height: modelData.id === "sep" ? 12 : 30
                        readonly property bool selected: Panels.settingsPane === modelData.id

                        Rectangle {
                            visible: navItem.modelData.id !== "sep"
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            radius: Theme.liquid ? height / 2 : 6
                            color: navItem.selected
                                ? (Theme.liquid ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)) : Theme.accent)
                                : (navMouse.containsMouse ? Theme.hover : "transparent")
                        }

                        Rectangle {
                            id: badge
                            visible: navItem.modelData.id !== "sep"
                            x: 18
                            anchors.verticalCenter: parent.verticalCenter
                            width: 20; height: 20; radius: 5
                            color: navItem.modelData.color ?? "#888"
                            Icon { anchors.centerIn: parent; size: 13; name: navItem.modelData.icon ?? ""; color: "white" }
                        }
                        Label {
                            visible: navItem.modelData.id !== "sep"
                            anchors.left: badge.right
                            anchors.leftMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: navItem.modelData.name ?? ""
                            color: navItem.selected && !Theme.liquid ? "white" : Theme.text
                            font.weight: navItem.selected && Theme.liquid ? Font.DemiBold : Font.Normal
                        }
                        MouseArea {
                            id: navMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: navItem.modelData.id !== "sep"
                            onClicked: Panels.settingsPane = navItem.modelData.id
                        }
                    }
                }
            }
        }
    }

    // ---------------- content ----------------
    Item {
        id: content
        anchors.left: sidebar.right
        anchors.right: parent.right
        height: parent.height

        Item {
            id: header
            width: parent.width
            height: 52
            MouseArea { anchors.fill: parent; onPressed: win.startMove() }
            Row {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 64; height: 30
                    radius: Theme.liquid ? 15 : 7
                    color: Theme.liquid ? Theme.control : "transparent"
                    border.color: Theme.liquid ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.9)) : "transparent"
                    Row {
                        anchors.centerIn: parent
                        spacing: 14
                        Icon { size: 14; name: "chevron-left"; color: Theme.textTertiary }
                        Icon { size: 14; name: "chevron-right"; color: Theme.textTertiary }
                    }
                }
                Label {
                    text: (win.panes.find(p => p.id === Panels.settingsPane) ?? {}).name ?? ""
                    font.pixelSize: 15
                    font.weight: Font.Bold
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        Flickable {
            anchors.top: header.bottom
            anchors.bottom: parent.bottom
            width: parent.width
            contentHeight: paneLoader.height + 30
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Loader {
                id: paneLoader
                x: 24
                width: parent.width - 48
                sourceComponent: {
                    switch (Panels.settingsPane) {
                    case "wifi": return wifiPane;
                    case "bluetooth": return btPane;
                    case "general": return generalPane;
                    case "battery": return batteryPane;
                    case "updates": return updatesPane;
                    case "appearance": return appearancePane;
                    case "desktop": return dockPane;
                    case "displays": return displaysPane;
                    case "wallpaper": return wallpaperPane;
                    case "notifications": return notificationsPane;
                    case "sound": return soundPane;
                    case "focus": return focusPane;
                    case "lock": return lockPane;
                    case "keyboard": return keyboardPane;
                    }
                    return generalPane;
                }
            }
        }
    }

    // ================= building blocks =================
    component Group: Rectangle {
        default property alias rows: groupCol.data
        width: parent?.width ?? 0
        height: groupCol.implicitHeight
        radius: Theme.liquid ? 18 : 9
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.05) : Qt.rgba(0, 0, 0, 0.03)
        border.color: Theme.separator
        Column { id: groupCol; width: parent.width }
    }

    component SettingRow: Item {
        id: sr
        property string label
        property string sub: ""
        property bool last: false
        default property alias control: ctl.data
        width: parent?.width ?? 0
        height: sub ? 52 : 40
        Column {
            x: 14
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - ctl.width - 40
            Label { width: parent.width; text: sr.label }
            Label { visible: sr.sub !== ""; width: parent.width; text: sr.sub; font.pixelSize: 11; color: Theme.textSecondary; wrapMode: Text.Wrap; elide: Text.ElideNone }
        }
        Item {
            id: ctl
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
        Rectangle {
            visible: !sr.last
            anchors.bottom: parent.bottom
            x: 14
            width: parent.width - 28
            height: 1
            color: Theme.separator
        }
    }

    component SectionTitle: Label {
        font.weight: Font.Bold
        topPadding: 8
    }

    component PlainSlider: Item {
        id: ps
        property real value: 0.5
        property real from: 0
        property real to: 1
        signal moved(real value)
        width: 200
        height: 20
        readonly property real t: (value - from) / (to - from)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width; height: 4; radius: 2
            color: Theme.controlOff
            Rectangle { width: parent.width * ps.t; height: parent.height; radius: 2; color: Theme.accent }
        }
        Rectangle {
            x: ps.t * (parent.width - width)
            anchors.verticalCenter: parent.verticalCenter
            width: 20; height: 20; radius: 10
            color: "white"
            border.color: Qt.rgba(0, 0, 0, 0.15)
        }
        MouseArea {
            anchors.fill: parent
            function upd(mx) {
                const v = ps.from + Math.max(0, Math.min(1, mx / width)) * (ps.to - ps.from);
                ps.value = v;
                ps.moved(v);
            }
            onPressed: m => upd(m.x)
            onPositionChanged: m => { if (pressed) upd(m.x); }
        }
    }

    // Compact segmented picker: click cycles through the options.
    component Choice: Rectangle {
        id: ch
        property var options: []
        property var value
        signal picked(var value)
        readonly property int idx: Math.max(0, options.findIndex(o => o[0] === value))
        width: chl.implicitWidth + 34
        height: 24
        radius: Theme.liquid ? 12 : 6
        color: Theme.control
        border.color: Theme.separator
        Label { id: chl; x: 12; anchors.verticalCenter: parent.verticalCenter; text: ch.options[ch.idx]?.[1] ?? ""; font.pixelSize: 12 }
        Icon { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; size: 10; name: "chevron-down"; color: Theme.textSecondary }
        MouseArea { anchors.fill: parent; onClicked: ch.picked(ch.options[(ch.idx + 1) % ch.options.length][0]) }
    }

    component PushButton: Rectangle {
        id: pb
        property string text
        signal clicked()
        width: pbl.implicitWidth + 24
        height: 24
        radius: Theme.liquid ? 12 : 6
        color: pbm.pressed ? Theme.pressed : Theme.control
        border.color: Theme.separator
        Label { id: pbl; anchors.centerIn: parent; text: pb.text; font.pixelSize: 12 }
        MouseArea { id: pbm; anchors.fill: parent; onClicked: pb.clicked() }
    }

    // ================= panes =================
    Component {
        id: generalPane
        Column {
            spacing: 18
            Item {
                width: parent.width
                height: 250
                Column {
                    anchors.centerIn: parent
                    spacing: 6
                    Image {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 128; height: 128
                        sourceSize: Qt.size(256, 256)
                        source: Qt.resolvedUrl("../icons/foxtail-logo.png")
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Foxtail"
                        font.pixelSize: 30
                        font.weight: Font.Bold
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: `Version ${SystemInfo.version} “${SystemInfo.codename}”`
                        color: Theme.textSecondary
                    }
                }
            }
            Group {
                SettingRow { label: "Name"; Label { text: SystemInfo.hostname; color: Theme.textSecondary } }
                SettingRow { label: "Chip"; Label { text: SystemInfo.cpu; color: Theme.textSecondary; width: 300; horizontalAlignment: Text.AlignRight } }
                SettingRow { label: "Graphics"; Label { text: SystemInfo.gpu; color: Theme.textSecondary; width: 300; horizontalAlignment: Text.AlignRight } }
                SettingRow { label: "Memory"; Label { text: SystemInfo.memory; color: Theme.textSecondary } }
                SettingRow { label: "Storage"; Label { text: SystemInfo.disk; color: Theme.textSecondary } }
                SettingRow { label: "Kernel"; last: true; Label { text: "Linux " + SystemInfo.kernel; color: Theme.textSecondary } }
            }
        }
    }

    Component {
        id: batteryPane
        Column {
            spacing: 14
            Group {
                visible: Power.hasBattery
                Item {
                    width: parent.width
                    height: 84
                    Column {
                        x: 18
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4
                        Label { text: Power.percent + "%"; font.pixelSize: 26; font.weight: Font.DemiBold }
                        Label {
                            text: Power.source + (Power.timeLeft ? " · " + Power.timeLeft : "")
                            color: Theme.textSecondary
                            font.pixelSize: 12
                        }
                    }
                    Rectangle {   // big battery gauge
                        anchors.right: parent.right
                        anchors.rightMargin: 22
                        anchors.verticalCenter: parent.verticalCenter
                        width: 120; height: 44; radius: 10
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.textSecondary
                        Rectangle {
                            x: 5; y: 5
                            height: parent.height - 10
                            width: (parent.width - 10) * Power.percent / 100
                            radius: 6
                            color: Power.mode === "power-saver" ? "#FFD60A" : Power.percent < 20 && !Power.charging ? "#FF453A" : "#30D158"
                        }
                    }
                }
            }
            Label {
                visible: !Power.hasBattery
                text: "This computer doesn't have a battery."
                color: Theme.textSecondary
            }

            SectionTitle { text: "Power Mode" }
            Group {
                Repeater {
                    model: [
                        { id: "power-saver", name: "Low Power", sub: "Reduces energy use for longer battery life. The display and apps may be a little slower." },
                        { id: "balanced", name: "Balanced", sub: "Good performance with sensible energy use." },
                        { id: "performance", name: "High Performance", sub: "Maximum speed. Uses more energy and may make fans louder." }
                    ]
                    SettingRow {
                        required property var modelData
                        required property int index
                        visible: modelData.id !== "performance" || Power.hasPerformance
                        label: modelData.name
                        sub: modelData.sub
                        last: index === 2 || (index === 1 && !Power.hasPerformance)
                        Rectangle {
                            width: 20; height: 20; radius: 10
                            color: Power.mode === modelData.id ? Theme.accent : "transparent"
                            border.width: Power.mode === modelData.id ? 0 : 1.5
                            border.color: Theme.textTertiary
                            Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: "white"; visible: Power.mode === modelData.id }
                            MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: Power.setMode(modelData.id) }
                        }
                    }
                }
            }

            Group {
                visible: Power.hasBattery
                SettingRow {
                    label: "Show battery percentage in menu bar"
                    Switch { checked: Settings.showBatteryPercent; onToggled: c => Settings.showBatteryPercent = c }
                }
                SettingRow {
                    label: "Switch to Low Power at 10%"
                    sub: "You'll also get a warning at 20%, 10% and 5%."
                    last: true
                    Switch { checked: Settings.autoLowPower; onToggled: c => Settings.autoLowPower = c }
                }
            }
        }
    }

    Component {
        id: updatesPane
        Column {
            id: upd
            spacing: 14
            Component.onCompleted: { if (!Updates.lastChecked.getTime || isNaN(Updates.lastChecked.getTime())) Updates.check(); Updates.refreshSnapshots(); }
            property int confirmRestore: -1

            Group {
                Item {
                    width: parent.width
                    height: 96
                    Image {
                        id: updLogo
                        x: 18
                        anchors.verticalCenter: parent.verticalCenter
                        width: 56; height: 56
                        sourceSize: Qt.size(112, 112)
                        source: Qt.resolvedUrl("../icons/foxtail-logo.png")
                        RotationAnimation on rotation {
                            running: Updates.installing || Updates.checking
                            from: 0; to: 360; duration: 2400; loops: Animation.Infinite
                            onStopped: updLogo.rotation = 0
                        }
                    }
                    Column {
                        anchors.left: updLogo.right
                        anchors.leftMargin: 14
                        anchors.right: updButton.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 3
                        Label {
                            width: parent.width
                            font.pixelSize: 15
                            font.weight: Font.DemiBold
                            text: Updates.installing ? "Installing updates…"
                                : Updates.checking ? "Checking for updates…"
                                : Updates.count === 1 ? "1 update available"
                                : Updates.count > 1 ? `${Updates.count} updates available`
                                : "Foxtail is up to date"
                        }
                        Label {
                            width: parent.width
                            font.pixelSize: 12
                            color: Theme.textSecondary
                            text: Updates.installing
                                ? (Updates.stage === "apps" ? "Updating apps…" : "Updating Foxtail and system software. A snapshot is taken first.")
                                : `Foxtail ${SystemInfo.version}` + (Updates.lastChecked.getTime && !isNaN(Updates.lastChecked.getTime())
                                    ? ` · Checked ${Qt.formatTime(Updates.lastChecked, "h:mm AP")}` : "")
                        }
                    }
                    PushButton {
                        id: updButton
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !Updates.installing && !Updates.checking
                        text: Updates.count ? "Update Now" : "Check Now"
                        onClicked: Updates.count ? Updates.install() : Updates.check()
                    }
                }
            }

            Label {
                visible: Updates.error !== ""
                width: parent.width
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                text: Updates.error
                color: "#FF453A"
                font.pixelSize: 12
            }

            Group {
                visible: !Updates.installing && (Updates.needsRestart || Updates.needsRelogin)
                SettingRow {
                    label: Updates.needsRestart ? "Restart to finish updating" : "Log out to finish updating"
                    sub: Updates.needsRestart ? "A new system kernel was installed." : "A new version of the Foxtail desktop was installed."
                    last: true
                    PushButton {
                        text: Updates.needsRestart ? "Restart…" : "Log Out…"
                        onClicked: Panels.confirm = Updates.needsRestart ? "restart" : "logout"
                    }
                }
            }

            Group {
                visible: Updates.count > 0 && !Updates.installing
                Repeater {
                    model: Updates.available.slice(0, 12)
                    SettingRow {
                        required property var modelData
                        required property int index
                        label: modelData.name
                        sub: modelData.kind === "app" ? "App" : (modelData.from ? `${modelData.from} → ${modelData.to}` : modelData.to)
                        last: index === Math.min(Updates.count, 12) - 1
                    }
                }
            }
            Label {
                visible: Updates.count > 12 && !Updates.installing
                text: `and ${Updates.count - 12} more`
                color: Theme.textSecondary
                font.pixelSize: 12
            }

            Group {
                SettingRow {
                    label: "Check for updates automatically"
                    sub: "You'll get a notification when updates are ready. Nothing installs without you."
                    last: true
                    Switch { checked: Settings.autoCheckUpdates; onToggled: c => Settings.autoCheckUpdates = c }
                }
            }

            SectionTitle { text: "Restore an earlier version" }
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                font.pixelSize: 12
                color: Theme.textSecondary
                text: "Foxtail saves a snapshot of the system before and after every update. Restoring one rolls back apps and system settings; your files and personal settings stay as they are. You can also pick a snapshot by holding Esc while your computer starts."
            }
            Group {
                visible: Updates.snapshots.length > 0
                Repeater {
                    model: Updates.snapshots.slice(0, 8)
                    SettingRow {
                        required property var modelData
                        required property int index
                        label: modelData.description || ("Snapshot " + modelData.number)
                        sub: modelData.date
                        last: index === Math.min(Updates.snapshots.length, 8) - 1
                        PushButton {
                            text: upd.confirmRestore === modelData.number ? "Click to confirm" : "Restore…"
                            onClicked: {
                                if (upd.confirmRestore === modelData.number) {
                                    upd.confirmRestore = -1;
                                    Updates.restore(modelData.number);
                                } else {
                                    upd.confirmRestore = modelData.number;
                                }
                            }
                        }
                    }
                }
            }
            Label {
                visible: Updates.snapshots.length === 0
                text: "No snapshots yet."
                color: Theme.textSecondary
                font.pixelSize: 12
            }
            Connections {
                target: Updates
                function onRestored() { Panels.confirm = "restart"; }
            }
        }
    }

    Component {
        id: appearancePane
        Column {
            spacing: 14
            Group {
                Item {
                    width: parent.width
                    height: 112
                    Label { x: 14; y: 14; text: "Appearance" }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        y: 12
                        spacing: 16
                        Repeater {
                            model: [{ n: "Light", d: false }, { n: "Dark", d: true }]
                            Column {
                                required property var modelData
                                spacing: 6
                                Rectangle {
                                    width: 84; height: 56; radius: 8
                                    border.width: Settings.darkMode === modelData.d ? 3 : 1
                                    border.color: Settings.darkMode === modelData.d ? Theme.accent : Theme.separator
                                    clip: true
                                    Image {
                                        anchors.fill: parent; anchors.margins: 3
                                        source: "file://" + Settings.wallpaper
                                        sourceSize: Qt.size(160, 100)
                                        fillMode: Image.PreserveAspectCrop
                                    }
                                    Rectangle {
                                        x: 14; y: 14; width: 56; height: 34; radius: 4
                                        color: modelData.d ? "#2A2A2C" : "#F5F5F7"
                                        Rectangle { x: 0; y: 0; width: parent.width; height: 6; radius: 3; color: modelData.d ? "#3A3A3C" : "#E5E5EA" }
                                        Rectangle { x: 6; y: 12; width: 26; height: 4; radius: 2; color: Theme.accent }
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: Settings.darkMode = modelData.d }
                                }
                                Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.n; font.pixelSize: 11 }
                            }
                        }
                    }
                }
            }

            Group {
                SettingRow {
                    label: "Liquid Glass"
                    sub: "Clear, refractive glass for the menu bar, Dock, menus and Control Center. Turn off for classic frosted translucency."
                    Switch { checked: Settings.liquidGlass; onToggled: c => Settings.liquidGlass = c }
                }
                SettingRow {
                    label: "Refract windows behind glass"
                    sub: "Menus and Control Center bend what's actually behind them, not just the wallpaper."
                    Switch {
                        checked: Settings.refractWindows
                        opacity: Settings.liquidGlass ? 1 : 0.4
                        onToggled: c => Settings.refractWindows = c
                    }
                }
                SettingRow {
                    label: "Reduce transparency"
                    Switch { checked: Settings.reduceTransparency; onToggled: c => Settings.reduceTransparency = c }
                }
                SettingRow {
                    label: "Accent color"
                    last: true
                    Row {
                        spacing: 8
                        Repeater {
                            model: ["#FF7A1A", "#FF3B30", "#FF2D55", "#AF52DE", "#007AFF", "#34C759", "#FFCC00", "#8E8E93"]
                            Rectangle {
                                required property string modelData
                                width: 18; height: 18; radius: 9
                                color: modelData
                                border.width: Settings.accent.toUpperCase() === modelData ? 2 : 0
                                border.color: Theme.dark ? "white" : "#555"
                                MouseArea { anchors.fill: parent; onClicked: Settings.accent = parent.modelData }
                            }
                        }
                    }
                }
            }

            Group {
                SettingRow {
                    label: "Use 24-hour time"
                    Switch { checked: Settings.clock24h; onToggled: c => Settings.clock24h = c }
                }
                SettingRow {
                    label: "Show seconds in menu bar"
                    last: true
                    Switch { checked: Settings.clockSeconds; onToggled: c => Settings.clockSeconds = c }
                }
            }
        }
    }

    Component {
        id: dockPane
        Column {
            spacing: 14
            SectionTitle { text: "Dock" }
            Group {
                SettingRow {
                    label: "Size"
                    PlainSlider { from: 36; to: 80; value: Settings.dockIconSize; onMoved: v => Settings.dockIconSize = Math.round(v) }
                }
                SettingRow {
                    label: "Magnification"
                    Row {
                        spacing: 12
                        PlainSlider {
                            width: 150
                            anchors.verticalCenter: parent.verticalCenter
                            from: 1.1; to: 2.2
                            value: Settings.dockMagnifySize
                            opacity: Settings.dockMagnification ? 1 : 0.4
                            onMoved: v => Settings.dockMagnifySize = v
                        }
                        Switch { checked: Settings.dockMagnification; onToggled: c => Settings.dockMagnification = c }
                    }
                }
                SettingRow {
                    label: "Automatically hide and show the Dock"
                    last: true
                    Switch { checked: Settings.dockAutoHide; onToggled: c => Settings.dockAutoHide = c }
                }
            }
            SectionTitle { text: "Windows" }
            Group {
                SettingRow {
                    label: "New windows float, like macOS"
                    sub: "Turn off for tiling: windows arrange themselves side by side."
                    last: true
                    Switch {
                        checked: true
                        onToggled: c => Quickshell.execDetached(["foxtail-window-mode", c ? "float" : "tile"])
                    }
                }
            }
        }
    }

    Component {
        id: wallpaperPane
        Column {
            spacing: 14
            Process {
                id: lister
                running: true
                command: ["sh", "-c", `ls -1 ${Settings.wallpaperDir}/*.jpg ${Settings.wallpaperDir}/*.png $HOME/Pictures/Wallpapers/* 2>/dev/null`]
                stdout: StdioCollector { onStreamFinished: grid.files = text.trim().split("\n").filter(f => f) }
            }
            Rectangle {
                width: parent.width
                height: width * 0.42
                radius: 12
                clip: true
                color: "black"
                Image {
                    anchors.fill: parent
                    source: "file://" + Settings.wallpaper
                    sourceSize: Qt.size(800, 400)
                    fillMode: Image.PreserveAspectCrop
                }
            }
            SectionTitle { text: "Foxtail Wallpapers" }
            Flow {
                id: grid
                property var files: []
                width: parent.width
                spacing: 12
                Repeater {
                    model: grid.files
                    Rectangle {
                        required property string modelData
                        width: (grid.width - 36) / 4
                        height: width * 0.62
                        radius: 8
                        color: "transparent"
                        border.width: Settings.wallpaper === modelData ? 3 : 0
                        border.color: Theme.accent
                        Image {
                            anchors.fill: parent
                            anchors.margins: 3
                            source: "file://" + parent.modelData
                            sourceSize: Qt.size(240, 150)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        MouseArea { anchors.fill: parent; onClicked: Settings.wallpaper = parent.modelData }
                    }
                }
            }
        }
    }

    Component {
        id: wifiPane
        Column {
            id: wifiCol
            spacing: 14
            readonly property var dev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
            Component.onCompleted: if (dev) dev.scannerEnabled = true
            Group {
                SettingRow {
                    label: "Wi-Fi"
                    last: true
                    Switch { checked: Networking.wifiEnabled; onToggled: c => Networking.wifiEnabled = c }
                }
            }
            SectionTitle { text: wifiCol.dev ? "Networks" : "No Wi-Fi adapter found" }
            Group {
                visible: wifiCol.dev !== null && Networking.wifiEnabled
                Repeater {
                    model: (wifiCol.dev?.networks.values ?? []).filter(n => n.name)
                    SettingRow {
                        required property var modelData
                        label: modelData.name
                        sub: modelData.connected ? "Connected" : (modelData.known ? "Known network" : "")
                        PushButton {
                            text: modelData.connected ? "Disconnect" : "Connect"
                            onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                        }
                    }
                }
            }
            SectionTitle { text: "Wired" }
            Group {
                Repeater {
                    model: Networking.devices.values.filter(d => d.type === DeviceType.Wired)
                    SettingRow {
                        required property var modelData
                        label: modelData.name
                        sub: modelData.connected ? "Connected" : "Not connected"
                        last: true
                        Rectangle { width: 10; height: 10; radius: 5; color: modelData.connected ? "#34C759" : "#8E8E93" }
                    }
                }
            }
        }
    }

    Component {
        id: btPane
        Column {
            id: btCol
            spacing: 14
            readonly property var adapter: Bluetooth.defaultAdapter
            Group {
                SettingRow {
                    label: "Bluetooth"
                    sub: btCol.adapter ? "" : "No Bluetooth adapter found"
                    last: true
                    Switch {
                        checked: Bluetooth.defaultAdapter?.enabled ?? false
                        onToggled: c => { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = c; }
                    }
                }
            }
            SectionTitle { text: "Devices"; visible: btCol.adapter?.enabled ?? false }
            Group {
                visible: btCol.adapter?.enabled ?? false
                Repeater {
                    model: Bluetooth.devices.values.filter(d => d.name)
                    SettingRow {
                        required property var modelData
                        label: modelData.name
                        sub: modelData.connected ? "Connected" : (modelData.paired ? "Not connected" : "")
                        PushButton {
                            text: modelData.connected ? "Disconnect" : (modelData.paired ? "Connect" : "Pair")
                            onClicked: modelData.connected ? modelData.disconnect() : (modelData.paired ? modelData.connect() : modelData.pair())
                        }
                    }
                }
            }
        }
    }

    Component {
        id: displaysPane
        Column {
            spacing: 14
            Group {
                SettingRow {
                    label: "Brightness"
                    sub: Brightness.available ? "" : "This display doesn't support brightness control"
                    last: true
                    PlainSlider { enabled: Brightness.available; value: Brightness.value; onMoved: v => Brightness.set(v) }
                }
            }
        }
    }

    Component {
        id: soundPane
        Column {
            spacing: 14
            SectionTitle { text: "Output" }
            Group {
                SettingRow {
                    label: "Output volume"
                    PlainSlider { value: Audio.volume; onMoved: v => Audio.setVolume(v) }
                }
                SettingRow {
                    label: "Mute"
                    last: true
                    Switch { checked: Audio.muted; onToggled: Audio.toggleMute() }
                }
            }
            Label {
                text: "Output device: " + (Audio.sink?.description ?? "None")
                color: Theme.textSecondary
                font.pixelSize: 12
            }
        }
    }

    Component {
        id: notificationsPane
        Column {
            spacing: 14
            Group {
                SettingRow {
                    label: "Show notification banners"
                    sub: "Banners appear in the top-right corner and go away automatically."
                    last: true
                    Switch { checked: !Settings.doNotDisturb; onToggled: c => Settings.doNotDisturb = !c }
                }
            }
            PushButton { text: "Clear Notification History"; onClicked: Notifs.clearAll() }
        }
    }

    Component {
        id: focusPane
        Column {
            spacing: 14
            Group {
                SettingRow {
                    label: "Do Not Disturb"
                    sub: "Silences notification banners. Critical alerts still come through."
                    last: true
                    Switch { checked: Settings.doNotDisturb; onToggled: c => Settings.doNotDisturb = c }
                }
            }
        }
    }

    Component {
        id: lockPane
        Column {
            spacing: 14
            Group {
                SettingRow {
                    label: "Require password after the screen is idle for"
                    Choice {
                        options: [[1, "1 minute"], [5, "5 minutes"], [15, "15 minutes"], [60, "1 hour"], [0, "Never"]]
                        value: Settings.lockAfter
                        onPicked: v => Settings.lockAfter = v
                    }
                }
                SettingRow {
                    label: "Turn display off when inactive for"
                    Choice {
                        options: [[2, "2 minutes"], [10, "10 minutes"], [30, "30 minutes"], [0, "Never"]]
                        value: Settings.displayOffAfter
                        onPicked: v => Settings.displayOffAfter = v
                    }
                }
                SettingRow {
                    label: "Lock Screen now"
                    last: true
                    PushButton { text: "Lock"; onClicked: { Panels.settings = false; Lock.lock(); } }
                }
            }
        }
    }

    Component {
        id: keyboardPane
        Column {
            spacing: 14
            SectionTitle { text: "Keyboard Shortcuts" }
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                text: "The Super (⊞) key is ⌘ Command, Ctrl is ⌃ Control, Alt is ⌥ Option. ⌘ shortcuts work in every app, and in terminals ⌘C copies instead of interrupting."
                color: Theme.textSecondary
                font.pixelSize: 12
            }
            Group {
                Repeater {
                    model: [
                        ["Copy, Paste, Cut, Undo, Select All", "⌘C  ⌘V  ⌘X  ⌘Z  ⌘A"],
                        ["Quit app (all its windows)", "⌘Q"],
                        ["Close tab or window", "⌘W"],
                        ["Hide / Minimize", "⌘H  /  ⌘M"],
                        ["Spotlight", "⌘ Space"],
                        ["Switch app windows", "⌘ Tab"],
                        ["Line start / end, word jump", "⌘← ⌘→  /  ⌥← ⌥→"],
                        ["Back / Forward", "⌘[  /  ⌘]"],
                        ["Full screen", "⌃⌘F"],
                        ["Switch desktop", "⌃1 … 9  /  ⌃⌘← →"],
                        ["Move window to desktop", "⌃⇧1 … 9"],
                        ["Launchpad", "F4  /  ⌥⌘L"],
                        ["Control Center", "⌥⌘C"],
                        ["Files  /  Terminal", "⌥⌘Space  /  ⌥⌘Return"],
                        ["Lock screen", "⌃⌘Q"],
                        ["Force Quit", "⌥⌘⎋"],
                        ["Screenshot (screen / area / window)", "⇧⌘3  ⇧⌘4  ⇧⌘5"]
                    ]
                    SettingRow {
                        required property var modelData
                        required property int index
                        label: modelData[0]
                        last: index === 16
                        Label { text: modelData[1]; color: Theme.textSecondary; font.family: Theme.font }
                    }
                }
            }
        }
    }
}
