pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screenshots and screen recording (⇧⌘5). Screenshots run in the
// background; a recording runs until Stop is clicked in the menu bar.
Singleton {
    id: root

    // screen | pick-window | area | record-screen | record-area
    property string mode: "area"
    readonly property bool recordMode: mode.startsWith("record")

    readonly property bool recording: recorder.running
    property string file: ""
    property real startedAt: 0
    property int elapsed: 0

    function capture() {
        Panels.screenshotBar = false;
        if (recordMode) {
            start(mode === "record-area" ? "area" : "screen");
            return;
        }
        const args = ["foxtail-screenshot", mode, "--delay", String(Settings.screenshotTimer)];
        if (Settings.screenshotPointer) args.push("--pointer");
        Quickshell.execDetached(args);
    }

    function start(kind) {
        if (recorder.running) return;
        const dir = Quickshell.env("HOME") + "/Videos/Screen Recordings";
        file = `${dir}/Screen Recording ${Qt.formatDateTime(new Date(), "yyyy-MM-dd 'at' HH.mm.ss")}.mp4`;
        recorder.command = ["foxtail-record", kind, file];
        recorder.running = true;
    }

    function stop() {
        if (recorder.running) recorder.signal(2);   // SIGINT: wf-recorder finishes the file
    }

    Process {
        id: recorder
        onStarted: { root.startedAt = Date.now(); root.elapsed = 0; }
        onExited: code => {
            if (code === 3) return;    // selection cancelled
            Quickshell.execDetached(["notify-send", "-a", "Screen Recording", "-i", "media-record",
                                     "Screen Recording", "Saved to Videos/Screen Recordings."]);
        }
    }
    Timer {
        interval: 1000
        repeat: true
        running: recorder.running
        onTriggered: root.elapsed = Math.round((Date.now() - root.startedAt) / 1000)
    }

    function clock(s) {
        const m = Math.floor(s / 60), r = s % 60;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
}
