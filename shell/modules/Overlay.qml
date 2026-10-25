import QtQuick
import Quickshell
import Quickshell.Wayland
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
    readonly property bool modal: Panels.spotlight || Panels.confirm !== ""
    visible: mine && (Panels.popover !== "" || modal)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "foxtail-popover"
    WlrLayershell.keyboardFocus: modal ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    readonly property size screenSize: Qt.size(width, height)
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
        opacity: Panels.confirm !== "" ? 0.25 : 0
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
                items.push({ text: "New Window", action: () => Apps.launch(id) });
                items.push({ separator: true });
                items.push({ text: pinned ? "Remove from Dock" : "Keep in Dock", action: () => pinned ? Apps.unpin(id) : Apps.pin(id) });
                if (running) {
                    items.push({ separator: true });
                    items.push({ text: "Quit", action: () => Apps.quit(id) });
                }
                return items;
            }
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
        active: Panels.confirm !== ""
        anchors.centerIn: parent
        sourceComponent: ConfirmDialog {
            screenSize: root.screenSize
            windowOffset: root.origin
        }
    }
}
