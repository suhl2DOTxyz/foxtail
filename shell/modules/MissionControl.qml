import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// Mission Control: every window on the current desktop, spread out so none
// overlap, with the desktops along the top. Click a window to go to it, drag
// it onto a desktop to move it there, click a desktop to switch.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property var monitor: Hyprland.monitors.values.find(m => m.name === modelData.name) ?? null
    readonly property bool wanted: Panels.missionControl && (Hyprland.focusedMonitor?.name ?? modelData.name) === modelData.name

    // Stay mapped while the closing animation plays.
    property bool open: false
    visible: open || closing.running
    onWantedChanged: {
        if (wanted) {
            Hyprland.refreshToplevels();
            Hyprland.refreshWorkspaces();
            open = true;
        } else if (open) {
            open = false;
            closing.restart();
        }
    }
    Timer { id: closing; interval: 260 }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "foxtail-launchpad"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    readonly property int wsId: monitor?.activeWorkspace?.id ?? 1
    readonly property var windows: Hyprland.toplevels.values.filter(t =>
        t.workspace?.id === wsId && t.wayland && !t.wayland.parent && t.lastIpcObject?.size)
    readonly property var desktops: {
        const ids = Hyprland.workspaces.values
            .filter(w => w.id > 0 && (w.monitor?.name ?? modelData.name) === modelData.name)
            .map(w => w.id);
        if (ids.indexOf(wsId) < 0 && wsId > 0) ids.push(wsId);
        return ids.sort((a, b) => a - b);
    }

    function close() { Panels.missionControl = false; }
    // Activating the toplevel also raises it (hl.dsp.focus leaves floating windows behind others).
    function go(t) {
        close();
        if (t.wayland) t.wayland.activate();
    }
    function moveTo(t, ws) {
        Hypr.dispatch(`hl.dsp.window.move({ workspace = ${ws}, follow = false, window = "address:${t.address.startsWith("0x") ? "" : "0x"}${t.address}" })`);
        Qt.callLater(Hyprland.refreshToplevels);
    }

    // Dimmed, blurred desktop
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.open ? 0.38 : 0
        Behavior on opacity { NumberAnimation { duration: 240 } }
    }
    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()
    }

    // ---------- desktops bar ----------
    Row {
        id: spaces
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.open ? 18 : -height - 10
        Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        spacing: 16
        readonly property real tileW: Math.min(180, root.width / 9)
        readonly property real tileH: tileW * root.height / root.width

        Repeater {
            model: root.desktops
            Item {
                id: desk
                required property int modelData
                readonly property bool current: modelData === root.wsId
                readonly property bool dropTarget: dragHover === modelData
                width: spaces.tileW
                height: spaces.tileH + 20

                Rectangle {
                    id: deskFrame
                    width: parent.width
                    height: spaces.tileH
                    radius: 8
                    color: "black"
                    clip: true
                    border.width: desk.current || desk.dropTarget ? 3 : 0
                    border.color: desk.dropTarget ? Theme.accent : "white"
                    Image {
                        anchors.fill: parent
                        anchors.margins: parent.border.width
                        source: "file://" + Settings.wallpaper
                        sourceSize: Qt.size(320, 200)
                        fillMode: Image.PreserveAspectCrop
                    }
                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Repeater {
                            model: Hyprland.toplevels.values.filter(t => t.workspace?.id === desk.modelData && t.wayland && !t.wayland.parent).slice(0, 5)
                            Image {
                                required property var modelData
                                width: 24; height: 24
                                sourceSize: Qt.size(48, 48)
                                source: Apps.iconFor(Apps.idForToplevel(modelData.wayland))
                            }
                        }
                    }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    text: "Desktop " + desk.modelData
                    color: "white"
                    font.pixelSize: 11
                    font.weight: desk.current ? Font.DemiBold : Font.Normal
                }
                MouseArea {
                    anchors.fill: deskFrame
                    onClicked: Hypr.workspace(desk.modelData)
                }
            }
        }

        // New desktop
        Rectangle {
            width: spaces.tileH * 0.7
            height: spaces.tileH
            radius: 8
            color: Qt.rgba(1, 1, 1, addMouse.containsMouse ? 0.28 : 0.16)
            Icon { anchors.centerIn: parent; size: 20; name: "plus"; color: "white" }
            MouseArea {
                id: addMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Hypr.workspace(Math.max(...root.desktops, 0) + 1)
            }
        }
    }

    // Which desktop a dragged window is over (-1 = none).
    property int dragHover: -1
    function desktopAt(x, y) {
        for (let i = 0; i < spaces.children.length; i++) {
            const c = spaces.children[i];
            if (c.modelData === undefined) continue;
            const p = c.mapToItem(null, 0, 0);
            if (x >= p.x && x <= p.x + c.width && y >= p.y && y <= p.y + c.height) return c.modelData;
        }
        return -1;
    }

    // ---------- windows ----------
    Item {
        id: area
        x: 40
        y: spaces.tileH + 70
        width: root.width - 80
        height: root.height - y - 50

        readonly property int n: root.windows.length
        readonly property int cols: Math.max(1, Math.ceil(Math.sqrt(n * (width / height) / 1.5)))
        readonly property int rows: Math.max(1, Math.ceil(n / cols))
        readonly property real cellW: width / cols
        readonly property real cellH: height / rows

        Label {
            anchors.centerIn: parent
            visible: area.n === 0 && root.open
            text: "No windows on this desktop"
            color: Qt.rgba(1, 1, 1, 0.7)
            font.pixelSize: 15
        }

        Repeater {
            model: root.windows
            Item {
                id: win
                required property var modelData
                required property int index
                readonly property var ipc: modelData.lastIpcObject
                readonly property real realW: ipc.size[0]
                readonly property real realH: ipc.size[1]
                readonly property real realX: ipc.at[0] - (root.monitor?.x ?? 0) - area.x
                readonly property real realY: ipc.at[1] - (root.monitor?.y ?? 0) - area.y

                // Grid slot (rows are centered when the last one isn't full).
                readonly property int col: index % area.cols
                readonly property int row: Math.floor(index / area.cols)
                readonly property int inRow: row === area.rows - 1 ? area.n - row * area.cols : area.cols
                readonly property real fit: Math.min(1, area.cellW * 0.86 / realW, (area.cellH - 30) * 0.9 / realH)
                readonly property real gridW: realW * fit
                readonly property real gridH: realH * fit
                readonly property real gridX: (area.width - inRow * area.cellW) / 2 + col * area.cellW + (area.cellW - gridW) / 2
                readonly property real gridY: row * area.cellH + (area.cellH - 30 - gridH) / 2

                property bool dragging: false
                property real dragX
                property real dragY
                x: dragging ? dragX : (root.open ? gridX : realX)
                y: dragging ? dragY : (root.open ? gridY : realY)
                width: dragging ? gridW * 0.5 : (root.open ? gridW : realW)
                height: dragging ? gridH * 0.5 : (root.open ? gridH : realH)
                z: dragging ? 10 : 0
                Behavior on x { enabled: !win.dragging; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: !win.dragging; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: 14
                    color: "transparent"
                    border.width: 3
                    border.color: Theme.accent
                    visible: hover.containsMouse && !win.dragging
                }
                ScreencopyView {
                    anchors.fill: parent
                    captureSource: root.visible ? win.modelData.wayland : null
                    live: true
                    layer.enabled: true
                    layer.smooth: true
                }
                Image {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.bottom
                    width: 44; height: 44
                    sourceSize: Qt.size(88, 88)
                    source: Apps.iconFor(Apps.idForToplevel(win.modelData.wayland))
                    opacity: root.open ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
                Rectangle {
                    visible: hover.containsMouse && !win.dragging
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: 26
                    width: Math.min(titleLabel.implicitWidth + 20, 320)
                    height: 24
                    radius: 12
                    color: Qt.rgba(0, 0, 0, 0.55)
                    Label {
                        id: titleLabel
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, 300)
                        text: win.modelData.title
                        color: "white"
                        font.pixelSize: 12
                    }
                }
                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    drag.threshold: 8
                    property point grab
                    property bool moved: false
                    onPressed: m => { grab = Qt.point(m.x, m.y); moved = false; }
                    onPositionChanged: m => {
                        if (!pressed) return;
                        if (!win.dragging && Math.hypot(m.x - grab.x, m.y - grab.y) > 8) win.dragging = true;
                        if (win.dragging) {
                            const p = mapToItem(area, m.x, m.y);
                            win.dragX = p.x - win.width / 2;
                            win.dragY = p.y - win.height / 2;
                            const g = mapToItem(null, m.x, m.y);
                            root.dragHover = root.desktopAt(g.x, g.y);
                        }
                    }
                    onReleased: {
                        moved = win.dragging;
                        if (win.dragging) {
                            win.dragging = false;
                            if (root.dragHover > 0 && root.dragHover !== root.wsId) root.moveTo(win.modelData, root.dragHover);
                            root.dragHover = -1;
                        }
                    }
                    onClicked: if (!moved) root.go(win.modelData)
                }
            }
        }
    }
}
