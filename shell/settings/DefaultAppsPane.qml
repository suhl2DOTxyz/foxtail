import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// System Settings › Default Apps: which app opens links, mail, folders,
// documents and media.
Column {
    id: pane
    spacing: 14

    readonly property var categories: [
        { id: "web", name: "Web browser", icon: "globe", mimes: ["x-scheme-handler/http", "x-scheme-handler/https", "text/html"] },
        { id: "mail", name: "Mail", icon: "bell", mimes: ["x-scheme-handler/mailto"] },
        { id: "files", name: "Files", icon: "folder", mimes: ["inode/directory"] },
        { id: "text", name: "Text editor", icon: "keyboard", mimes: ["text/plain"] },
        { id: "pdf", name: "PDF documents", icon: "info", mimes: ["application/pdf"] },
        { id: "image", name: "Images", icon: "photo", mimes: ["image/png", "image/jpeg", "image/webp", "image/gif"] },
        { id: "video", name: "Videos", icon: "play", mimes: ["video/mp4", "video/x-matroska", "video/webm"] },
        { id: "music", name: "Music", icon: "music", mimes: ["audio/mpeg", "audio/flac", "audio/ogg", "audio/x-wav"] }
    ]

    // { id: { current: "x.desktop", apps: ["a.desktop", ...] } }
    property var state: ({})

    function refresh() { query.running = true; }
    Component.onCompleted: refresh()

    Process {
        id: query
        // For each "id mime" argument: the current default and every app that can open that type.
        command: ["sh", "-c", `
            dirs="$HOME/.local/share/applications /usr/share/applications /var/lib/flatpak/exports/share/applications $HOME/.local/share/flatpak/exports/share/applications"
            for pair in "$@"; do
                id=\${pair%% *}; mime=\${pair#* }
                cur=$(xdg-mime query default "$mime" 2>/dev/null)
                apps=$(for d in $dirs; do [ -d "$d" ] && grep -l "^MimeType=.*$mime;" "$d"/*.desktop 2>/dev/null; done |
                       while read -r f; do grep -q '^NoDisplay=true' "$f" || basename "$f"; done | sort -u | tr '\\n' ',')
                printf '%s\\t%s\\t%s\\n' "$id" "$cur" "$apps"
            done`, "sh"].concat(pane.categories.map(c => c.id + " " + c.mimes[0]))
        stdout: StdioCollector {
            onStreamFinished: {
                const st = {};
                for (const l of text.split("\n")) {
                    const f = l.split("\t");
                    if (f.length < 3) continue;
                    st[f[0]] = { current: f[1], apps: f[2].split(",").filter(a => a) };
                }
                pane.state = st;
            }
        }
    }

    function nameOf(desktop) {
        const e = Apps.entry(desktop.replace(/\.desktop$/, ""));
        return e?.name ?? desktop.replace(/\.desktop$/, "");
    }

    function setDefault(cat, desktop) {
        const cmds = [["xdg-mime", "default", desktop].concat(cat.mimes)];
        if (cat.id === "web") cmds.push(["xdg-settings", "set", "default-web-browser", desktop]);
        for (const c of cmds) Quickshell.execDetached(c);
        const st = Object.assign({}, state);
        st[cat.id] = Object.assign({}, st[cat.id] ?? { apps: [] }, { current: desktop });
        state = st;
    }

    Group {
        Repeater {
            model: pane.categories
            SettingRow {
                id: crow
                required property var modelData
                required property int index
                readonly property var info: pane.state[modelData.id] ?? { current: "", apps: [] }
                icon: modelData.icon
                label: modelData.name
                last: index === pane.categories.length - 1
                Choice {
                    menuWidth: 220
                    enabled: crow.info.apps.length > 0
                    options: {
                        const apps = crow.info.apps.slice();
                        if (crow.info.current && apps.indexOf(crow.info.current) < 0) apps.unshift(crow.info.current);
                        return apps.map(a => [a, pane.nameOf(a)]);
                    }
                    value: crow.info.current
                    onPicked: v => pane.setDefault(crow.modelData, v)
                }
            }
        }
    }
    Note { text: "Apps you install from the App Store appear here once they can open these kinds of files." }
}
