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
        shoot(mode, Settings.screenshotTimer, Settings.screenshotPointer, false);
    }

    // Where screenshots and recordings go (Options ▸ Save to).
    readonly property string home: Quickshell.env("HOME")
    property string desktopDir: home + "/Desktop"
    Process {
        running: true
        command: ["xdg-user-dir", "DESKTOP"]
        stdout: StdioCollector { onStreamFinished: if (text.trim() && text.trim() !== root.home) root.desktopDir = text.trim() }
    }
    readonly property string saveDir: Settings.screenshotSaveTo === "documents" ? home + "/Documents"
                                    : Settings.screenshotSaveTo === "pictures" ? home + "/Pictures/Screenshots"
                                    : desktopDir

    // ⇧⌘3 / ⇧⌘4 and the toolbar. `toClipboard` (⌃⇧⌘3/4, or Save to
    // Clipboard) copies the picture instead of saving a file.
    function shoot(kind, delay, pointer, toClipboard) {
        if (shooter.running) return;
        const clip = toClipboard || Settings.screenshotSaveTo === "clipboard";
        const args = ["foxtail-screenshot", kind, "--delay", String(delay ?? 0)];
        if (pointer) args.push("--pointer");
        if (clip) args.push("--clipboard"); else args.push("--dir", saveDir);
        shooter.clip = clip;
        shooter.command = args;
        shooter.running = true;
    }

    // The latest screenshot: a thumbnail floats in the corner for a few
    // seconds (click it to open the picture), as on macOS.
    property string lastShot: ""
    Process {
        id: shooter
        property bool clip: false
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split("\n").pop();
                if (f) root.lastShot = f;
            }
        }
        onExited: code => { if (code === 0) Sounds.play("screenshot"); }
    }

    function start(kind) {
        if (recorder.running) return;
        const dir = Settings.screenshotSaveTo === "clipboard" ? home + "/Videos" : saveDir;
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
            root.lastShot = root.file;
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
