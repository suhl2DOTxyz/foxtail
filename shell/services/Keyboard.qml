pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Input sources (keyboard layouts). The list lives in Settings.keyboardLayouts
// and becomes Hyprland's kb_layout through HyprConfig; an empty list means
// the layout picked in the installer.
Singleton {
    id: root

    property string systemLayout: "us"
    readonly property var layouts: Settings.keyboardLayouts.length ? Settings.keyboardLayouts : [systemLayout]
    property int activeIndex: 0
    readonly property string active: layouts[Math.min(activeIndex, layouts.length - 1)] ?? "us"

    // [[code, description]] from xkeyboard-config
    property var all: []

    FileView {
        path: "/etc/X11/xorg.conf.d/00-keyboard.conf"
        onLoaded: {
            const m = /XkbLayout"\s+"([^",]+)/.exec(text());
            if (m) root.systemLayout = m[1];
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "awk '/^! layout/{f=1;next} /^!/{f=0} f && NF {c=$1; $1=\"\"; sub(/^ +/,\"\"); print c \"\\t\" $0}' /usr/share/X11/xkb/rules/base.lst"]
        stdout: StdioCollector {
            onStreamFinished: root.all = text.trim().split("\n").map(l => l.split("\t")).filter(x => x.length === 2)
                .sort((a, b) => a[1].localeCompare(b[1]))
        }
    }

    function nameFor(code) {
        return (all.find(l => l[0] === code) ?? [code, code.toUpperCase()])[1];
    }
    // Short label for the menu bar ("US", "DE", "FR").
    function shortName(code) {
        return code.split("(")[0].toUpperCase().slice(0, 3);
    }

    function setLayouts(list) {
        Settings.keyboardLayouts = list;
    }
    function add(code) {
        if (layouts.indexOf(code) < 0) setLayouts(layouts.concat([code]));
    }
    function remove(code) {
        if (layouts.length > 1) setLayouts(layouts.filter(l => l !== code));
    }
    function select(i) {
        Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", String(i)]);
        activeIndex = i;
    }
    function next() {
        select((activeIndex + 1) % layouts.length);
    }

    // Which layout is active right now (it changes with ⌃Space or a reload).
    Process {
        id: devices
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards ?? [];
                    const main = kbs.find(k => k.main) ?? kbs[0];
                    if (main) root.activeIndex = main.active_layout_index ?? 0;
                } catch (e) {}
            }
        }
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name === "activelayout" || event.name === "configreloaded") devicesSoon.restart();
        }
    }
    Timer { id: devicesSoon; interval: 150; onTriggered: devices.running = true }
}
