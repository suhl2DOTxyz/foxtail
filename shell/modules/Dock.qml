import QtQuick
import Quickshell.Io
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// The Dock. Pinned apps, then running apps that aren't pinned, then Trash.
// Hover magnification follows the pointer like macOS's; launching bounces the
// icon until the app's first window appears; a dot marks running apps and a
// red badge counts its notifications. Drag pinned apps to reorder them, or
// up and out of the Dock to remove them. Downloads sits beside the Trash.
PanelWindow {
    id: dock

    required property var modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "foxtail-dock"
    exclusionMode: ExclusionMode.Normal
    anchors { bottom: true; left: true; right: true }
    color: "transparent"

    readonly property real iconSize: Settings.dockIconSize
    readonly property real magnify: Settings.dockMagnification ? Settings.dockMagnifySize : 1.0
    readonly property real pad: Math.round(iconSize * 0.14)
    readonly property real spacing: Math.round(iconSize * 0.08)
    readonly property real bottomGap: 6
    readonly property real bodyHeight: iconSize + pad * 2

    implicitHeight: iconSize * magnify + pad * 2 + bottomGap + 40
    exclusiveZone: Settings.dockAutoHide ? 0 : bodyHeight + bottomGap

    readonly property bool hovered: hover.hovered
    readonly property bool shown: !Settings.dockAutoHide || hovered || Panels.popover === "dockmenu"

    // Input only where the Dock actually is; the rest of the strip passes through.
    mask: Region { item: hitArea }

    Item {
        id: hitArea
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: body.width
        height: !dock.shown ? 4 : (dock.hovered ? dock.height : dock.bodyHeight + dock.bottomGap)
        HoverHandler { id: hover }
    }

    // ---- model ----
    readonly property var items: {
        const out = [];
        const pinned = Settings.pinnedApps;
        for (let i = 0; i < pinned.length; i++) {
            out.push({ kind: "app", id: pinned[i] });
            if (i === 0) out.push({ kind: "launchpad", id: "launchpad" });
        }
        if (Apps.unpinnedRunning.length) {
            out.push({ kind: "sep", id: "sep1" });
            for (const id of Apps.unpinnedRunning) out.push({ kind: "app", id });
        }
        out.push({ kind: "sep", id: "sep2" });
        // Minimized windows sit between the separator and Trash, as on macOS.
        for (const t of Hypr.minimized)
            out.push({ kind: "min", id: "min:" + t.address, toplevel: t });
        out.push({ kind: "downloads", id: "downloads" });
        out.push({ kind: "trash", id: "trash" });
        return out;
    }

    // ---- Trash and Downloads ----
    // Whether the Trash has anything in it. Emptying the Trash removes its
    // folder, which a folder model can't follow, so check every few seconds
    // (and right away after Move to Trash / Empty Trash).
    property bool trashFull: false
    Process {
        id: trashCheck
        command: ["sh", "-c", 'test -n "$(ls -A "$HOME/.local/share/Trash/files" 2>/dev/null)"']
        onExited: code => dock.trashFull = code === 0
    }
    Timer {
        interval: 4000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: trashCheck.running = true
    }
    Connections {
        target: Sounds
        function onPlayed(kind) { if (kind === "trash") recheck.restart(); }
    }
    Timer { id: recheck; interval: 600; onTriggered: trashCheck.running = true }

    // ---- reordering: drag a pinned app along the Dock, or out to remove ----
    property string dragId: ""
    property point dragPos: Qt.point(0, 0)      // pointer, in window coordinates
    readonly property bool dragOut: dragId !== "" && dragPos.y < body.y - iconSize * 0.9
    property bool justDragged: false
    function dropIndex() {
        // Insertion point among the pinned apps (in un-magnified coordinates).
        const bx = (dragPos.x - body.x) / body.width * baseWidth;
        let n = 0;
        for (let i = 0; i < items.length; i++) {
            if (items[i].kind !== "app" || Settings.pinnedApps.indexOf(items[i].id) < 0) continue;
            if (bx > baseCenters[i]) n = Settings.pinnedApps.indexOf(items[i].id) + 1;
        }
        return n;
    }
    function finishDrag() {
        const id = dragId;
        dragId = "";
        justDragged = true;
        clearJustDragged.restart();
        if (dragOut) {
            if (id !== "org.gnome.Nautilus") Apps.unpin(id);   // Files stays, like Finder
            return;
        }
        const list = Settings.pinnedApps.filter(p => p !== id);
        let at = dropIndex();
        if (Settings.pinnedApps.indexOf(id) < at) at--;
        list.splice(Math.max(0, Math.min(at, list.length)), 0, id);
        Settings.pinnedApps = list;
    }
    Timer { id: clearJustDragged; interval: 50; onTriggered: dock.justDragged = false }

    // An app asking for attention bounces its icon, as on macOS.
    signal attention(string appId)
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "urgent") return;
            const t = Hyprland.toplevels.values.find(t => t.address.replace(/^0x/, "") === event.data.replace(/^0x/, ""));
            if (t?.wayland && !t.wayland.activated) {
                dock.attention(Apps.idForToplevel(t.wayland));
                Sounds.play("attention");
            }
        }
    }

    // Un-magnified centers, used to compute magnification without feedback.
    readonly property var baseCenters: {
        const c = [];
        let x = pad;
        for (const it of items) {
            const w = it.kind === "sep" ? 13 : iconSize;
            c.push(x + w / 2);
            x += w + spacing;
        }
        return c;
    }
    readonly property real baseWidth: {
        let x = pad * 2 - spacing;
        for (const it of items) x += (it.kind === "sep" ? 13 : iconSize) + spacing;
        return x;
    }

    property real pointerX: -1000  // in base coordinates

    function scaleAt(i) {
        if (!hovered || magnify <= 1.0) return 1.0;
        const d = Math.abs(pointerX - baseCenters[i]);
        const range = iconSize * 2.6;
        if (d >= range) return 1.0;
        return 1.0 + (magnify - 1.0) * (Math.cos(Math.PI * d / range) + 1) / 2;
    }

    // ---- body ----
    Item {
        id: body
        anchors.horizontalCenter: parent.horizontalCenter
        width: row.width + dock.pad * 2
        height: dock.bodyHeight
        y: dock.height - height - dock.bottomGap + (dock.shown ? 0 : dock.bodyHeight + dock.bottomGap + 4)
        Behavior on y { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

        Glass {
            id: dockGlass
            anchors.fill: parent
            radius: Theme.liquid ? Math.round(dock.bodyHeight * 0.42) : 18
            // The highlight slides along the Dock with the pointer.
            pointer: dockHover.hovered ? Qt.point(dockHover.point.position.x / width, -0.6) : Qt.point(-1, -1)
            screenSize: Qt.size(dock.width, dock.screen.height)
            windowOffset: Qt.point(0, dock.screen.height - dock.height)
            bezel: 20
            refraction: 16
            adapt: 0.35   // icons, not text: let the wallpaper's color through
        }

        HoverHandler {
            id: dockHover
            target: null
            onPointChanged: {
                // Map pointer back to base (un-magnified) coordinates.
                const px = point.position.x;
                dock.pointerX = px / body.width * dock.baseWidth;
            }
        }
    }

    Row {
        id: row
        anchors.bottom: body.bottom
        anchors.bottomMargin: dock.pad
        anchors.horizontalCenter: body.horizontalCenter
        spacing: dock.spacing

        Repeater {
            model: dock.items

            Item {
                id: cell
                required property var modelData
                required property int index
                readonly property real s: modelData.kind === "sep" ? 1.0 : dock.scaleAt(index)
                readonly property bool running: modelData.kind === "app" && Apps.isRunning(modelData.id)

                width: modelData.kind === "sep" ? 13 : dock.iconSize * s
                height: dock.iconSize

                Accessible.role: modelData.kind === "sep" ? Accessible.Separator : Accessible.Button
                Accessible.name: modelData.kind === "trash" ? I18n.tr("Trash")
                    : modelData.kind === "downloads" ? I18n.tr("Downloads")
                    : modelData.kind === "launchpad" ? I18n.tr("Apps")
                    : modelData.kind === "min" ? (modelData.toplevel.title || "Window")
                    : modelData.kind === "app" ? Apps.nameFor(modelData.id) : ""
                Accessible.description: running ? I18n.tr("Running") : ""
                Behavior on width { enabled: !dock.hovered; NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

                // Separator
                Rectangle {
                    visible: cell.modelData.kind === "sep"
                    anchors.centerIn: parent
                    width: 1
                    height: dock.iconSize * 0.8
                    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.25) : Qt.rgba(0, 0, 0, 0.18)
                }

                Item {
                    id: iconBox
                    visible: cell.modelData.kind !== "sep"
                    width: dock.iconSize * cell.s
                    height: width
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    property real bounce: 0
                    transform: Translate { y: -iconBox.bounce }

                    // Minimized window: a small "window" card carrying the app icon.
                    Rectangle {
                        visible: cell.modelData.kind === "min"
                        anchors.fill: parent
                        anchors.margins: parent.width * 0.08
                        radius: width * 0.16
                        color: Theme.dark ? "#2C2C2E" : "#FFFFFF"
                        border.color: Theme.separator
                        Rectangle {   // title bar strip with traffic lights
                            width: parent.width; height: parent.height * 0.18
                            radius: parent.radius
                            color: Theme.dark ? "#3A3A3C" : "#ECECEE"
                            Row {
                                x: parent.width * 0.1
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: parent.height * 0.25
                                Repeater {
                                    model: ["#FF5F57", "#FEBC2E", "#28C840"]
                                    Rectangle { required property string modelData; width: parent.parent.height * 0.42; height: width; radius: width / 2; color: modelData }
                                }
                            }
                        }
                    }

                    Image {
                        anchors.fill: parent
                        anchors.margins: cell.modelData.kind === "min" ? parent.width * 0.26 : 0
                        anchors.topMargin: cell.modelData.kind === "min" ? parent.width * 0.32 : 0
                        visible: cell.modelData.kind !== "launchpad"
                        sourceSize: Qt.size(dock.iconSize * dock.magnify * 2, dock.iconSize * dock.magnify * 2)
                        smooth: true
                        mipmap: true
                        source: cell.modelData.kind === "trash"
                            ? Quickshell.iconPath(dock.trashFull ? "user-trash-full" : "user-trash", "user-trash")
                            : cell.modelData.kind === "downloads"
                            ? Quickshell.iconPath("folder-download", "folder")
                            : cell.modelData.kind === "min"
                                ? Apps.iconFor(Apps.idForToplevel(cell.modelData.toplevel.wayland))
                                : Apps.iconFor(cell.modelData.id)
                        opacity: dock.dragId === cell.modelData.id ? 0.25 : (press.pressed ? 0.7 : 1)
                    }

                    // Red badge: unread notifications from this app.
                    Rectangle {
                        readonly property int count: cell.modelData.kind === "app" ? Notifs.countFor(cell.modelData.id) : 0
                        visible: count > 0
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.rightMargin: -parent.width * 0.06
                        anchors.topMargin: -parent.width * 0.06
                        width: Math.max(height, badgeLabel.implicitWidth + 10)
                        height: Math.round(parent.width * 0.38)
                        radius: height / 2
                        color: "#FF3B30"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.5)
                        Text {
                            id: badgeLabel
                            anchors.centerIn: parent
                            text: parent.count > 99 ? "99+" : parent.count
                            color: "white"
                            font.family: Theme.font
                            font.pixelSize: Math.round(parent.height * 0.6)
                            font.weight: Font.DemiBold
                        }
                    }

                    // Launchpad tile drawn in QML: a glass rounded square with a grid of dots.
                    Rectangle {
                        visible: cell.modelData.kind === "launchpad"
                        anchors.fill: parent
                        anchors.margins: parent.width * 0.06
                        radius: width * 0.23
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#FFB15C" }
                            GradientStop { position: 1; color: "#E5400A" }
                        }
                        Grid {
                            anchors.centerIn: parent
                            columns: 3
                            spacing: parent.width * 0.08
                            Repeater {
                                model: 9
                                Rectangle {
                                    width: iconBox.width * 0.14
                                    height: width
                                    radius: width * 0.3
                                    color: Qt.rgba(1, 1, 1, 0.92)
                                }
                            }
                        }
                    }

                    SequentialAnimation {
                        id: bounceAnim
                        loops: 3
                        NumberAnimation { target: iconBox; property: "bounce"; to: dock.iconSize * 0.45; duration: Theme.ms(260); easing.type: Easing.OutQuad }
                        NumberAnimation { target: iconBox; property: "bounce"; to: 0; duration: Theme.ms(260); easing.type: Easing.InQuad }
                    }
                }

                // Running indicator
                Rectangle {
                    visible: cell.running
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.bottom
                    anchors.topMargin: Math.max(1, dock.pad / 2 - 2)
                    width: 4; height: 4; radius: 2
                    color: Theme.dark ? Qt.rgba(1, 1, 1, 0.85) : Qt.rgba(0, 0, 0, 0.7)
                }

                // Tooltip
                Rectangle {
                    id: tip
                    visible: press.containsMouse && cell.modelData.kind !== "sep" && Panels.popover !== "dockmenu"
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: iconBox.top
                    anchors.bottomMargin: 12
                    width: tipLabel.implicitWidth + 22
                    height: 26
                    radius: Theme.liquid ? 13 : 6
                    color: Theme.glassStrong
                    border.color: Theme.glassOutline
                    Label {
                        id: tipLabel
                        anchors.centerIn: parent
                        text: cell.modelData.kind === "trash" ? I18n.tr("Trash")
                            : cell.modelData.kind === "downloads" ? I18n.tr("Downloads")
                            : cell.modelData.kind === "launchpad" ? I18n.tr("Apps")
                            : cell.modelData.kind === "min" ? (cell.modelData.toplevel.title || "Window")
                            : Apps.nameFor(cell.modelData.id)
                    }
                }

                MouseArea {
                    id: press
                    anchors.fill: parent
                    enabled: cell.modelData.kind !== "sep"
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    property point pressAt
                    onPressed: m => pressAt = Qt.point(m.x, m.y)
                    onPositionChanged: m => {
                        const it = cell.modelData;
                        if (!(pressedButtons & Qt.LeftButton) || it.kind !== "app" || Settings.pinnedApps.indexOf(it.id) < 0) return;
                        if (dock.dragId === "" && Math.hypot(m.x - pressAt.x, m.y - pressAt.y) < 8) return;
                        dock.dragId = it.id;
                        dock.dragPos = mapToItem(null, m.x, m.y);
                    }
                    onReleased: if (dock.dragId === cell.modelData.id) dock.finishDrag()
                    onClicked: m => {
                        const it = cell.modelData;
                        if (dock.justDragged) return;
                        if (m.button === Qt.RightButton && it.kind === "trash") {
                            const p = cell.mapToItem(null, cell.width / 2, 0);
                            Panels.showContext([
                                { text: I18n.tr("Open"), action: () => Quickshell.execDetached(["nautilus", "trash:///"]) },
                                { separator: true },
                                { text: I18n.tr("Empty Trash"), enabled: dock.trashFull, action: () => Panels.confirm = "emptyTrash" }
                            ], p.x - 90, dock.screen.height - Settings.dockIconSize - 110, dock.modelData);
                            return;
                        }
                        if (it.kind === "downloads") {
                            const p = cell.mapToItem(null, cell.width / 2, 0);
                            Panels.downloadsX = p.x;
                            Panels.toggle("downloads", dock.modelData);
                            return;
                        }
                        if (m.button === Qt.RightButton && it.kind === "app") {
                            const p = cell.mapToItem(null, cell.width / 2, 0);
                            Panels.dockMenuApp = it.id;
                            Panels.dockMenuX = p.x;
                            Panels.toggle("dockmenu", dock.modelData);
                            return;
                        }
                        Panels.closeAll();
                        if (it.kind === "launchpad") {
                            Panels.launchpad = true;
                        } else if (it.kind === "min") {
                            Hypr.restore(it.toplevel);
                        } else if (it.kind === "trash") {
                            Quickshell.execDetached(["nautilus", "trash:///"]);
                        } else if (!Apps.activate(it.id) && it.id !== "foxtail-settings") {
                            bounceAnim.restart();
                        }
                    }
                }

                // Files dragged from the desktop and let go over this item:
                // onto the Trash to trash them, onto Downloads to move them
                // there, onto an app to open them with it. (Hyprland doesn't
                // deliver drags to the Dock's layer, so the desktop reports
                // where its drags end - see Desktop.qml.)
                Connections {
                    target: Panels
                    function onFileDragEnded(uris, x, y) {
                        const it = cell.modelData;
                        if (["trash", "app", "downloads"].indexOf(it.kind) < 0) return;
                        const p = cell.mapToItem(null, 0, 0);
                        const top = dock.screen.height - dock.height;
                        if (x < p.x || x >= p.x + cell.width || y < top + p.y - 8 || y >= top + p.y + cell.height + 8) return;
                        if (it.kind === "trash") {
                            Quickshell.execDetached(["gio", "trash", "--"].concat(uris));
                            Sounds.play("trash");
                        } else if (it.kind === "downloads") {
                            Quickshell.execDetached(["gio", "move", "--"].concat(uris, [Quickshell.env("HOME") + "/Downloads/"]));
                        } else {
                            Quickshell.execDetached(["gtk-launch", it.id].concat(uris));
                        }
                    }
                }

                Connections {
                    target: dock
                    function onAttention(appId) {
                        if (cell.modelData.kind === "app" && cell.modelData.id === appId) bounceAnim.restart();
                    }
                }

                Connections {
                    target: Apps
                    function onToplevelsChanged() {
                        if (cell.running && bounceAnim.running) {
                            bounceAnim.stop();
                            iconBox.bounce = 0;
                        }
                    }
                }
            }
        }
    }

    // The app being dragged follows the pointer; "Remove" once it's pulled
    // far enough out of the Dock.
    Item {
        visible: dock.dragId !== ""
        x: dock.dragPos.x - width / 2
        y: dock.dragPos.y - height / 2
        width: dock.iconSize
        height: dock.iconSize
        z: 100
        Image {
            anchors.fill: parent
            sourceSize: Qt.size(dock.iconSize * 2, dock.iconSize * 2)
            source: dock.dragId ? Apps.iconFor(dock.dragId) : ""
            opacity: dock.dragOut ? 0.6 : 1
        }
        Rectangle {
            visible: dock.dragOut && dock.dragId !== "org.gnome.Nautilus"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: 6
            width: removeLabel.implicitWidth + 18
            height: 22
            radius: 11
            color: Theme.glassStrong
            border.color: Theme.glassOutline
            Label { id: removeLabel; anchors.centerIn: parent; text: I18n.tr("Remove"); font.pixelSize: Theme.px(12) }
        }
    }
}
