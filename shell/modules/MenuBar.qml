import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Services.UPower
import qs.services
import qs.components

// The menu bar: fox menu, bold app name and app menus on the left; status
// items, Control Center, Spotlight and the clock on the right.
PanelWindow {
    id: bar

    required property var modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "foxtail-menubar"
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.menuBarHeight
    exclusiveZone: Theme.menuBarHeight
    color: "transparent"

    readonly property bool menuOpen: Panels.popover !== "" && Panels.screen === modelData

    Rectangle {
        anchors.fill: parent
        color: Theme.menuBar
        Behavior on color { ColorAnimation { duration: Theme.anim } }
    }

    // Tahoe-style clear bar gets a soft scrim so text stays legible on any wallpaper.
    Rectangle {
        anchors.fill: parent
        visible: Theme.liquid
        gradient: Gradient {
            GradientStop { position: 0; color: Theme.wallpaperDark ? Qt.rgba(0, 0, 0, 0.22) : Qt.rgba(1, 1, 1, 0.28) }
            GradientStop { position: 1; color: "transparent" }
        }
    }

    readonly property color fg: Theme.menuBarText

    // ---------- left ----------
    Row {
        id: left
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        spacing: 0

        BarButton {
            id: foxButton
            active: Panels.popover === "fox" && bar.menuOpen
            width: 36
            onPressed: bar.openMenu("fox", foxButton)
            onHoverSwitch: bar.openMenu("fox", foxButton, true)
            Icon {
                anchors.centerIn: parent
                name: "foxtail"
                size: 17
                color: bar.fg
            }
        }

        BarButton {
            id: appName
            active: Panels.popover === "app:name" && bar.menuOpen
            width: appLabel.implicitWidth + 20
            onPressed: bar.openMenu("app:name", appName)
            onHoverSwitch: bar.openMenu("app:name", appName, true)
            Label {
                id: appLabel
                anchors.centerIn: parent
                text: MenuModels.appName
                font.weight: Font.Bold
                color: bar.fg
            }
        }

        Repeater {
            model: MenuModels.menuTitles
            BarButton {
                id: menuTitle
                required property string modelData
                required property int index
                readonly property string key: "app:" + index
                active: Panels.popover === key && bar.menuOpen
                width: titleLabel.implicitWidth + 20
                onPressed: bar.openMenu(key, menuTitle)
                onHoverSwitch: bar.openMenu(key, menuTitle, true)
                Label {
                    id: titleLabel
                    anchors.centerIn: parent
                    text: menuTitle.modelData
                    color: bar.fg
                }
            }
        }
    }

    // ---------- right ----------
    Row {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        spacing: 2

        // Screen recording in progress: click to stop.
        BarButton {
            id: recButton
            visible: Capture.recording
            width: recRow.implicitWidth + 18
            onPressed: Capture.stop()
            Row {
                id: recRow
                anchors.centerIn: parent
                spacing: 6
                Icon { size: 12; name: "stop"; color: bar.fg; anchors.verticalCenter: parent.verticalCenter }
                Label {
                    text: Capture.clock(Capture.elapsed)
                    color: bar.fg
                    font.pixelSize: 12
                    font.features: { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Input source (shown when more than one keyboard layout is set up).
        BarButton {
            id: inputButton
            visible: Keyboard.layouts.length > 1
            width: inputBadge.width + 16
            active: Panels.popover === "input" && bar.menuOpen
            onPressed: bar.openMenu("input", inputButton)
            Rectangle {
                id: inputBadge
                anchors.centerIn: parent
                width: Math.max(20, inputLabel.implicitWidth + 8)
                height: 16
                radius: 4
                color: "transparent"
                border.width: 1.2
                border.color: bar.fg
                Label {
                    id: inputLabel
                    anchors.centerIn: parent
                    text: Keyboard.shortName(Keyboard.active)
                    font.pixelSize: 9
                    font.weight: Font.Bold
                    color: bar.fg
                }
            }
        }

        BarButton {
            id: batteryButton
            visible: Power.hasBattery
            width: batteryRow.implicitWidth + 16
            active: Panels.popover === "battery" && bar.menuOpen
            onPressed: bar.openMenu("battery", batteryButton)
            Row {
                id: batteryRow
                anchors.centerIn: parent
                spacing: 5
                Label {
                    visible: Settings.showBatteryPercent
                    text: Power.percent + "%"
                    color: bar.fg
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                }
                Item {
                    width: 25; height: 13
                    anchors.verticalCenter: parent.verticalCenter
                    Icon { anchors.fill: parent; size: 25; name: "battery"; color: bar.fg }
                    Rectangle {
                        x: 3; y: 4
                        height: 5.5
                        radius: 1.5
                        width: 15 * (UPower.displayDevice?.percentage ?? 0)
                        color: Power.mode === "power-saver" ? "#FFD60A"
                             : Power.charging || Power.full ? "#30D158"
                             : (UPower.displayDevice?.percentage ?? 1) < 0.2 ? "#FF453A" : bar.fg
                    }
                    Icon {
                        visible: Power.charging
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -1
                        size: 10
                        name: "bolt"
                        color: bar.fg
                    }
                }
            }
        }

        BarButton {
            id: wifiButton
            width: 32
            active: Panels.popover === "wifi" && bar.menuOpen
            onPressed: bar.openMenu("wifi", wifiButton)
            Icon {
                anchors.centerIn: parent
                size: 16
                name: Networking.wifiEnabled ? "wifi" : "wifi-off"
                color: bar.fg
            }
        }

        BarButton {
            id: ccButton
            width: 32
            active: Panels.popover === "controlcenter" && bar.menuOpen
            onPressed: bar.openMenu("controlcenter", ccButton)
            Icon { anchors.centerIn: parent; size: 16; name: "controls"; color: bar.fg }
        }

        BarButton {
            width: 32
            active: Panels.spotlight
            onPressed: {
                Panels.popover = "";
                Panels.screen = bar.modelData;
                Panels.spotlight = !Panels.spotlight;
            }
            Icon { anchors.centerIn: parent; size: 14; name: "search"; color: bar.fg }
        }

        BarButton {
            id: clockButton
            width: clock.implicitWidth + 18
            active: Panels.popover === "calendar" && bar.menuOpen
            onPressed: bar.openMenu("calendar", clockButton)
            Label {
                id: clock
                anchors.centerIn: parent
                color: bar.fg
                text: {
                    const d = time.date;
                    const fmt = Settings.clock24h ? (Settings.clockSeconds ? "HH:mm:ss" : "HH:mm")
                                                  : (Settings.clockSeconds ? "h:mm:ss AP" : "h:mm AP");
                    return Qt.formatDateTime(d, "ddd MMM d") + "   " + Qt.formatDateTime(d, fmt);
                }
            }
        }
    }

    SystemClock {
        id: time
        precision: Settings.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }

    // Opens a popover anchored under `item`. With `hoverOnly`, only switches
    // if some menu is already open (macOS: sliding across the bar).
    function openMenu(key, item, hoverOnly) {
        if (hoverOnly) {
            if (!menuOpen || Panels.popover === key || !(Panels.popover === "fox" || Panels.popover.startsWith("app:"))) return;
            Panels.popover = key;
        } else {
            Panels.toggle(key, modelData);
        }
        const p = item.mapToItem(null, 0, 0);
        Panels.anchorX = p.x;
        Panels.anchorRight = p.x + item.width;
        Panels.screen = modelData;
    }

    component BarButton: Item {
        id: btn
        property bool active: false
        signal pressed()
        signal hoverSwitch()
        height: Theme.menuBarHeight
        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            anchors.bottomMargin: 3
            radius: Theme.liquid ? height / 2 : 5
            color: btn.active ? (Theme.liquid ? Qt.rgba(1, 1, 1, Theme.wallpaperDark ? 0.22 : 0.45)
                                              : Theme.hover)
                              : "transparent"
            Behavior on color { ColorAnimation { duration: 80 } }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPressed: btn.pressed()
            onEntered: btn.hoverSwitch()
        }
    }
}
