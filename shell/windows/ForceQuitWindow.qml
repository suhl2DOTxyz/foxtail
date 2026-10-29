import QtQuick
import Quickshell
import qs.services
import qs.components

// Force Quit Applications (⌥⌘⎋). Also opened by Memory when the system runs
// low on memory, with macOS's "run out of application memory" message; it
// shows how much memory each app uses either way.
FloatingWindow {
    id: win

    title: I18n.tr("Force Quit Applications")
    visible: Panels.forceQuit
    onVisibleChanged: if (!visible) { Panels.forceQuit = false; Memory.warning = false; }
    implicitWidth: 380
    implicitHeight: 400
    color: "transparent"

    property var selected: null

    // Memory use per app, refreshed while the window is open.
    Timer { interval: 3000; repeat: true; running: win.visible; triggeredOnStart: true; onTriggered: Memory.refreshApps() }
    readonly property var usage: {
        const u = {};
        for (const a of Memory.apps) {
            const id = Apps.idForToplevel({ appId: a.class }) || a.class;
            u[id] = u[id] ? { kib: u[id].kib + a.kib, pids: u[id].pids.concat(a.pids) } : { kib: a.kib, pids: a.pids };
        }
        return u;
    }

    readonly property var apps: {
        const seen = {};
        const out = [];
        for (const t of Apps.toplevels) {
            const id = Apps.idForToplevel(t);
            if (!id || seen[id]) continue;
            seen[id] = true;
            out.push({ id, name: Apps.nameFor(id), icon: Apps.iconFor(id), kib: usage[id]?.kib ?? 0 });
        }
        // Low on memory: the biggest first, as on macOS.
        if (Memory.warning) out.sort((a, b) => b.kib - a.kib);
        return out;
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.windowRadius
        color: Theme.dark ? "#262628" : "#F3F3F5"
        border.color: Theme.glassOutline
    }

    TrafficLights { x: 14; y: 14; onClose: Panels.forceQuit = false; onMinimize: Panels.forceQuit = false }

    Label {
        x: 20; y: 44
        width: parent.width - 40
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        text: Memory.warning
              ? I18n.tr("Your system has run out of application memory. To avoid problems with your computer, quit any applications you are not using.")
              : I18n.tr("If an app doesn't respond for a while, select its name and click Force Quit.")
        font.pixelSize: Theme.px(12)
    }

    Rectangle {
        x: 20; y: Memory.warning ? 104 : 84   // room for the longer message
        width: parent.width - 40
        height: parent.height - y - 56
        radius: 6
        color: Theme.dark ? "#1C1C1E" : "white"
        border.color: Theme.separator
        clip: true

        ListView {
            anchors.fill: parent
            anchors.margins: 4
            model: win.apps
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 28
                radius: 4
                color: win.selected === modelData.id ? Theme.accent : "transparent"
                Image { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; sourceSize: Qt.size(40, 40); source: modelData.icon }
                Label {
                    x: 36
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - x - mem.width - 16
                    text: modelData.name
                    color: win.selected === modelData.id ? "white" : Theme.text
                }
                Label {
                    id: mem
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    visible: modelData.kib > 0
                    text: Memory.formatKib(modelData.kib)
                    font.pixelSize: Theme.px(11)
                    color: win.selected === modelData.id ? "white" : Theme.textSecondary
                }
                MouseArea { anchors.fill: parent; onClicked: win.selected = modelData.id }
            }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: 100; height: 26
        radius: Theme.liquid ? 13 : 6
        color: win.selected ? Theme.accent : Theme.control
        Label { anchors.centerIn: parent; text: I18n.tr("Force Quit"); color: win.selected ? "white" : Theme.textTertiary }
        MouseArea {
            anchors.fill: parent
            onClicked: if (win.selected) {
                // The app's own processes (and what it started), not
                // everything whose command line happens to mention its name.
                const pids = win.usage[win.selected]?.pids ?? [];
                if (pids.length) Memory.quitPids(pids);
                else for (const w of Apps.windowsFor(win.selected)) w.close();
                win.selected = null;
            }
        }
    }
}
