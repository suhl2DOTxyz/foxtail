import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// Spotlight: one search field; results for apps, a calculator, system
// actions and a web-search fallback. ↑/↓ to move, Return to open.
Item {
    id: root

    property point windowOffset
    property size screenSize

    width: 680
    height: field.height + (results.count > 0 ? list.height + 12 : 0)
    Behavior on height { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

    property int current: 0

    readonly property var actions: [
        { name: "System Settings", sub: "Foxtail", icon: "gear", run: () => Panels.openSettings() },
        { name: "Lock Screen", sub: "Action", icon: "lock", run: () => Lock.lock() },
        { name: "Toggle Dark Mode", sub: "Appearance", icon: "half-circle", run: () => Settings.darkMode = !Settings.darkMode },
        { name: "Toggle Liquid Glass", sub: "Appearance", icon: "drop", run: () => Settings.liquidGlass = !Settings.liquidGlass },
        { name: "Restart", sub: "Action", icon: "restart", run: () => Panels.confirm = "restart" },
        { name: "Shut Down", sub: "Action", icon: "power", run: () => Panels.confirm = "shutdown" },
        { name: "Log Out", sub: "Action", icon: "logout", run: () => Panels.confirm = "logout" }
    ]

    function calc(q) {
        // Only digits, operators, parens and a few Math names make it to eval.
        const expr = q.replace(/\s+/g, "").replace(/×/g, "*").replace(/÷/g, "/").replace(/\^/g, "**");
        if (!/^[0-9+\-*/().%*]+$/.test(expr) || !/[+\-*/%]/.test(expr)) return null;
        try {
            const v = Function("\"use strict\"; return (" + expr + ")")();
            if (typeof v !== "number" || !isFinite(v)) return null;
            return Math.round(v * 1e10) / 1e10;
        } catch (e) {
            return null;
        }
    }

    readonly property var items: {
        const q = input.text.trim();
        if (!q) return [];
        const out = [];
        const c = calc(q);
        if (c !== null) out.push({ kind: "calc", name: String(c), sub: q + " =", glyph: "calculator",
                                  run: () => Quickshell.clipboardText = String(c) });
        for (const e of Apps.search(q).slice(0, 8))
            out.push({ kind: "app", name: e.name, sub: e.genericName || "Application", entry: e, run: () => e.execute() });
        for (const f of files.slice(0, 6)) {
            const name = f.split("/").pop();
            const dir = f.slice(0, f.length - name.length - 1).replace(Quickshell.env("HOME"), "~");
            out.push({ kind: "file", name, sub: dir || "~", glyph: "folder",
                       run: () => Quickshell.execDetached(["xdg-open", f]) });
        }
        const ql = q.toLowerCase();
        for (const a of actions)
            if (a.name.toLowerCase().indexOf(ql) >= 0)
                out.push({ kind: "action", name: a.name, sub: a.sub, glyph: a.icon, run: a.run });
        out.push({ kind: "web", name: `Search the web for “${q}”`, sub: "Firefox", glyph: "globe",
                   run: () => Quickshell.execDetached(["xdg-open", "https://duckduckgo.com/?q=" + encodeURIComponent(q)]) });
        return out;
    }

    onItemsChanged: current = 0

    // ---- file search: debounced `find` over the home folder ----
    property var files: []
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
                  "-iname", "*" + query.replace(/[*?\[\]]/g, "") + "*", "-print"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (finder.query !== input.text.trim()) return;   // stale result
                root.files = text.split("\n").filter(l => l).slice(0, 20)
                    .sort((a, b) => a.split("/").length - b.split("/").length);
            }
        }
    }

    function launch(i) {
        const it = items[i];
        if (!it) return;
        Panels.closeAll();
        it.run();
    }

    opacity: 0
    scale: 0.97
    Component.onCompleted: { opacity = 1; scale = 1; input.forceActiveFocus(); }
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }

    MouseArea { anchors.fill: parent }

    Glass {
        anchors.fill: parent
        radius: Theme.liquid ? 30 : 16
        color: Theme.glassStrong
        windowOffset: root.windowOffset
        screenSize: root.screenSize
        rimOpacity: 0.55
        bezel: 24
        refraction: 20
    }

    Item {
        id: field
        width: parent.width
        height: 58

        Icon {
            id: glass
            x: 20
            anchors.verticalCenter: parent.verticalCenter
            size: 22
            name: "search"
            color: Theme.textSecondary
        }

        TextInput {
            id: input
            anchors.left: glass.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.font
            font.pixelSize: 24
            font.weight: Font.Light
            color: Theme.text
            selectionColor: Theme.accent
            clip: true
            onTextChanged: fileDebounce.restart()

            Label {
                visible: !input.text
                text: "Spotlight Search"
                font.pixelSize: 24
                font.weight: Font.Light
                color: Theme.textTertiary
                anchors.verticalCenter: parent.verticalCenter
            }

            Keys.onDownPressed: root.current = Math.min(root.current + 1, root.items.length - 1)
            Keys.onUpPressed: root.current = Math.max(root.current - 1, 0)
            Keys.onReturnPressed: root.launch(root.current)
            Keys.onEnterPressed: root.launch(root.current)
            Keys.onEscapePressed: Panels.closeAll()
            Keys.onTabPressed: root.current = (root.current + 1) % Math.max(1, root.items.length)
        }
    }

    Rectangle {
        visible: results.count > 0
        y: field.height
        width: parent.width
        height: 1
        color: Theme.separator
    }

    Item {
        id: list
        y: field.height + 6
        width: parent.width
        height: Math.min(results.count, 9) * 40

        ListView {
            id: results
            anchors.fill: parent
            clip: true
            model: root.items
            currentIndex: root.current
            interactive: count > 9
            highlightMoveDuration: 80

            delegate: Item {
                id: row
                required property var modelData
                required property int index
                width: results.width
                height: 40
                readonly property bool sel: index === root.current

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    radius: Theme.liquid ? 12 : 7
                    color: row.sel ? Theme.accent : "transparent"
                }

                Item {
                    id: ico
                    x: 18
                    width: 26; height: 26
                    anchors.verticalCenter: parent.verticalCenter
                    Image {
                        anchors.fill: parent
                        visible: row.modelData.kind === "app"
                        source: row.modelData.kind === "app" ? Quickshell.iconPath(row.modelData.entry.icon, "application-x-executable") : ""
                        sourceSize: Qt.size(52, 52)
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: row.modelData.kind !== "app"
                        size: 20
                        name: row.modelData.glyph ?? ""
                        color: row.sel ? "white" : Theme.text
                    }
                }

                Label {
                    anchors.left: ico.right
                    anchors.leftMargin: 12
                    anchors.right: sub.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.name
                    font.pixelSize: row.modelData.kind === "calc" ? 18 : 14
                    color: row.sel ? "white" : Theme.text
                }

                Label {
                    id: sub
                    anchors.right: parent.right
                    anchors.rightMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.sub
                    font.pixelSize: 12
                    color: row.sel ? Qt.rgba(1, 1, 1, 0.8) : Theme.textSecondary
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: root.current = row.index
                    onClicked: root.launch(row.index)
                }
            }
        }
    }
}
