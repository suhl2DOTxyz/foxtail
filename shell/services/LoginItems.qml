pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell

// Login Items ("Open at Login"): apps started when you log in, kept as
// standard autostart entries in ~/.config/autostart (foxtail-autostart runs
// them at session start).
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/.config/autostart"

    FolderListModel {
        id: folder
        folder: "file://" + root.dir
        nameFilters: ["*.desktop"]
        showDirs: false
    }

    // Desktop ids of the login items.
    readonly property var items: {
        void folder.count;
        const out = [];
        for (let i = 0; i < folder.count; i++)
            out.push(String(folder.get(i, "fileName")).replace(/\.desktop$/, ""));
        return out;
    }

    function has(id) { return items.indexOf(id) >= 0; }

    function add(id) {
        const e = Apps.entry(id);
        if (!e || has(id)) return;
        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$1" && printf "%s\\n" "[Desktop Entry]" "Type=Application" "Name=$2" "Exec=$3" "Icon=$4" "X-Foxtail-Login-Item=true" > "$1/$5.desktop"',
            "sh", dir, e.name, e.execString, e.icon ?? "", e.id]);
    }

    function remove(id) {
        Quickshell.execDetached(["rm", "-f", dir + "/" + id + ".desktop"]);
    }

    function toggle(id) { if (has(id)) remove(id); else add(id); }
}
