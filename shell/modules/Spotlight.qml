import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// Spotlight, macOS Tahoe style: a floating search capsule; results appear in
// a glass panel beneath it, grouped (Top Hit, Applications, System Settings,
// Folders, Documents, Actions, Clipboard, ...) with a preview of the
// selection on the right. The four buttons in the bar (or ⌘1–⌘4) browse
// Applications, Files, Actions and the Clipboard without typing anything.
// ↑/↓ move, Return opens, Tab or ⌘1–⌘4 switch what you browse, Esc closes.
Item {
    id: root

    property point windowOffset
    property size screenSize

    width: 720
    height: field.height + (rows.length > 0 ? panel.height + 10 : 0)

    // "" = search everything; "apps" | "files" | "actions" | "clipboard" = browse
    property string mode: ""
    readonly property var modes: [
        { id: "apps", name: "Applications", icon: "grid" },
        { id: "files", name: "Files", icon: "doc" },
        { id: "actions", name: "Actions", icon: "bolt-circle" },
        { id: "clipboard", name: "Clipboard", icon: "clipboard" }
    ]
    readonly property var modeInfo: modes.find(m => m.id === mode) ?? null
    function setMode(m) {
        mode = mode === m ? "" : m;
        if (mode === "clipboard") Clipboard.refresh();
        if (mode === "files") recent.running = true;
        input.forceActiveFocus();
    }

    // ⌘1–⌘4 reach the shell through hypr/foxtail.lua while Spotlight is open.
    Component.onCompleted: {
        Hypr.lua("foxtail_spotlight = true");
        opacity = 1; scale = 1;
        input.forceActiveFocus();
        Clipboard.refresh();
    }
    Component.onDestruction: Hypr.lua("foxtail_spotlight = false")
    Connections {
        target: Panels
        function onSpotlightMode(i) { root.setMode(root.modes[i - 1]?.id ?? ""); }
    }

    // ---------------- sources ----------------
    readonly property var actions: [
        { name: "System Settings", keys: "preferences", icon: "gear", run: () => Panels.openSettings() },
        { name: "Lock Screen", keys: "lock", icon: "lock", run: () => Lock.lock() },
        { name: "Take Screenshot", keys: "capture screen", icon: "screen-capture", run: () => Capture.shoot("screen", 0, false, false) },
        { name: "Screenshot and Recording Options", keys: "capture record video", icon: "screen-record", run: () => { Panels.screenshotBar = true; } },
        { name: "New Folder on Desktop", keys: "create directory", icon: "folder-plus", run: () => Panels.desktopNewFolder() },
        { name: "Show Clipboard History", keys: "paste copied", icon: "clipboard", run: () => Panels.toggle("clipboard", Panels.screen) },
        { name: "Emoji & Symbols", keys: "emoji characters", icon: "smiley", run: () => Panels.toggle("emoji", Panels.screen) },
        { name: "Mission Control", keys: "windows overview spaces", icon: "mission", run: () => { Panels.missionControl = true; } },
        { name: Settings.doNotDisturb ? "Turn Off Do Not Disturb" : "Turn On Do Not Disturb", keys: "focus notifications", icon: "moon", run: () => Settings.doNotDisturb = !Settings.doNotDisturb },
        { name: Settings.darkMode ? "Turn Off Dark Mode" : "Turn On Dark Mode", keys: "appearance light", icon: "half-circle", run: () => { Settings.appearanceAuto = false; Settings.darkMode = !Settings.darkMode; } },
        { name: Settings.liquidGlass ? "Turn Off Liquid Glass" : "Turn On Liquid Glass", keys: "transparency glass", icon: "drop", run: () => Settings.liquidGlass = !Settings.liquidGlass },
        { name: Settings.nightShiftNow ? "Turn Off Night Shift" : "Turn On Night Shift", keys: "warm display", icon: "nightshift", run: () => Settings.nightShiftNow = !Settings.nightShiftNow },
        { name: "Empty Trash", keys: "delete", icon: "trash", run: () => Panels.confirm = "emptyTrash" },
        { name: "Sleep", keys: "suspend", icon: "moon", run: () => Quickshell.execDetached(["systemctl", "suspend"]) },
        { name: "Restart…", keys: "reboot", icon: "restart", run: () => Panels.confirm = "restart" },
        { name: "Shut Down…", keys: "power off", icon: "power", run: () => Panels.confirm = "shutdown" },
        { name: "Log Out…", keys: "sign out", icon: "logout", run: () => Panels.confirm = "logout" }
    ]

    function calc(q) {
        // Only digits, operators, parens and a few Math names make it to eval.
        const expr = q.replace(/\s+/g, "").replace(/×/g, "*").replace(/÷/g, "/").replace(/\^/g, "**").replace(/,/g, ".");
        if (!/^[0-9+\-*/().%*]+$/.test(expr) || !/[+\-*/%]/.test(expr)) return null;
        try {
            const v = Function("\"use strict\"; return (" + expr + ")")();
            if (typeof v !== "number" || !isFinite(v)) return null;
            return Math.round(v * 1e10) / 1e10;
        } catch (e) {
            return null;
        }
    }

    function matches(text, q) { return String(text ?? "").toLowerCase().indexOf(q) >= 0; }
    function fileRow(f) {
        const name = f.split("/").pop();
        const dir = f.slice(0, f.length - name.length - 1);
        const dot = name.lastIndexOf(".");
        return { kind: "file", name, sub: dir.replace(Quickshell.env("HOME"), "~") || "~", path: f,
                 suffix: dot > 0 ? name.slice(dot + 1).toLowerCase() : "", isDir: !!dirs[f],
                 run: () => Quickshell.execDetached(["xdg-open", f]) };
    }
    function appRow(e) { return { kind: "app", name: Apps.title(e), sub: e.genericName || e.comment || "Application", entry: e, run: () => e.execute() }; }
    function actionRow(a) { return { kind: "action", name: a.name, sub: "Action", glyph: a.icon, run: a.run }; }
    function paneRow(p) { return { kind: "pane", name: p.name, sub: "System Settings", glyph: p.icon, color: p.color, run: () => Panels.openSettings(p.id) }; }
    function clipRow(c) { return { kind: "clip", name: c.text.split("\n")[0].slice(0, 120), sub: c.image ? "Image" : "Text", clip: c, glyph: "clipboard", run: () => Clipboard.paste(c) }; }

    // Sections: [{ title, rows: [...] }]
    readonly property var sections: {
        const q = input.text.trim().toLowerCase();
        const out = [];
        const add = (title, rows) => { if (rows.length) out.push({ title, rows }); };

        if (mode === "apps")
            return [{ title: "Applications", rows: (q ? Apps.search(q) : Apps.all).slice(0, 60).map(appRow) }];
        if (mode === "files") {
            const list = q ? files : recentFiles;
            return list.length ? [{ title: q ? "Files" : "Recent Files", rows: list.slice(0, 40).map(fileRow) }] : [];
        }
        if (mode === "actions")
            return [{ title: "Actions", rows: actions.filter(a => !q || matches(a.name + " " + a.keys, q)).map(actionRow) }];
        if (mode === "clipboard")
            return [{ title: "Clipboard", rows: Clipboard.items.filter(c => !q || matches(c.text, q)).slice(0, 50).map(clipRow) }];

        if (!q) return [];
        const c = calc(q);
        const apps = Apps.search(q).slice(0, 8).map(appRow);
        const panes = Panels.settingsPanes.filter(p => p.id !== "sep" && matches(p.name + " " + p.keywords, q)).slice(0, 4).map(paneRow);
        const acts = actions.filter(a => matches(a.name + " " + a.keys, q)).slice(0, 4).map(actionRow);
        const found = files.map(fileRow);

        if (c !== null) add("Calculator", [{ kind: "calc", name: String(c), sub: q + " =", glyph: "calculator",
                                             run: () => Quickshell.clipboardText = String(c) }]);
        // Top Hit: an app whose name starts with what you typed, else the best match.
        let top = null;
        if (c === null) {
            if (apps.length && apps[0].name.toLowerCase().startsWith(q)) top = apps.shift();
            else if (panes.length && panes[0].name.toLowerCase().startsWith(q)) top = panes.shift();
            else if (apps.length) top = apps.shift();
        }
        if (top) add("Top Hit", [top]);
        add("Applications", apps);
        add("System Settings", panes);
        add("Folders", found.filter(f => f.isDir).slice(0, 4));
        add("Documents", found.filter(f => !f.isDir).slice(0, 6));
        add("Actions", acts);
        add("Clipboard", Clipboard.items.filter(i => !i.image && matches(i.text, q)).slice(0, 3).map(clipRow));
        add("Web", [{ kind: "web", name: `Search the web for “${input.text.trim()}”`, sub: "Firefox", glyph: "globe",
                      run: () => Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(input.text.trim())]) }]);
        return out;
    }

    // ---- file search: debounced `find` over the home folder ----
    property var files: []
    property var dirs: ({})
    Timer {
        id: fileDebounce
        interval: 180
        onTriggered: {
            const q = input.text.trim();
            if (q.length < 2) { root.files = []; return; }
            finder.running = false;
            finder.query = q;
            finder.running = true;
        }
    }
    Process {
        id: finder
        property string query
        // Skip hidden folders and caches; names only, case-insensitive.
        command: ["find", Quickshell.env("HOME"), "-maxdepth", "5",
                  "(", "-name", ".*", "-o", "-name", "node_modules", ")", "-prune", "-o",
                  "-iname", "*" + query.replace(/[*?\[\]]/g, "") + "*", "-printf", "%y %p\\n"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (finder.query !== input.text.trim()) return;   // stale result
                const d = {};
                const list = text.split("\n").filter(l => l.length > 2).slice(0, 30).map(l => {
                    const p = l.slice(2);
                    if (l[0] === "d") d[p] = true;
                    return p;
                }).sort((a, b) => a.split("/").length - b.split("/").length);
                root.dirs = d;
                root.files = list;
            }
        }
    }
    // Browse ▸ Files with nothing typed: recently changed files.
    property var recentFiles: []
    Process {
        id: recent
        command: ["sh", "-c", 'find "$HOME" -maxdepth 4 \\( -name ".*" -o -name node_modules \\) -prune -o -type f -mtime -30 -printf "%T@ %p\\n" 2>/dev/null | sort -rn | head -40 | cut -d" " -f2-']
        stdout: StdioCollector { onStreamFinished: root.recentFiles = text.split("\n").filter(l => l) }
    }

    // Flattened rows for the list: headers and results.
    readonly property var rows: {
        const out = [];
        for (const s of sections) {
            out.push({ header: true, name: s.title });
            for (const r of s.rows) out.push(r);
        }
        return out;
    }
    property int current: 1
    onRowsChanged: current = rows.length > 1 ? 1 : 0
    readonly property var selected: rows[current] && !rows[current].header ? rows[current] : null

    function move(d) {
        let i = current;
        do { i += d; } while (i >= 0 && i < rows.length && rows[i].header);
        if (i >= 0 && i < rows.length) current = i;
    }
    function launch(i) {
        const it = rows[i];
        if (!it || it.header) return;
        Panels.closeAll();
        it.run();
    }

    opacity: 0
    scale: 0.97
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }

    MouseArea { anchors.fill: parent }

    // ---------------- the search capsule ----------------
    Item {
        id: field
        width: parent.width
        height: 56

        Glass {
            anchors.fill: parent
            radius: Theme.liquid ? height / 2 : 14
            color: Theme.glassStrong
            windowOffset: root.windowOffset
            screenSize: root.screenSize
            rimOpacity: 0.85
            bezel: 18
            refraction: 12
        }

        Icon {
            id: glass
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            size: 20
            name: "search"
            color: Theme.textSecondary
        }

        // The category being browsed, as a token in the field.
        Rectangle {
            id: token
            visible: root.modeInfo !== null
            anchors.left: glass.right
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            width: visible ? tokenLabel.implicitWidth + 20 : 0
            height: 26
            radius: 13
            color: Theme.accent
            Label { id: tokenLabel; anchors.centerIn: parent; text: root.modeInfo?.name ?? ""; color: "white"; font.pixelSize: 13; font.weight: Font.Medium }
        }

        TextInput {
            id: input
            anchors.left: token.visible ? token.right : glass.right
            anchors.leftMargin: 10
            anchors.right: modeButtons.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.font
            font.pixelSize: 22
            font.weight: Font.Light
            color: Theme.text
            selectionColor: Theme.accent
            clip: true
            onTextChanged: fileDebounce.restart()

            Label {
                visible: !input.text
                text: root.modeInfo ? `Search ${root.modeInfo.name}` : "Spotlight Search"
                font.pixelSize: 22
                font.weight: Font.Light
                color: Theme.textTertiary
                anchors.verticalCenter: parent.verticalCenter
            }

            Keys.onDownPressed: root.move(1)
            Keys.onUpPressed: root.move(-1)
            Keys.onReturnPressed: root.launch(root.current)
            Keys.onEnterPressed: root.launch(root.current)
            Keys.onEscapePressed: {
                if (root.mode) root.mode = "";
                else Panels.closeAll();
            }
            Keys.onTabPressed: {
                const i = root.modes.findIndex(m => m.id === root.mode);
                root.setMode(i + 1 < root.modes.length ? root.modes[i + 1].id : "");
            }
            Keys.onPressed: e => {
                // Backspace in an empty field leaves the category.
                if (e.key === Qt.Key_Backspace && !input.text && root.mode) { root.mode = ""; e.accepted = true; }
            }
        }

        Row {
            id: modeButtons
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Repeater {
                model: root.modes
                Rectangle {
                    id: modeButton
                    required property var modelData
                    required property int index
                    width: 32; height: 32
                    radius: 16
                    color: root.mode === modelData.id ? Theme.accent : (mb.containsMouse ? Theme.hover : "transparent")
                    Icon { anchors.centerIn: parent; size: 16; name: modeButton.modelData.icon; color: root.mode === modeButton.modelData.id ? "white" : Theme.textSecondary }
                    MouseArea { id: mb; anchors.fill: parent; hoverEnabled: true; onClicked: root.setMode(modeButton.modelData.id) }
                    Rectangle {   // tooltip with the shortcut, like macOS
                        visible: mb.containsMouse
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: 8
                        width: tipText.implicitWidth + 16
                        height: 22
                        radius: 11
                        color: Theme.glassStrong
                        border.color: Theme.glassOutline
                        Label { id: tipText; anchors.centerIn: parent; text: `${modeButton.modelData.name}  ⌘${modeButton.index + 1}`; font.pixelSize: 11 }
                    }
                }
            }
        }
    }

    // ---------------- results ----------------
    Item {
        id: panel
        visible: root.rows.length > 0
        y: field.height + 10
        width: parent.width
        // Tall enough for the preview even when there's a single result.
        height: Math.min(440, Math.max(root.selected ? 260 : 0, list.contentHeight + 16))
        Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

        Glass {
            anchors.fill: parent
            radius: Theme.liquid ? 26 : 14
            color: Theme.glassStrong
            windowOffset: root.windowOffset
            screenSize: root.screenSize
            rimOpacity: 0.85
            bezel: 18
            refraction: 12
        }

        ListView {
            id: list
            x: 8; y: 8
            width: preview.visible ? 340 : parent.width - 16
            height: parent.height - 16
            clip: true
            model: root.rows
            currentIndex: root.current
            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 80

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: list.width
                height: modelData.header ? 26 : 36
                readonly property bool sel: index === root.current

                Label {
                    visible: row.modelData.header === true
                    x: 12
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 4
                    text: row.modelData.name
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Theme.textSecondary
                }

                Rectangle {
                    visible: !row.modelData.header
                    anchors.fill: parent
                    radius: Theme.liquid ? 12 : 7
                    color: row.sel ? Theme.accent : (rowMouse.containsMouse ? Theme.hover : "transparent")
                }

                Item {
                    id: ico
                    visible: !row.modelData.header
                    x: 10
                    width: 24; height: 24
                    anchors.verticalCenter: parent.verticalCenter
                    Image {
                        anchors.fill: parent
                        visible: row.modelData.kind === "app"
                        source: row.modelData.kind === "app" ? Quickshell.iconPath(row.modelData.entry.icon, "application-x-executable") : ""
                        sourceSize: Qt.size(48, 48)
                    }
                    Loader {
                        anchors.centerIn: parent
                        active: row.modelData.kind === "file"
                        sourceComponent: FileIcon {
                            size: 24
                            file: row.modelData
                            path: row.modelData.path
                            uri: ""
                        }
                    }
                    Rectangle {   // System Settings panes get their colored tile
                        visible: row.modelData.kind === "pane"
                        anchors.fill: parent
                        radius: 6
                        color: row.modelData.color ?? Theme.accent
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: row.modelData.kind !== "app" && row.modelData.kind !== "file"
                        size: row.modelData.kind === "pane" ? 15 : 18
                        name: row.modelData.glyph ?? ""
                        color: row.modelData.kind === "pane" || row.sel ? "white" : Theme.text
                    }
                }

                Label {
                    visible: !row.modelData.header
                    anchors.left: ico.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    elide: Text.ElideRight
                    font.pixelSize: row.modelData.kind === "calc" ? 17 : 13
                    color: row.sel ? "white" : Theme.text
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    enabled: !row.modelData.header
                    hoverEnabled: true
                    onClicked: {
                        if (root.current === row.index) root.launch(row.index);
                        else root.current = row.index;
                    }
                    onDoubleClicked: root.launch(row.index)
                }
            }
        }

        // ---- preview of the selected result ----
        Item {
            id: preview
            readonly property var it: root.selected ?? ({})
            visible: root.selected !== null
            x: list.x + list.width + 8
            y: 8
            width: parent.width - x - 8
            height: parent.height - 16

            Rectangle {
                width: 1
                height: parent.height - 16
                y: 8
                color: Theme.separator
            }

            Column {
                anchors.centerIn: parent
                width: parent.width - 32
                spacing: 8

                Item {
                    width: parent.width
                    height: 120
                    Image {
                        anchors.centerIn: parent
                        width: 96; height: 96
                        visible: preview.it.kind === "app"
                        sourceSize: Qt.size(192, 192)
                        source: preview.it.kind === "app" ? Quickshell.iconPath(preview.it.entry.icon, "application-x-executable") : ""
                    }
                    Loader {
                        anchors.centerIn: parent
                        active: preview.it.kind === "file"
                        sourceComponent: FileIcon {
                            size: 110
                            file: preview.it
                            path: preview.it.path
                            uri: "file://" + encodeURI(preview.it.path)
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        visible: ["pane", "action", "web", "clip"].indexOf(preview.it.kind) >= 0
                        width: 80; height: 80
                        radius: 20
                        color: preview.it.kind === "pane" ? (preview.it.color ?? Theme.accent) : Theme.control
                        Icon {
                            anchors.centerIn: parent
                            size: 40
                            name: preview.it.glyph ?? ""
                            color: preview.it.kind === "pane" ? "white" : Theme.text
                        }
                    }
                    Label {
                        anchors.centerIn: parent
                        visible: preview.it.kind === "calc"
                        text: preview.it.name ?? ""
                        font.pixelSize: 40
                        font.weight: Font.Light
                    }
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    text: preview.it.kind === "calc" ? preview.it.sub : (preview.it.name ?? "")
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Label {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    text: preview.it.kind === "file" ? (preview.it.isDir ? "Folder" : (preview.it.suffix ? preview.it.suffix.toUpperCase() + " document" : "Document")) + "\n" + preview.it.sub
                        : preview.it.kind === "calc" ? "Press Return to copy the result"
                        : preview.it.kind === "clip" ? "Press Return to paste"
                        : (preview.it.sub ?? "")
                    color: Theme.textSecondary
                    font.pixelSize: 12
                }
            }
        }
    }
}
