pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history (⌥⌘V), kept by cliphist. Recording can be turned off in
// System Settings › Keyboard.
Singleton {
    id: root

    property var items: []      // [{ id, text, image }]

    // Records everything copied while the setting is on.
    Process {
        running: Settings.clipboardHistory
        command: ["wl-paste", "--watch", "cliphist", "store"]
    }

    function refresh() { lister.running = true; }

    Process {
        id: lister
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.items = text.split("\n").filter(l => l.indexOf("\t") > 0).slice(0, 200).map(l => {
                    const tab = l.indexOf("\t");
                    const t = l.slice(tab + 1);
                    const img = /^\[\[ binary data .* (png|jpe?g|webp|gif|bmp) (\d+)x(\d+) \]\]$/.exec(t);
                    return { id: l.slice(0, tab), line: l, text: img ? `Image · ${img[2]}×${img[3]}` : t, image: !!img };
                });
            }
        }
    }

    // Put an entry back on the clipboard and paste it into the focused app.
    function paste(item) {
        Panels.closeAll();
        copier.command = ["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "sh", item.line];
        copier.running = true;
    }
    Process {
        id: copier
        onExited: code => { if (code === 0) Hypr.sendKeys(["ctrl"], "v"); }
    }

    function remove(item) {
        Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist delete", "sh", item.line]);
        items = items.filter(i => i.id !== item.id);
    }

    function clear() {
        Quickshell.execDetached(["cliphist", "wipe"]);
        items = [];
    }
}
