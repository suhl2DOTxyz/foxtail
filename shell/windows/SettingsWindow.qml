import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.services
import qs.components
import qs.settings

// System Settings, modelled on macOS Ventura+: translucent sidebar with a
// search field and user card, panes of inset-grouped rows on the right.
FloatingWindow {
    id: win

    title: I18n.tr("System Settings")
    visible: Panels.settings
    onVisibleChanged: if (!visible) Panels.settings = false
    implicitWidth: 760
    implicitHeight: 680
    minimumSize: Qt.size(680, 480)
    color: "transparent"

    readonly property var panes: Panels.settingsPanes
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

        // macOS 27: the sidebar is an edge-to-edge shaded column again (Tahoe
        // floated it as an inset card), rounded only by the window's corners.
        Rectangle {
            anchors.fill: parent
            radius: Theme.windowRadius
            color: Theme.dark ? "#29292B" : "#EEEEF0"
            Rectangle {   // square off the corners on the content side
                anchors.right: parent.right
                width: parent.radius
                height: parent.height
                color: parent.color
            }
            Rectangle {   // hairline between sidebar and content
                anchors.right: parent.right
                width: 1
                height: parent.height
                color: Theme.dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.08)
            }
        }

        MouseArea { anchors.fill: parent; onPressed: win.startMove() }

        TrafficLights {
            x: 18
            y: 20
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
                font.pixelSize: Theme.px(13)
                clip: true
                onTextChanged: win.filter = text.toLowerCase()
                Label { visible: !searchInput.text; text: I18n.tr("Search"); color: Theme.textTertiary }
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
                            font.pixelSize: Theme.px(17)
                            font.weight: Font.DemiBold
                        }
                    }
                    Column {
                        anchors.left: avatar.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        Label { text: SystemInfo.fullName || SystemInfo.user; font.weight: Font.DemiBold }
                        Label { text: I18n.tr("Foxtail Account"); font.pixelSize: Theme.px(11); color: Theme.textSecondary }
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
                            // macOS System Settings: the selected pane is filled
                            // with the accent colour, in white text.
                            radius: 8
                            color: navItem.selected ? Theme.accent
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
                            color: navItem.selected ? "white" : Theme.text
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
                    font.pixelSize: Theme.px(15)
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
                    case "users": return usersPane;
                    case "datetime": return dateTimePane;
                    case "printers": return printersPane;
                    case "defaultapps": return defaultAppsPane;
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
                    case "menubar": return menuBarPane;
                    case "accessibility": return accessibilityPane;
                    case "trackpad": return trackpadPane;
                    case "mouse": return mousePane;
                    }
                    return generalPane;
                }
            }
        }
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
                        text: I18n.tr("Foxtail")
                        font.pixelSize: Theme.px(30)
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
                SettingRow { label: I18n.tr("Name"); Label { text: SystemInfo.hostname; color: Theme.textSecondary } }
                SettingRow { label: I18n.tr("Chip"); Label { text: SystemInfo.cpu; color: Theme.textSecondary; width: 300; horizontalAlignment: Text.AlignRight } }
                SettingRow { label: I18n.tr("Graphics"); Label { text: SystemInfo.gpu; color: Theme.textSecondary; width: 300; horizontalAlignment: Text.AlignRight } }
                SettingRow { label: I18n.tr("Memory"); Label { text: SystemInfo.memory; color: Theme.textSecondary } }
                SettingRow { label: I18n.tr("Storage"); Label { text: SystemInfo.disk; color: Theme.textSecondary } }
                SettingRow { label: I18n.tr("Kernel"); last: true; Label { text: I18n.tr("Linux ") + SystemInfo.kernel; color: Theme.textSecondary } }
            }

            SectionTitle { text: I18n.tr("Open at Login") }
            Group {
                Repeater {
                    model: LoginItems.items
                    SettingRow {
                        required property string modelData
                        required property int index
                        label: Apps.nameFor(modelData)
                        PushButton { text: I18n.tr("Remove"); onClicked: LoginItems.remove(modelData) }
                    }
                }
                SettingRow {
                    label: LoginItems.items.length ? "Add an app" : "No apps open when you log in"
                    sub: I18n.tr("Apps here open automatically when you log in.")
                    last: true
                    Choice {
                        menuWidth: 240
                        options: Apps.all.filter(e => !LoginItems.has(e.id)).map(e => [e.id, e.name])
                        value: ""
                        onPicked: v => LoginItems.add(v)
                    }
                }
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
                        Label { text: Power.percent + "%"; font.pixelSize: Theme.px(26); font.weight: Font.DemiBold }
                        Label {
                            text: Power.source + (Power.timeLeft ? " · " + Power.timeLeft : "")
                            color: Theme.textSecondary
                            font.pixelSize: Theme.px(12)
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
                text: I18n.tr("This computer doesn't have a battery.")
                color: Theme.textSecondary
            }

            SectionTitle { text: I18n.tr("Power Mode") }
            Group {
                Repeater {
                    model: [
                        { id: "power-saver", name: I18n.tr("Low Power"), sub: I18n.tr("Reduces energy use for longer battery life. The display and apps may be a little slower.") },
                        { id: "balanced", name: I18n.tr("Balanced"), sub: I18n.tr("Good performance with sensible energy use.") },
                        { id: "performance", name: I18n.tr("High Performance"), sub: I18n.tr("Maximum speed. Uses more energy and may make fans louder.") }
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
                    label: I18n.tr("Show battery percentage in menu bar")
                    Switch { checked: Settings.showBatteryPercent; onToggled: c => Settings.showBatteryPercent = c }
                }
                SettingRow {
                    label: I18n.tr("Switch to Low Power at 10%")
                    sub: I18n.tr("You'll also get a warning at 20%, 10% and 5%.")
                    Switch { checked: Settings.autoLowPower; onToggled: c => Settings.autoLowPower = c }
                }
                SettingRow {
                    label: I18n.tr("When the lid is closed")
                    sub: I18n.tr("With an external display connected, closing the lid only turns off the built-in display.")
                    last: true
                    Choice {
                        menuWidth: 160
                        options: [["sleep", I18n.tr("Sleep")], ["lock", I18n.tr("Lock Screen")], ["nothing", I18n.tr("Do Nothing")]]
                        value: Settings.lidAction
                        onPicked: v => Settings.lidAction = v
                    }
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
                            from: 0; to: 360; duration: Theme.ms(2400); loops: Animation.Infinite
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
                            font.pixelSize: Theme.px(15)
                            font.weight: Font.DemiBold
                            text: Updates.installing ? "Installing updates…"
                                : Updates.checking ? "Checking for updates…"
                                : Updates.count === 1 ? "1 update available"
                                : Updates.count > 1 ? `${Updates.count} updates available`
                                : "Foxtail is up to date"
                        }
                        Label {
                            width: parent.width
                            font.pixelSize: Theme.px(12)
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
                font.pixelSize: Theme.px(12)
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
                font.pixelSize: Theme.px(12)
            }

            Group {
                SettingRow {
                    label: I18n.tr("Check for updates automatically")
                    sub: I18n.tr("You'll get a notification when updates are ready. Nothing installs without you.")
                    Switch { checked: Settings.autoCheckUpdates; onToggled: c => Settings.autoCheckUpdates = c }
                }
                SettingRow {
                    label: I18n.tr("Beta updates")
                    sub: I18n.tr("Get new versions of Foxtail before they're released, to help test them. They may have more bugs.")
                    last: true
                    Switch { checked: Updates.channel === "testing"; onToggled: c => Updates.setChannel(c ? "testing" : "stable") }
                }
            }

            SectionTitle { text: I18n.tr("Restore an earlier version") }
            Label {
                width: parent.width
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                font.pixelSize: Theme.px(12)
                color: Theme.textSecondary
                text: I18n.tr("Foxtail saves a snapshot of the system before and after every update. Restoring one rolls back apps and system settings; your files and personal settings stay as they are. You can also pick a snapshot by holding Esc while your computer starts.")
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
                text: I18n.tr("No snapshots yet.")
                color: Theme.textSecondary
                font.pixelSize: Theme.px(12)
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
                    Label { x: 14; y: 14; text: I18n.tr("Appearance") }
                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 14
                        y: 12
                        spacing: 16
                        Repeater {
                            // Auto follows the time of day: dark from 7 PM to 7 AM.
                            model: [{ n: "Auto", mode: "auto" }, { n: "Light", mode: "light" }, { n: "Dark", mode: "dark" }]
                            Column {
                                id: modeChoice
                                required property var modelData
                                readonly property bool chosen: modelData.mode === "auto" ? Settings.appearanceAuto
                                    : !Settings.appearanceAuto && Settings.darkMode === (modelData.mode === "dark")
                                spacing: 6
                                Rectangle {
                                    width: 84; height: 56; radius: 8
                                    border.width: modeChoice.chosen ? 3 : 1
                                    border.color: modeChoice.chosen ? Theme.accent : Theme.separator
                                    clip: true
                                    Image {
                                        anchors.fill: parent; anchors.margins: 3
                                        source: "file://" + Settings.wallpaper
                                        sourceSize: Qt.size(160, 100)
                                        fillMode: Image.PreserveAspectCrop
                                    }
                                    // A little window, light, dark or split for Auto.
                                    Repeater {
                                        model: modeChoice.modelData.mode === "auto" ? [false, true] : [modeChoice.modelData.mode === "dark"]
                                        Item {
                                            required property bool modelData
                                            required property int index
                                            x: 14 + (modeChoice.modelData.mode === "auto" ? index * 28 : 0)
                                            y: 14
                                            width: modeChoice.modelData.mode === "auto" ? 28 : 56
                                            height: 34
                                            clip: true
                                            Rectangle {
                                                x: -parent.x + 14; width: 56; height: 34; radius: 4
                                                color: parent.modelData ? "#2A2A2C" : "#F5F5F7"
                                                Rectangle { width: parent.width; height: 6; radius: 3; color: parent.parent.modelData ? "#3A3A3C" : "#E5E5EA" }
                                                Rectangle { x: 6; y: 12; width: 26; height: 4; radius: 2; color: Theme.accent }
                                            }
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            Settings.appearanceAuto = modeChoice.modelData.mode === "auto";
                                            if (!Settings.appearanceAuto) Settings.darkMode = modeChoice.modelData.mode === "dark";
                                        }
                                    }
                                }
                                Label { anchors.horizontalCenter: parent.horizontalCenter; text: modeChoice.modelData.n; font.pixelSize: Theme.px(11) }
                            }
                        }
                    }
                }
            }

            Group {
                SettingRow {
                    label: I18n.tr("Liquid Glass")
                    sub: I18n.tr("Clear, refractive glass for the Dock, menus, Spotlight and Control Center. Turn off for classic frosted translucency.")
                    Switch { checked: Settings.liquidGlass; onToggled: c => Settings.liquidGlass = c }
                }
                SettingRow {
                    label: I18n.tr("Glass style")
                    sub: I18n.tr("Clear shows more of what's behind the glass. Tinted is more opaque, with more contrast.")
                    opacity: Settings.liquidGlass ? 1 : 0.4
                    Row {
                        spacing: 10
                        // "Clear" as in clear glass (I18n "Clear" means erase).
                        Label { text: I18n.english ? "Clear" : I18n.tr("Clear glass"); font.pixelSize: Theme.px(11); color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                        PlainSlider {
                            width: 150
                            anchors.verticalCenter: parent.verticalCenter
                            enabled: Settings.liquidGlass
                            value: Settings.glassTintLevel
                            onMoved: v => Settings.glassTint = v
                        }
                        Label { text: I18n.tr("Tinted"); font.pixelSize: Theme.px(11); color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                SettingRow {
                    label: I18n.tr("Refract windows behind glass")
                    sub: I18n.tr("Menus and Control Center bend what's actually behind them, not just the wallpaper.")
                    Switch {
                        checked: Settings.refractWindows
                        opacity: Settings.liquidGlass ? 1 : 0.4
                        onToggled: c => Settings.refractWindows = c
                    }
                }
                SettingRow {
                    label: I18n.tr("Reduce transparency")
                    Switch { checked: Settings.reduceTransparency; onToggled: c => Settings.reduceTransparency = c }
                }
                SettingRow {
                    label: I18n.tr("Accent color")
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

        }
    }

    Component {
        id: dockPane
        Column {
            spacing: 14
            SectionTitle { text: I18n.tr("Dock") }
            Group {
                SettingRow {
                    label: I18n.tr("Size")
                    PlainSlider { from: 36; to: 80; value: Settings.dockIconSize; onMoved: v => Settings.dockIconSize = Math.round(v) }
                }
                SettingRow {
                    label: I18n.tr("Magnification")
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
                    label: I18n.tr("Automatically hide and show the Dock")
                    last: true
                    Switch { checked: Settings.dockAutoHide; onToggled: c => Settings.dockAutoHide = c }
                }
            }
            SectionTitle { text: I18n.tr("Desktop") }
            Group {
                SettingRow {
                    label: I18n.tr("Show items on the desktop")
                    sub: I18n.tr("Files in your Desktop folder appear on the wallpaper. Screenshots are saved there.")
                    last: true
                    Switch { checked: Settings.showDesktopItems; onToggled: c => Settings.showDesktopItems = c }
                }
            }
            SectionTitle { text: I18n.tr("Hot Corners") }
            Group {
                Repeater {
                    model: [["tl", "Top left"], ["tr", "Top right"], ["bl", "Bottom left"], ["br", "Bottom right"]]
                    SettingRow {
                        required property var modelData
                        required property int index
                        label: modelData[1]
                        last: index === 3
                        Choice {
                            menuWidth: 200
                            options: [["", "—"], ["mission", "Mission Control"], ["desktop", "Desktop"],
                                      ["notifications", "Notification Center"], ["launchpad", "Apps"],
                                      ["lock", "Lock Screen"], ["sleep", "Put Display to Sleep"]]
                            value: Settings.hotCorners[modelData[0]] ?? ""
                            onPicked: v => {
                                const c = Object.assign({}, Settings.hotCorners);
                                c[modelData[0]] = v;
                                Settings.hotCorners = c;
                            }
                        }
                    }
                }
            }
            SectionTitle { text: I18n.tr("Windows") }
            Group {
                SettingRow {
                    label: I18n.tr("New windows float, like macOS")
                    sub: I18n.tr("Turn off for tiling: windows arrange themselves side by side.")
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
            SectionTitle { text: I18n.tr("Foxtail Wallpapers") }
            Flow {
                id: grid
                property var files: []
                width: parent.width
                spacing: 12
                // Dynamic: a light picture in Light mode and a dark one in Dark
                // mode, like macOS's dynamic desktops. Two pairs: Vixen (2.0)
                // and Dunes (Dawn and Dusk).
                Repeater {
                    model: [{ id: "vixen", n: "Vixen", a: "foxtail-vixen-day", b: "foxtail-vixen-night" },
                            { id: "dunes", n: I18n.tr("Dunes"), a: "foxtail-dawn", b: "foxtail-dusk" }]
                    Rectangle {
                        id: dyn
                        required property var modelData
                        readonly property bool current: Settings.dynamicWallpaper && Settings.dynamicPair === modelData.id
                        width: (grid.width - 36) / 4
                        height: width * 0.62
                        radius: 8
                        color: "transparent"
                        border.width: current ? 3 : 0
                        border.color: Theme.accent
                        Item {
                            anchors.fill: parent
                            anchors.margins: 3
                            clip: true
                            Image {
                                anchors.fill: parent
                                source: "file://" + Settings.wallpaperDir + "/" + dyn.modelData.a + ".jpg"
                                sourceSize: Qt.size(240, 150)
                                fillMode: Image.PreserveAspectCrop
                            }
                            Image {   // the dark half
                                width: parent.width / 2
                                height: parent.height
                                x: parent.width / 2
                                source: "file://" + Settings.wallpaperDir + "/" + dyn.modelData.b + ".jpg"
                                sourceSize: Qt.size(240, 150)
                                fillMode: Image.PreserveAspectCrop
                                horizontalAlignment: Image.AlignRight
                            }
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 6
                            text: I18n.tr("Dynamic") + " · " + dyn.modelData.n
                            color: "white"
                            style: Text.Outline
                            styleColor: Qt.rgba(0, 0, 0, 0.3)
                            font.pixelSize: Theme.px(11)
                            font.weight: Font.DemiBold
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                Settings.dynamicPair = dyn.modelData.id;
                                Settings.dynamicWallpaper = true;
                                Settings.wallpaper = Settings.dynamicFile(Settings.darkMode);
                            }
                        }
                    }
                }
                Repeater {
                    model: grid.files
                    Rectangle {
                        required property string modelData
                        width: (grid.width - 36) / 4
                        height: width * 0.62
                        radius: 8
                        color: "transparent"
                        border.width: !Settings.dynamicWallpaper && Settings.wallpaper === modelData ? 3 : 0
                        border.color: Theme.accent
                        Image {
                            anchors.fill: parent
                            anchors.margins: 3
                            source: "file://" + parent.modelData
                            sourceSize: Qt.size(240, 150)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                        MouseArea { anchors.fill: parent; onClicked: { Settings.dynamicWallpaper = false; Settings.wallpaper = parent.modelData; } }
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
                    label: I18n.tr("Wi-Fi")
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
            SectionTitle { text: I18n.tr("Wired") }
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

    Component { id: btPane; BluetoothPane {} }

    Component { id: displaysPane; DisplaysPane {} }

    Component { id: soundPane; SoundPane {} }

    Component {
        id: notificationsPane
        Column {
            spacing: 14
            Group {
                SettingRow {
                    label: I18n.tr("Show notification banners")
                    sub: I18n.tr("Banners appear in the top-right corner and go away automatically.")
                    last: true
                    Switch { checked: !Settings.doNotDisturb; onToggled: c => Settings.doNotDisturb = !c }
                }
            }
            PushButton { text: I18n.tr("Clear Notification History"); onClicked: Notifs.clearAll() }
        }
    }

    Component {
        id: focusPane
        Column {
            spacing: 14
            Group {
                SettingRow {
                    label: I18n.tr("Do Not Disturb")
                    sub: I18n.tr("Silences notification banners. Critical alerts still come through.")
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
                    label: I18n.tr("Require password after the screen is idle for")
                    Choice {
                        options: [[1, "1 minute"], [5, "5 minutes"], [15, "15 minutes"], [60, "1 hour"], [0, "Never"]]
                        value: Settings.lockAfter
                        onPicked: v => Settings.lockAfter = v
                    }
                }
                SettingRow {
                    label: I18n.tr("Turn display off when inactive for")
                    Choice {
                        options: [[2, "2 minutes"], [10, "10 minutes"], [30, "30 minutes"], [0, "Never"]]
                        value: Settings.displayOffAfter
                        onPicked: v => Settings.displayOffAfter = v
                    }
                }
                SettingRow {
                    label: I18n.tr("Lock Screen now")
                    last: true
                    PushButton { text: I18n.tr("Lock"); onClicked: { Panels.settings = false; Lock.lock(); } }
                }
            }
        }
    }

    Component { id: keyboardPane; KeyboardPane {} }
    Component { id: menuBarPane; MenuBarPane {} }
    Component { id: accessibilityPane; AccessibilityPane {} }
    Component { id: trackpadPane; TrackpadPane {} }
    Component { id: mousePane; MousePane {} }
    Component { id: usersPane; UsersPane {} }
    Component { id: dateTimePane; DateTimePane {} }
    Component { id: printersPane; PrintersPane {} }
    Component { id: defaultAppsPane; DefaultAppsPane {} }
}
