pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Software Update: checks pacman (`checkupdates`, which never touches the
// real package database) and Flatpak in the background, installs through
// `pkexec foxtail-update`, and lists/restores snapper snapshots.
Singleton {
    id: root

    // [{ name, from, to, kind: "system" | "app" }]
    property var available: []
    property bool checking: false
    property date lastChecked
    property string error: ""

    property bool installing: false
    property string stage: ""            // "system" | "apps"
    property string log: ""              // tail of the installer output
    property bool needsRestart: false     // kernel changed
    property bool needsRelogin: false     // Foxtail's own shell changed

    // [{ number, date, description }] newest first
    property var snapshots: []
    property bool restoring: false

    readonly property int count: available.length
    readonly property bool foxtailUpdate: available.some(u => u.name === "foxtail-desktop")

    // Update channel: "stable" or "testing" (beta builds of Foxtail).
    property string channel: "stable"
    Process {
        id: channelReader
        running: true
        command: ["foxtail-channel"]
        stdout: StdioCollector { onStreamFinished: root.channel = text.trim() || "stable" }
    }
    function setChannel(c) {
        if (c === channel) return;
        channelWriter.command = ["pkexec", "/usr/bin/foxtail-channel", c];
        channelWriter.running = true;
    }
    Process {
        id: channelWriter
        onExited: { channelReader.running = true; root.check(); }
    }

    function check() {
        if (checking || installing) return;
        checking = true;
        error = "";
        pacmanCheck.running = true;
    }

    function install() {
        if (installing) return;
        installing = true;
        log = "";
        stage = "";
        needsRelogin = foxtailUpdate;
        installer.running = true;
    }

    function refreshSnapshots() { snapLister.running = true; }

    function restore(number) {
        if (restoring) return;
        restoring = true;
        restorer.command = ["pkexec", "/usr/bin/foxtail-restore", String(number)];
        restorer.running = true;
    }
    signal restored()

    // ---- check ----
    property var _pending: []
    Process {
        id: pacmanCheck
        // checkupdates exits 2 when there's nothing to update; that's fine.
        command: ["sh", "-c", "checkupdates --nocolor 2>/dev/null; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._pending = text.split("\n").filter(l => l.trim()).map(l => {
                    const m = l.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/);
                    return m ? { name: m[1], from: m[2], to: m[3], kind: "system" } : null;
                }).filter(x => x);
                flatpakCheck.running = true;
            }
        }
    }
    Process {
        id: flatpakCheck
        command: ["sh", "-c", "command -v flatpak >/dev/null && flatpak remote-ls --updates --app --columns=name,version 2>/dev/null; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const apps = text.split("\n").filter(l => l.trim()).map(l => {
                    const [name, version] = l.split("\t");
                    return { name, from: "", to: version ?? "", kind: "app" };
                });
                const before = root.count;
                root.available = root._pending.concat(apps);
                root.checking = false;
                root.lastChecked = new Date();
                if (root.count > 0 && root.count !== before && !Panels.settings)
                    Quickshell.execDetached(["notify-send", "-a", "Software Update", "-i", "foxtail",
                        "Software Update",
                        root.count === 1 ? "1 update is available." : `${root.count} updates are available.`]);
            }
        }
    }

    // Check shortly after login, then every 6 hours.
    Timer { running: Settings.autoCheckUpdates; interval: 2 * 60 * 1000; onTriggered: root.check() }
    Timer { running: Settings.autoCheckUpdates; interval: 6 * 3600 * 1000; repeat: true; onTriggered: root.check() }

    // ---- install ----
    Process {
        id: installer
        command: ["pkexec", "/usr/bin/foxtail-update"]
        stdout: SplitParser {
            onRead: line => {
                if (line.startsWith("STAGE ")) root.stage = line.slice(6);
                else if (line.startsWith("RESTART")) root.needsRestart = true;
                else if (line !== "DONE") root.log = (root.log + "\n" + line).split("\n").slice(-6).join("\n");
            }
        }
        onExited: code => {
            root.installing = false;
            root.stage = "";
            if (code === 126 || code === 127) root.error = "Authentication was cancelled.";
            else if (code !== 0) root.error = "The update didn't finish (code " + code + "). Nothing was changed after the last snapshot.";
            else root.available = [];
            root.refreshSnapshots();
        }
    }

    // ---- snapshots ----
    Process {
        id: snapLister
        command: ["snapper", "--jsonout", "-c", "root", "list", "--columns", "number,date,description"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(text).root ?? [];
                    root.snapshots = list.filter(s => s.number > 0).reverse();
                } catch (e) {
                    root.snapshots = [];
                }
            }
        }
    }
    Process {
        id: restorer
        onExited: code => {
            root.restoring = false;
            if (code === 0) root.restored();
            else if (code !== 126 && code !== 127) root.error = "Restoring failed (code " + code + ").";
        }
    }

    Component.onCompleted: refreshSnapshots()
}
