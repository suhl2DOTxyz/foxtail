import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// A transparent full-screen layer that hosts every popover (menus, Control
// Center, Spotlight, ...). Clicking anywhere outside the popover closes it.
// The menu-bar strip is cut out of the input mask so you can slide between
// menus, as on macOS.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property bool mine: Panels.screen === null || Panels.screen === modelData
    readonly property bool modal: Panels.spotlight || Panels.confirm !== "" || Panels.popover === "clipboard" || Panels.popover === "emoji"
    visible: mine && (Panels.popover !== "" || modal)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "foxtail-popover"
    WlrLayershell.keyboardFocus: modal ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    readonly property size screenSize: Qt.size(width, height)

    // Screen snapshot that Liquid Glass popovers in this window refract
    // (read by components/Glass.qml through QsWindow.window.backdrop).
    property Item backdrop: liveBackdrop
    LiveBackdrop {
        id: liveBackdrop
        screen: root.modelData
        inUse: root.visible
    }
    readonly property point origin: Qt.point(0, 0)

    mask: Region {
        item: catcher
        regions: [
            Region { item: modal ? null : barStrip; intersection: Intersection.Subtract }
        ]
    }

    Item { id: barStrip; width: parent.width; height: Theme.menuBarHeight }

    // Dims the desktop behind modal dialogs.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: Panels.confirm !== "" ? 0.10 : 0   // below the blur threshold (ignore_alpha 0.15): macOS keeps the desktop sharp
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
    }

    MouseArea {
        id: catcher
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onPressed: {
            if (Panels.confirm !== "") return;
            Panels.closeAll();
        }
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            Panels.confirm = "";
            Panels.closeAll();
        }
    }

    // ---------- pull-down menus ----------
    Loader {
        active: Panels.popover === "fox" || Panels.popover.startsWith("app:")
        x: Math.min(Panels.anchorX, root.width - (item?.width ?? 0) - 6)
        y: Theme.menuBarHeight + 3
        sourceComponent: MenuPanel {
            model: MenuModels.model(Panels.popover)
            windowOffset: root.origin
            screenSize: root.screenSize
            onDone: Panels.closeAll()
        }
    }

    // ---------- right-click menus (desktop) ----------
    Loader {
        active: Panels.popover === "context"
        x: Math.max(6, Math.min(Panels.contextPos.x, root.width - (item?.width ?? 0) - 6))
        y: Math.max(Theme.menuBarHeight + 3, Math.min(Panels.contextPos.y, root.height - (item?.height ?? 0) - 6))
        sourceComponent: MenuPanel {
            minWidth: 200
            model: Panels.contextModel
            windowOffset: root.origin
            screenSize: root.screenSize
            onDone: Panels.closeAll()
        }
    }

    // ---------- Dock icon context menu ----------
    Loader {
        active: Panels.popover === "dockmenu" && Panels.dockMenuApp !== null
        x: Math.max(6, Math.min(Panels.dockMenuX - (item?.width ?? 0) / 2, root.width - (item?.width ?? 0) - 6))
        y: root.height - (item?.height ?? 0) - Settings.dockIconSize - 30
        sourceComponent: MenuPanel {
            minWidth: 180
            windowOffset: root.origin
            screenSize: root.screenSize
            onDone: Panels.closeAll()
            model: {
                const id = Panels.dockMenuApp;
                const running = Apps.isRunning(id);
                const pinned = Settings.pinnedApps.indexOf(id) >= 0;
                const items = [];
                for (const w of Apps.windowsFor(id))
                    items.push({ text: w.title || Apps.nameFor(id), checkable: true, checked: w.activated, action: () => w.activate() });
                if (items.length) items.push({ separator: true });
                items.push({ text: I18n.tr("New Window"), action: () => Apps.launch(id) });
                items.push({ separator: true });
                items.push({ text: I18n.tr("Options"), submenu: [
                    { text: pinned ? I18n.tr("Remove from Dock") : I18n.tr("Keep in Dock"), enabled: id !== "org.gnome.Nautilus",
                      action: () => pinned ? Apps.unpin(id) : Apps.pin(id) },
                    { text: I18n.tr("Open at Login"), checkable: true, checked: LoginItems.has(id), action: () => LoginItems.toggle(id) }
                ] });
                if (running) {
                    const wins = Apps.windowsFor(id);
                    const hidden = wins.length > 0 && wins.every(w => Hypr.isHidden(w));
                    items.push({ separator: true });
                    items.push({ text: hidden ? I18n.tr("Show") : I18n.tr("Hide"), action: () => {
                        if (hidden) Apps.focus(id);
                        else Hypr.hideApp(wins[0].appId);
                    } });
                    items.push({ text: I18n.tr("Quit"), action: () => Apps.quit(id) });
                }
                return items;
            }
        }
    }

    // ---------- Dock ▸ Downloads ----------
    Loader {
        active: Panels.popover === "downloads"
        x: Math.max(6, Math.min(Panels.downloadsX - (item?.width ?? 0) / 2, root.width - (item?.width ?? 0) - 6))
        y: root.height - (item?.height ?? 0) - Settings.dockIconSize - 34
        sourceComponent: DownloadsStack {
            screenSize: root.screenSize
            windowOffset: root.origin
        }
    }

    // ---------- Control Center ----------
    Loader {
        active: Panels.popover === "controlcenter"
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: Theme.menuBarHeight + 4
        sourceComponent: ControlCenter {
            screenSize: root.screenSize
            windowOffset: root.origin
        }
    }

    // ---------- Input sources ----------
    Loader {
        active: Panels.popover === "input"
        x: Math.min(Panels.anchorX, root.width - (item?.width ?? 0) - 8)
        y: Theme.menuBarHeight + 3
        sourceComponent: MenuPanel {
            minWidth: 220
            windowOffset: root.origin
            screenSize: root.screenSize
            onDone: Panels.closeAll()
            model: {
                const items = Keyboard.layouts.map((code, i) => ({
                    text: Keyboard.nameFor(code), checkable: true, checked: i === Keyboard.activeIndex,
                    action: () => Keyboard.select(i)
                }));
                items.push({ separator: true });
                items.push({ text: I18n.tr("Open Keyboard Settings…"), action: () => Panels.openSettings("keyboard") });
                return items;
            }
        }
    }

    // ---------- Battery ----------
    Loader {
        active: Panels.popover === "battery"
        x: Math.min(Panels.anchorX, root.width - (item?.width ?? 0) - 8)
        y: Theme.menuBarHeight + 3
        sourceComponent: BatteryMenu {
            screenSize: root.screenSize
            windowOffset: root.origin
        }
    }

    // ---------- Sound ----------
    Loader {
        active: Panels.popover === "sound"
        x: Math.min(Panels.anchorX, root.width - (item?.width ?? 0) - 8)
        y: Theme.menuBarHeight + 3
        sourceComponent: SoundMenu {
            screenSize: root.screenSize
            windowOffset: root.origin
        }
    }

    // ---------- Wi-Fi ----------
    Loader {
        active: Panels.popover === "wifi"
        x: Math.min(Panels.anchorX, root.width - (item?.width ?? 0) - 8)
        y: Theme.menuBarHeight + 3
        sourceComponent: WifiMenu {
            screenSize: root.screenSize
        }
    }

    // ---------- Notification Center + calendar ----------
    Loader {
        active: Panels.popover === "calendar"
        anchors.right: parent.right
        anchors.rightMargin: 8
        y: Theme.menuBarHeight + 4
        sourceComponent: NotificationCenter {
            screenSize: root.screenSize
            windowOffset: root.origin
        }
    }

    // ---------- Clipboard history ----------
    Loader {
        active: Panels.popover === "clipboard"
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.22)
        sourceComponent: ClipboardMenu {
            screenSize: root.screenSize
            windowOffset: root.origin
        }
    }

    // ---------- Emoji & Symbols ----------
    Loader {
        active: Panels.popover === "emoji"
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.2)
        sourceComponent: EmojiPicker {
            screenSize: root.screenSize
            windowOffset: root.origin
        }
    }

    // ---------- Spotlight ----------
    Loader {
        active: Panels.spotlight
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(root.height * 0.22)
        sourceComponent: Spotlight {
            screenSize: root.screenSize
            windowOffset: root.origin
        }
    }

    // ---------- Restart / Shut Down / Log Out confirmation ----------
    Loader {
        active: Panels.confirm !== "" && Panels.confirm !== "auth"
        anchors.centerIn: parent
        sourceComponent: ConfirmDialog {
            screenSize: root.screenSize
            windowOffset: root.origin
        }
    }

    // ---------- administrator password (polkit) ----------
    // On one screen only: the one with the pointer's focused monitor.
    Loader {
        active: Panels.confirm === "auth" && root.modelData === (Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0])
        anchors.centerIn: parent
        sourceComponent: AuthDialog {
            screenSize: root.screenSize
            windowOffset: root.origin
        }
    }
}
