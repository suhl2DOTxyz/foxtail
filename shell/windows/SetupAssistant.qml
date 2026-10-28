import QtQuick
import Quickshell
import qs.services
import qs.components
import qs.settings

// Setup Assistant, like the screens macOS shows on first login and after a
// major update: appearance, Liquid Glass, accent color and desktop widgets,
// each applied live, then a few tips. Finishing records the major version in
// Settings.setupVersion so it doesn't come back until the next one.
FloatingWindow {
    id: win

    title: I18n.tr("Welcome to Foxtail")
    visible: Panels.setupAssistant
    onVisibleChanged: if (!visible) win.finish()
    implicitWidth: 640
    implicitHeight: 500
    minimumSize: Qt.size(640, 500)
    maximumSize: Qt.size(640, 500)
    color: "transparent"

    readonly property int major: 2
    property int page: 0
    readonly property int pages: 6
    property bool addWidgets: Settings.desktopWidgets.length === 0

    // Come to the front with the keyboard, so the first click lands.
    Component.onCompleted: focusSoon.start()
    Timer {
        id: focusSoon
        interval: 300
        onTriggered: Hypr.dispatch(`hl.dsp.focus({ window = "title:^${win.title}$" })`)
    }

    function finish() {
        Settings.setupVersion = major;
        Panels.setupAssistant = false;
    }
    function next() {
        if (page === 4 && addWidgets && Settings.desktopWidgets.length === 0) {
            // Clock, Calendar and Battery in the top-left corner, like a
            // fresh macOS desktop with widgets.
            const t = Date.now();
            Settings.desktopWidgets = [
                { id: t + "c", kind: "clock", x: 24, y: 24 },
                { id: t + "k", kind: "calendar", x: 202, y: 24 },
                { id: t + "b", kind: "battery", x: 24, y: 202 }
            ];
        }
        if (page < pages - 1) page++;
        else finish();
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.windowRadius
        color: Theme.dark ? "#1E1E1F" : "#FFFFFF"
        border.color: Theme.glassOutline
    }
    MouseArea {
        anchors.fill: parent
        onPressed: { try { win._backingWindow.startSystemMove(); } catch (e) {} }
    }

    // ---- pages ----
    Item {
        id: stage
        x: 48
        y: 40
        width: parent.width - 96
        height: parent.height - 120

        Loader {
            id: pageLoader
            anchors.fill: parent
            sourceComponent: [welcome, appearance, glass, accent, widgets, done][win.page]
            onLoaded: { item.opacity = 0; item.opacity = 1; }
        }
    }

    // ---- footer: page dots, Back, Continue ----
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 32
        spacing: 7
        Repeater {
            model: win.pages
            Rectangle {
                required property int index
                width: 7; height: 7; radius: 3.5
                color: index === win.page ? Theme.text : Theme.controlOff
            }
        }
    }
    PushButton {
        visible: win.page > 0 && win.page < win.pages - 1
        anchors.left: parent.left
        anchors.leftMargin: 32
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        text: I18n.tr("Back")
        onClicked: win.page--
    }
    PushButton {
        anchors.right: parent.right
        anchors.rightMargin: 32
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        primary: true
        text: win.page === win.pages - 1 ? I18n.tr("Get Started") : I18n.tr("Continue")
        onClicked: win.next()
    }

    // ================= page contents =================

    component Heading: Column {
        property string title
        property string sub
        width: parent?.width ?? 0
        spacing: 8
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: parent.title
            font.pixelSize: Theme.px(24)
            font.weight: Font.Bold
            wrapMode: Text.Wrap
        }
        Label {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: parent.sub
            color: Theme.textSecondary
            font.pixelSize: Theme.px(13)
            wrapMode: Text.Wrap
        }
    }

    component Page: Column {
        spacing: 26
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
    }

    Component {
        id: welcome
        Page {
            Item { width: 1; height: 20 }
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 128; height: 128
                sourceSize: Qt.size(256, 256)
                source: Qt.resolvedUrl("../icons/foxtail-logo.png")
            }
            Heading {
                title: I18n.tr("Welcome to Foxtail 2.0")
                sub: I18n.tr("Foxtail “%1” is the biggest update yet: widgets on your desktop, apps that look and feel like Mac apps, and more. Take a minute to make it yours.").replace("%1", SystemInfo.codename)
            }
        }
    }

    Component {
        id: appearance
        Page {
            Heading {
                title: I18n.tr("Choose your look")
                sub: I18n.tr("Light, Dark, or Auto to switch with the time of day. You can change this any time in System Settings.")
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 22
                Repeater {
                    model: [{ id: "light", n: I18n.tr("Light") }, { id: "dark", n: I18n.tr("Dark") }, { id: "auto", n: I18n.tr("Auto") }]
                    Column {
                        id: choice
                        required property var modelData
                        readonly property bool selected: modelData.id === "auto" ? Settings.appearanceAuto
                            : !Settings.appearanceAuto && Settings.darkMode === (modelData.id === "dark")
                        spacing: 8
                        Rectangle {
                            width: 136; height: 92; radius: 12
                            border.width: choice.selected ? 3 : 1
                            border.color: choice.selected ? Theme.accent : Theme.separator
                            clip: true
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: choice.modelData.id === "dark" ? "#3B1009" : "#FFC48A" }
                                GradientStop { position: choice.modelData.id === "auto" ? 0.5 : 1; color: choice.modelData.id === "dark" ? "#7A2E2A" : "#FF9A4D" }
                                GradientStop { position: choice.modelData.id === "auto" ? 0.5001 : 1; color: choice.modelData.id === "auto" ? "#3B1009" : (choice.modelData.id === "dark" ? "#7A2E2A" : "#FF9A4D") }
                            }
                            Rectangle {   // a little window
                                x: 22; y: 20
                                width: 92; height: 56; radius: 7
                                color: choice.modelData.id === "light" ? "#FFFFFF" : "#2A2A2C"
                                Rectangle { x: 8; y: 8; width: 30; height: 5; radius: 2.5; color: Theme.accent }
                                Rectangle { x: 8; y: 18; width: 60; height: 4; radius: 2; color: choice.modelData.id === "light" ? "#D8D8DC" : "#4A4A4E" }
                                Rectangle { x: 8; y: 26; width: 46; height: 4; radius: 2; color: choice.modelData.id === "light" ? "#D8D8DC" : "#4A4A4E" }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    Settings.appearanceAuto = choice.modelData.id === "auto";
                                    if (choice.modelData.id !== "auto") Settings.darkMode = choice.modelData.id === "dark";
                                }
                            }
                        }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: choice.modelData.n; font.weight: choice.selected ? Font.DemiBold : Font.Normal }
                    }
                }
            }
        }
    }

    Component {
        id: glass
        Page {
            Heading {
                title: I18n.tr("Liquid Glass")
                sub: I18n.tr("The Dock, menus, Control Center and widgets are made of glass that bends the light behind it. Make it clearer, or more tinted for contrast.")
            }
            Group {
                width: parent.width
                SettingRow {
                    label: I18n.tr("Liquid Glass")
                    Switch { checked: Settings.liquidGlass; onToggled: c => Settings.liquidGlass = c }
                }
                SettingRow {
                    label: I18n.tr("Glass style")
                    last: true
                    opacity: Settings.liquidGlass ? 1 : 0.4
                    Row {
                        spacing: 10
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
            }
        }
    }

    Component {
        id: accent
        Page {
            Heading {
                title: I18n.tr("Pick an accent color")
                sub: I18n.tr("Used for buttons, selections, switches and highlights everywhere, in Foxtail and in your apps.")
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                Repeater {
                    model: ["#FF7A1A", "#FF3B30", "#FF2D55", "#AF52DE", "#007AFF", "#34C759", "#FFCC00", "#8E8E93"]
                    Rectangle {
                        required property string modelData
                        readonly property bool selected: String(Settings.accent).toUpperCase() === modelData
                        width: 36; height: 36; radius: 18
                        color: modelData
                        border.width: selected ? 3 : 0
                        border.color: Theme.dark ? "white" : Qt.rgba(0, 0, 0, 0.35)
                        Rectangle { anchors.centerIn: parent; visible: parent.selected; width: 10; height: 10; radius: 5; color: "white" }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Settings.accent = parent.modelData }
                        Accessible.role: Accessible.RadioButton
                        Accessible.name: modelData
                        Accessible.checked: selected
                    }
                }
            }
        }
    }

    Component {
        id: widgets
        Page {
            Heading {
                title: I18n.tr("Widgets on your desktop")
                sub: I18n.tr("A clock, your calendar and the battery, right on the wallpaper. Drag them anywhere, or right-click the desktop and choose Edit Widgets… for more.")
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14
                opacity: win.addWidgets ? 1 : 0.4
                Repeater {
                    model: [["clock", I18n.tr("Clock")], ["calendar", I18n.tr("Calendar")], ["battery", I18n.tr("Battery")]]
                    Column {
                        required property var modelData
                        spacing: 6
                        Rectangle {
                            width: 96; height: 96; radius: 20
                            color: Theme.tile
                            border.width: 1
                            border.color: Theme.separator
                            Icon { anchors.centerIn: parent; size: 32; name: parent.parent.modelData[0]; color: Theme.accent }
                        }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: parent.modelData[1]; font.pixelSize: Theme.px(12) }
                    }
                }
            }
            Group {
                width: parent.width
                SettingRow {
                    label: I18n.tr("Add widgets to my desktop")
                    last: true
                    Switch { checked: win.addWidgets; onToggled: c => win.addWidgets = c }
                }
            }
        }
    }

    Component {
        id: done
        Page {
            Heading {
                title: I18n.tr("You're all set")
                sub: I18n.tr("A few things worth knowing:")
            }
            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14
                Repeater {
                    model: [
                        ["search", I18n.tr("Press ⌘ Space to find apps, files and settings, or do quick math.")],
                        ["controls", I18n.tr("Control Center in the menu bar has Wi-Fi, Focus, sound, Dark Mode and Liquid Glass.")],
                        ["grid", I18n.tr("Right-click the desktop and choose Edit Widgets… to add more widgets.")],
                        ["keyboard", I18n.tr("Make your own shortcuts in System Settings ▸ Keyboard.")]
                    ]
                    Row {
                        required property var modelData
                        spacing: 14
                        Rectangle {
                            width: 34; height: 34; radius: 9
                            color: Theme.accent
                            Icon { anchors.centerIn: parent; size: 17; name: parent.parent.modelData[0]; color: "white" }
                        }
                        Label {
                            width: 420
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData[1]
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
    }
}
