import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// Files on the desktop, as on macOS: the Desktop folder shown on the
// wallpaper, arranged in a grid from the top-right corner. Click to select
// (⇧/⌃-click to add), drag to move, drag on empty space to select several,
// double-click to open, Return to rename, ⌫ or ⌘⌫ to move to the Trash.
// Right-click for New Folder, Get Info, Change Wallpaper, Clean Up, Sort By.
//
// Dragging is real drag and drop: icons can be dropped into Files windows,
// onto folders on the desktop, or onto the Dock's Trash and apps, and files
// dragged out of Files land on the desktop where they're dropped.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // Desktop items live on the main display, like macOS.
    readonly property bool primary: modelData === Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "foxtail-desktop"
    // Clicking the desktop makes it the front "app" (Panels.desktopActive) and
    // gives it the keyboard, so Return, ⌫ and Escape work: it grabs the
    // keyboard for a moment, then keeps it on demand (exclusive focus would
    // keep drags from reaching windows). Otherwise it takes no keyboard at
    // all, so closing a menu doesn't hand the keyboard to the desktop. A click
    // on a window ends it (hypr/foxtail.lua: desktopBlur).
    property bool grabKeyboard: false
    WlrLayershell.keyboardFocus: !primary || !(Panels.desktopActive || renaming !== "") ? WlrKeyboardFocus.None
                               : grabKeyboard || renaming !== "" ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    Timer { id: releaseGrab; interval: 150; onTriggered: root.grabKeyboard = false }
    exclusionMode: ExclusionMode.Normal
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    // ---------------- the Desktop folder ----------------
    property string dir: ""
    Process {
        running: true
        command: ["xdg-user-dir", "DESKTOP"]
        stdout: StdioCollector {
            onStreamFinished: {
                const d = text.trim();
                const home = Quickshell.env("HOME");
                // No desktop folder configured: xdg-user-dir answers $HOME,
                // and showing the whole home folder would be wrong.
                root.dir = d && d !== home && d !== home + "/" ? d : home + "/Desktop";
            }
        }
    }

    FolderListModel {
        id: folder
        // Until the Desktop folder is known, point nowhere (an empty folder
        // would mean the current directory).
        folder: root.dir ? "file://" + root.dir : "file:///nonexistent"
        showDirsFirst: false
        showHidden: false
        showDotAndDotDot: false
        sortField: FolderListModel.Name
    }
    Connections {
        target: folder
        function onCountChanged() { Qt.callLater(root.rebuild); }
        function onStatusChanged() { Qt.callLater(root.rebuild); }
        function onDataChanged() { Qt.callLater(root.rebuild); }
        function onRowsInserted() { Qt.callLater(root.rebuild); }
        function onRowsRemoved() { Qt.callLater(root.rebuild); }
    }

    Connections {
        target: Panels
        function onDesktopNewFolder() { if (root.primary) root.newFolder(); }
    }

    // Saved grid positions (slot per file name), kept across sessions.
    FileView {
        id: store
        path: Settings.dir + "/desktop.json"
        onAdapterUpdated: writeAdapter()
        onLoaded: { root.positionsLoaded = true; Qt.callLater(root.relayout); }
        onLoadFailed: error => {
            root.positionsLoaded = true;
            if (error === FileViewError.FileNotFound) writeAdapter();
            Qt.callLater(root.relayout);
        }
        JsonAdapter {
            id: saved
            property var positions: ({})
        }
    }

    property var files: []
    // Don't lay out (and save) icon positions before the saved ones are read.
    property bool positionsLoaded: false
    function rebuild() {
        const out = [];
        if (!root.dir) { files = []; return; }
        for (let i = 0; i < folder.count; i++) {
            const name = String(folder.get(i, "fileName"));
            const dot = name.lastIndexOf(".");
            out.push({
                name: name,
                path: folder.get(i, "filePath"),
                isDir: folder.get(i, "fileIsDir"),
                suffix: dot > 0 ? name.slice(dot + 1).toLowerCase() : "",
                modified: folder.get(i, "fileModified")
            });
        }
        files = out;
        relayout();
        // Forget selections of files that are gone.
        const keep = {};
        for (const f of out) if (selected[f.name]) keep[f.name] = true;
        selected = keep;
        if (pendingRename && out.some(f => f.name === pendingRename)) {
            selected = { [pendingRename]: true };
            renaming = pendingRename;
            pendingRename = "";
        }
    }

    // ---------------- grid ----------------
    readonly property real cellW: 104
    readonly property real cellH: 102
    readonly property real marginTop: 10
    readonly property real marginRight: 12
    readonly property int rows: Math.max(1, Math.floor((height - marginTop - 6) / cellH))

    function slotCol(s) { return Math.floor(s / rows); }
    function slotRow(s) { return s % rows; }
    function slotX(s) { return width - marginRight - (slotCol(s) + 1) * cellW; }
    function slotY(s) { return marginTop + slotRow(s) * cellH; }
    function slotAt(x, y) {
        const c = Math.max(0, Math.round((width - marginRight - cellW - x) / cellW));
        const r = Math.max(0, Math.min(rows - 1, Math.round((y - marginTop) / cellH)));
        return c * rows + r;
    }

    property var slots: ({})
    function ordered() {
        const list = files.slice();
        const byName = (a, b) => a.name.localeCompare(b.name, undefined, { numeric: true, sensitivity: "base" });
        switch (Settings.desktopSort) {
        case "kind":
            return list.sort((a, b) => (b.isDir - a.isDir) || a.suffix.localeCompare(b.suffix) || byName(a, b));
        case "date":
            return list.sort((a, b) => (b.modified?.getTime?.() ?? 0) - (a.modified?.getTime?.() ?? 0) || byName(a, b));
        default:
            return list.sort(byName);
        }
    }
    function relayout() {
        if (!positionsLoaded) return;
        const order = ordered();
        const free = Settings.desktopSort === "none";
        const pos = free ? (saved.positions ?? {}) : {};
        const used = {};
        const out = {};
        for (const f of order) {
            const s = pos[f.name];
            if (s !== undefined && !used[s]) { out[f.name] = s; used[s] = true; }
        }
        let next = 0;
        for (const f of order) {
            if (out[f.name] !== undefined) continue;
            while (used[next]) next++;
            out[f.name] = next;
            used[next] = true;
        }
        slots = out;
        // Remember where everything landed, so icons stay put when others
        // come and go.
        if (free && JSON.stringify(out) !== JSON.stringify(saved.positions ?? {}))
            saved.positions = out;
    }
    Connections {
        target: Settings
        function onDesktopSortChanged() { root.relayout(); }
    }
    onRowsChanged: relayout()

    // Clean Up: close the gaps, keeping the current order.
    function cleanUp() {
        const names = Object.keys(slots).sort((a, b) => slots[a] - slots[b]);
        const out = {};
        names.forEach((n, i) => out[n] = i);
        Settings.desktopSort = "none";
        saved.positions = out;
        slots = out;
    }

    // ---------------- selection ----------------
    property var selected: ({})
    readonly property var selectedNames: Object.keys(selected)
    function select(name, add) {
        const s = add ? Object.assign({}, selected) : {};
        if (add && s[name]) delete s[name]; else s[name] = true;
        selected = s;
    }
    function pathOf(name) { return root.dir + "/" + name; }
    function selectedPaths() { return selectedNames.map(pathOf); }

    // ---------------- actions ----------------
    function open(paths) {
        for (const p of paths) Quickshell.execDetached(["xdg-open", p]);
    }
    function trash(paths) {
        if (!paths.length) return;
        Quickshell.execDetached(["gio", "trash", "--"].concat(paths));
        Sounds.play("trash");
        selected = {};
    }
    function fileUris(paths) {
        return paths.map(p => "file://" + encodeURI(p).replace(/\?/g, "%3F").replace(/#/g, "%23"));
    }
    // Get Info and Show in Files go through the file manager's D-Bus API.
    function fileManager(method, paths) {
        Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.freedesktop.FileManager1",
                                 "--object-path", "/org/freedesktop/FileManager1",
                                 "--method", "org.freedesktop.FileManager1." + method,
                                 JSON.stringify(fileUris(paths)).replace(/"/g, "'"), ""]);
    }
    property string pendingRename: ""
    function newFolder() {
        let name = "untitled folder";
        const names = files.map(f => f.name);
        for (let i = 2; names.indexOf(name) >= 0; i++) name = "untitled folder " + i;
        pendingRename = name;
        Quickshell.execDetached(["mkdir", "-p", "--", pathOf(name)]);
    }
    property string renaming: ""
    function finishRename(newName) {
        const old = renaming;
        renaming = "";
        newName = newName.trim().replace(/\//g, ":");
        if (!old || !newName || newName === old) return;
        // Keep the icon where it was under its new name.
        const pos = Object.assign({}, saved.positions ?? {});
        if (pos[old] !== undefined) { pos[newName] = pos[old]; delete pos[old]; saved.positions = pos; }
        selected = { [newName]: true };
        Quickshell.execDetached(["mv", "-n", "--", pathOf(old), pathOf(newName)]);
    }

    function iconMenu(name) {
        const paths = selected[name] ? selectedPaths() : [pathOf(name)];
        if (!selected[name]) selected = { [name]: true };
        const one = paths.length === 1;
        return [
            { text: I18n.tr("Open"), action: () => root.open(paths) },
            { separator: true },
            { text: I18n.tr("Move to Trash"), shortcut: "⌘⌫", action: () => root.trash(paths) },
            { separator: true },
            { text: I18n.tr("Get Info"), shortcut: "⌘I", action: () => root.fileManager("ShowItemProperties", paths) },
            { text: I18n.tr("Rename"), enabled: one, action: () => root.renaming = name },
            { text: I18n.tr("Show in Files"), action: () => root.fileManager("ShowItems", paths) },
            { separator: true },
            { text: I18n.tr("Copy"), shortcut: "⌘C", action: () => Quickshell.execDetached(["wl-copy", "-t", "text/uri-list", fileUris(paths).join("\r\n")]) }
        ];
    }
    function desktopMenu() {
        const sort = v => () => { Settings.desktopSort = v; };
        return [
            { text: I18n.tr("New Folder"), shortcut: "⇧⌘N", action: () => root.newFolder() },
            { separator: true },
            { text: I18n.tr("Get Info"), action: () => root.fileManager("ShowItemProperties", [root.dir]) },
            { separator: true },
            { text: I18n.tr("Change Wallpaper…"), action: () => Panels.openSettings("wallpaper") },
            { separator: true },
            { text: I18n.tr("Clean Up"), enabled: Settings.desktopSort === "none", action: () => root.cleanUp() },
            { text: I18n.tr("Sort By"), submenu: [
                { text: I18n.tr("None"), checkable: true, checked: Settings.desktopSort === "none", action: sort("none") },
                { separator: true },
                { text: I18n.tr("Name"), checkable: true, checked: Settings.desktopSort === "name", action: sort("name") },
                { text: I18n.tr("Kind"), checkable: true, checked: Settings.desktopSort === "kind", action: sort("kind") },
                { text: I18n.tr("Date Modified"), checkable: true, checked: Settings.desktopSort === "date", action: sort("date") }
            ] },
            { separator: true },
            { text: I18n.tr("Show Desktop in Files"), action: () => Quickshell.execDetached(["xdg-open", root.dir]) }
        ];
    }
    function contextAt(model, x, y) {
        const p = Qt.point(x, y);
        // The overlay covers the whole screen; this window starts below the menu bar.
        Panels.showContext(model, p.x + root.screenOffset.x, p.y + root.screenOffset.y, root.modelData);
    }
    // This surface sits inside the reserved menu bar / Dock area.
    readonly property point screenOffset: Qt.point(0, Theme.menuBarHeight)

    // ---------------- drag and drop ----------------
    // `dragging` is the icon under the pointer when a drag started; the
    // selection moves with it. dragDx/dragDy follow the pointer while it is
    // over the desktop.
    property string dragging: ""
    property real dragDx: 0
    property real dragDy: 0
    property point dragFrom: Qt.point(0, 0)
    property url dragImage

    function startDrag(name, from) {
        grabKeyboard = false;      // an exclusive grab would block the drag
        dragging = name;
        dragFrom = from;
        dragDx = 0;
        dragDy = 0;
        dragProxy.uris = fileUris(selected[name] ? selectedPaths() : [pathOf(name)]);
        dragProxy.Drag.imageSource = dragImage;
        dragProxy.Drag.active = true;
    }
    function endDrag() {
        dragProxy.Drag.active = false;
        dragging = "";
        dragDx = 0;
        dragDy = 0;
    }

    // The platform drag (Wayland data device): other apps see the files as
    // text/uri-list, like a drag out of Files.
    Item {
        id: dragProxy
        property var uris: []
        Drag.dragType: Drag.Automatic
        // Matched by DropAreas in the shell itself (the Dock); other apps go by
        // the mime type.
        Drag.keys: ["text/uri-list"]
        Drag.supportedActions: Qt.MoveAction | Qt.CopyAction | Qt.LinkAction
        Drag.proposedAction: Qt.MoveAction
        Drag.hotSpot: Qt.point(32, 32)
        Drag.mimeData: ({ "text/uri-list": uris.join("\r\n") + "\r\n" })
        Drag.onDragFinished: action => {
            // Nobody took the files: maybe they were let go over the Dock.
            if (action === Qt.IgnoreAction) {
                pointerAt.uris = uris;
                pointerAt.running = true;
            }
            root.endDrag();
        }
    }

    Process {
        id: pointerAt
        property var uris: []
        command: ["hyprctl", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = /(-?[\d.]+),\s*(-?[\d.]+)/.exec(text);
                if (m) Panels.fileDragEnded(pointerAt.uris, parseFloat(m[1]) - root.screen.x, parseFloat(m[2]) - root.screen.y);
            }
        }
    }

    // Name of the desktop folder at a point, if any.
    function folderAt(x, y) {
        for (const f of files) {
            if (!f.isDir) continue;
            const s = slots[f.name];
            const fx = slotX(s) + 18, fy = slotY(s) + 4;
            if (x >= fx && x < fx + cellW - 36 && y >= fy && y < fy + cellH - 8) return f.name;
        }
        return "";
    }

    // Moves files (paths) into a folder, like a drop in Files: same disk moves,
    // another disk copies.
    function moveInto(dir, paths) {
        if (!paths.length) return;
        Quickshell.execDetached(["sh", "-c",
            'dest=$1; shift; for f; do if [ "$(stat -c %d "$f")" = "$(stat -c %d "$dest")" ]; then gio move -- "$f" "$dest/"; else gio copy -r -- "$f" "$dest/"; fi; done',
            "sh", dir].concat(paths));
    }

    DropArea {
        id: dropZone
        anchors.fill: parent
        keys: ["text/uri-list"]
        property string target: ""      // folder being hovered
        onPositionChanged: drag => {
            if (root.dragging) {
                root.dragDx = drag.x - root.dragFrom.x;
                root.dragDy = drag.y - root.dragFrom.y;
            }
            const f = root.folderAt(drag.x, drag.y);
            target = f && !(root.dragging && (f === root.dragging || root.selected[f])) ? f : "";
        }
        onExited: target = ""
        onDropped: drop => {
            const folder = target;
            target = "";
            const paths = drop.urls.map(u => decodeURIComponent(String(u).replace(/^file:\/\//, "")));
            if (folder) {
                root.moveInto(root.pathOf(folder), paths.filter(p => p !== root.pathOf(folder)));
                drop.accept(Qt.MoveAction);
            } else if (root.dragging) {
                // Rearranging icons on the desktop.
                root.dragDx = drop.x - root.dragFrom.x;
                root.dragDy = drop.y - root.dragFrom.y;
                root.dropAt(root.dragging);
                drop.accept(Qt.IgnoreAction);
            } else {
                // Files dragged in from elsewhere land where they're dropped.
                const start = root.slotAt(drop.x - root.cellW / 2, drop.y - root.cellH / 2);
                if (Settings.desktopSort === "none") {
                    const pos = Object.assign({}, saved.positions ?? {});
                    const taken = {};
                    for (const n of Object.keys(root.slots)) taken[root.slots[n]] = true;
                    let s = start;
                    for (const p of paths) {
                        while (taken[s]) s++;
                        pos[p.split("/").pop()] = s;
                        taken[s] = true;
                    }
                    saved.positions = pos;
                }
                root.moveInto(root.dir, paths.filter(p => p.slice(0, p.lastIndexOf("/")) !== root.dir));
                drop.accept(Qt.MoveAction);
            }
            root.dragging = "";
        }
    }

    function dropAt(name) {
        const from = slots[name];
        const target = slotAt(slotX(from) + dragDx, slotY(from) + dragDy);
        const dc = slotCol(target) - slotCol(from);
        const dr = slotRow(target) - slotRow(from);
        dragging = "";
        dragDx = 0;
        dragDy = 0;
        if (dc === 0 && dr === 0) return;
        const moving = selected[name] ? selectedNames : [name];
        const out = Object.assign({}, slots);
        const taken = {};
        for (const n of Object.keys(out)) if (moving.indexOf(n) < 0) taken[out[n]] = true;
        for (const n of moving) {
            let c = Math.max(0, slotCol(out[n]) + dc);
            let r = Math.max(0, Math.min(rows - 1, slotRow(out[n]) + dr));
            let s = c * rows + r;
            while (taken[s]) s++;
            out[n] = s;
            taken[s] = true;
        }
        Settings.desktopSort = "none";
        saved.positions = out;
        slots = out;
    }

    // ---------------- empty desktop: rubber band, right-click ----------------
    MouseArea {
        id: backdrop
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property point start
        property bool banding: false
        onPressed: m => {
            if (root.renaming) { root.renaming = ""; }
            if (m.button === Qt.RightButton) {
                root.activate();
                root.selected = {};
                root.contextAt(root.desktopMenu(), m.x, m.y);
                return;
            }
            Panels.closeAll();
            if (!(m.modifiers & (Qt.ShiftModifier | Qt.ControlModifier))) root.selected = {};
            start = Qt.point(m.x, m.y);
            banding = true;
            band.x = m.x; band.y = m.y; band.width = 0; band.height = 0;
        }
        onPositionChanged: m => {
            if (!banding) return;
            band.x = Math.min(start.x, m.x);
            band.y = Math.min(start.y, m.y);
            band.width = Math.abs(m.x - start.x);
            band.height = Math.abs(m.y - start.y);
            const sel = {};
            for (const f of root.files) {
                const s = root.slots[f.name];
                const x = root.slotX(s) + 18, y = root.slotY(s) + 4, w = root.cellW - 36, h = root.cellH - 8;
                if (x < band.x + band.width && x + w > band.x && y < band.y + band.height && y + h > band.y) sel[f.name] = true;
            }
            root.selected = sel;
        }
        onReleased: { banding = false; root.activate(); }
    }

    Rectangle {
        id: band
        visible: backdrop.banding && width > 2
        color: Qt.rgba(1, 1, 1, 0.18)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.7)
        radius: 2
    }

    // ---------------- keyboard ----------------
    // Clicking the desktop makes Files the front app (as Finder on macOS): the
    // menu bar shows Files, and ⌘ shortcuts act on desktop items instead of
    // the window that was in front (hypr/foxtail.lua checks foxtail_desktop).
    function activate() {
        if (!primary) return;
        if (!Panels.desktopActive) {
            grabKeyboard = true;
            releaseGrab.restart();
        }
        Panels.desktopActive = true;
        keys.forceActiveFocus();
    }
    Connections {
        target: Panels
        function onDesktopActiveChanged() {
            if (root.primary) Hypr.lua(`foxtail_desktop = ${Panels.desktopActive}`);
            if (!Panels.desktopActive) root.renaming = "";
        }
    }
    // Any window becoming active (⌘Tab, Dock, a click) ends desktop focus.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activewindowv2" && event.data && event.data !== "," && Panels.desktopActive)
                Panels.desktopActive = false;
        }
    }
    Connections {
        target: Panels
        function onDesktopKey(key) {
            if (!root.primary) return;
            const paths = root.selectedPaths();
            switch (key) {
            case "backspace": root.trash(paths); break;
            case "A": { const all = {}; for (const f of root.files) all[f.name] = true; root.selected = all; break; }
            case "I": if (paths.length) root.fileManager("ShowItemProperties", paths); break;
            case "O": case "down": root.open(paths); break;
            case "SHIFT+N": root.newFolder(); break;
            case "C": if (paths.length) Quickshell.execDetached(["wl-copy", "-t", "text/uri-list", root.fileUris(paths).join("\r\n")]); break;
            }
        }
    }

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => {
            if (root.renaming) return;
            const one = root.selectedNames.length === 1;
            if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && one) {
                root.renaming = root.selectedNames[0];
            } else if (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace) {
                root.trash(root.selectedPaths());
            } else if (e.key === Qt.Key_Down && (e.modifiers & Qt.ControlModifier)) {
                root.open(root.selectedPaths());       // ⌘↓ (sent as ⌃End by the ⌘ remap) - open
            } else if (e.key === Qt.Key_Escape) {
                root.selected = {};
            } else if (e.key === Qt.Key_A && (e.modifiers & Qt.ControlModifier)) {
                const all = {};
                for (const f of root.files) all[f.name] = true;
                root.selected = all;
            } else return;
            e.accepted = true;
        }
    }

    // ---------------- icons ----------------
    Repeater {
        model: root.primary && Settings.showDesktopItems ? root.files : []

        Item {
            id: cell
            required property var modelData
            readonly property string name: modelData.name
            readonly property int slot: root.slots[name] ?? 0
            readonly property bool isSelected: !!root.selected[name]
            readonly property bool moving: root.dragging !== "" && (root.dragging === name || (isSelected && !!root.selected[root.dragging]))

            x: root.slotX(slot) + (moving ? root.dragDx : 0)
            y: root.slotY(slot) + (moving ? root.dragDy : 0)
            z: moving ? 10 : 0
            width: root.cellW
            height: root.cellH
            Behavior on x { enabled: !cell.moving; NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            Behavior on y { enabled: !cell.moving; NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }
            opacity: moving ? 0.75 : 1

            // Selection: a soft dark rounded square behind the icon.
            Rectangle {
                visible: cell.isSelected || dropZone.target === cell.name
                anchors.horizontalCenter: parent.horizontalCenter
                y: 2
                width: 68; height: 68
                radius: 8
                color: dropZone.target === cell.name ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(0, 0, 0, 0.22)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.25)
            }

            FileIcon {
                id: icon
                anchors.horizontalCenter: parent.horizontalCenter
                y: 6
                size: 60
                file: cell.modelData
                path: root.pathOf(cell.name)
                uri: root.fileUris([root.pathOf(cell.name)])[0]
            }

            // Label: white on dark wallpapers, dark on light ones; an accent
            // pill when selected, as in Finder.
            Rectangle {
                visible: cell.isSelected && root.renaming !== cell.name
                anchors.horizontalCenter: label.horizontalCenter
                y: label.y - 1
                width: label.paintedWidth + 10
                height: label.paintedHeight + 2
                radius: 4
                color: Theme.accent
            }
            Text {
                id: label
                visible: root.renaming !== cell.name
                anchors.horizontalCenter: parent.horizontalCenter
                y: 72
                width: root.cellW - 8
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: cell.name
                font.family: Theme.font
                font.pixelSize: Theme.px(12)
                font.weight: Font.Medium
                color: cell.isSelected || Theme.wallpaperDark ? "white" : "#1D1D1F"
                style: cell.isSelected ? Text.Normal : Text.Outline
                styleColor: Theme.wallpaperDark ? Qt.rgba(0, 0, 0, 0.35) : Qt.rgba(1, 1, 1, 0.35)
            }

            // Inline rename (Return), Finder-style.
            Rectangle {
                visible: root.renaming === cell.name
                anchors.horizontalCenter: parent.horizontalCenter
                y: 70
                width: root.cellW + 10
                height: editor.contentHeight + 6
                radius: 4
                color: Theme.dark ? "#2C2C2E" : "white"
                border.width: 2
                border.color: Theme.accent
                TextInput {
                    id: editor
                    x: 4; y: 3
                    width: parent.width - 8
                    horizontalAlignment: TextInput.AlignHCenter
                    wrapMode: TextInput.WrapAnywhere
                    font.family: Theme.font
                    font.pixelSize: Theme.px(12)
                    color: Theme.text
                    selectionColor: Theme.accent
                    selectByMouse: true
                    onVisibleChanged: if (visible) {
                        text = cell.name;
                        forceActiveFocus();
                        // Select the name without its extension, as Finder does.
                        const dot = cell.modelData.isDir ? -1 : text.lastIndexOf(".");
                        select(0, dot > 0 ? dot : text.length);
                    }
                    Keys.onReturnPressed: root.finishRename(text)
                    Keys.onEnterPressed: root.finishRename(text)
                    Keys.onEscapePressed: { root.renaming = ""; keys.forceActiveFocus(); }
                    onActiveFocusChanged: if (!activeFocus && root.renaming === cell.name) root.finishRename(text)
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: 6
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                property point pressAt
                // The desktop takes the keyboard on release: changing its keyboard
                // mode during a press would cancel a drag before it starts.
                onReleased: if (root.dragging === "") root.activate()
                onPressed: m => {
                    Panels.closeAll();
                    if (root.renaming && root.renaming !== cell.name) root.renaming = "";
                    if (m.button === Qt.RightButton) {
                        const p = mapToItem(null, m.x, m.y);
                        root.contextAt(root.iconMenu(cell.name), p.x, p.y);
                        return;
                    }
                    const add = m.modifiers & (Qt.ShiftModifier | Qt.ControlModifier);
                    if (add) root.select(cell.name, true);
                    else if (!cell.isSelected) root.select(cell.name, false);
                    pressAt = mapToItem(null, m.x, m.y);
                    // The picture that follows the pointer if this becomes a drag.
                    icon.grabToImage(r => root.dragImage = r.url, Qt.size(64, 64));
                }
                onPositionChanged: m => {
                    if (!(pressedButtons & Qt.LeftButton) || root.dragging !== "") return;
                    const p = mapToItem(null, m.x, m.y);
                    if (Math.hypot(p.x - pressAt.x, p.y - pressAt.y) < 6) return;
                    root.startDrag(cell.name, pressAt);
                }
                onDoubleClicked: m => {
                    if (m.button === Qt.LeftButton) root.open(root.selectedPaths());
                }
            }
        }
    }
}
