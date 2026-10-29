pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Running out of memory, handled like macOS (and a step further):
//
//  low       "Your system has run out of application memory": the Force
//            Quit window opens, listing open apps with how much memory each
//            uses, so you can choose what to quit.
//  critical  Memory is about to run out (the computer would freeze before
//            the kernel stepped in): the app using the most memory is quit,
//            and a notification offers to reopen it.
//
// Measured from /proc/meminfo (what's left, counting swap) and the kernel's
// memory pressure (/proc/pressure/memory: how much time processes spend
// waiting for memory), every 2 seconds.
Singleton {
    id: root

    // 0..1: memory still available, counting free swap at half its size
    // (zram swap is compressed RAM, and swapping is slow).
    property real available: 1
    // % of the last 10 s that some / all processes were stalled on memory.
    property real pressureSome: 0
    property real pressureFull: 0
    readonly property string level: (available < 0.04 && pressureFull > 15) ? "critical"
                                  : (available < 0.10 || pressureSome > 40) ? "low" : "ok"

    // [{ class, pids, kib }] from foxtail-memory, largest first; refreshed
    // while the Force Quit window is open.
    property var apps: []
    function refreshApps() { if (!appsProc.running) appsProc.running = true; }

    function quitPids(pids) { Quickshell.execDetached(["foxtail-memory", "quit"].concat(pids.map(String))); }

    function formatKib(kib) {
        return kib >= 1048576 ? (kib / 1048576).toFixed(1) + " GB"
             : Math.max(1, Math.round(kib / 1024)) + " MB";
    }

    FileView { id: meminfo; path: "/proc/meminfo" }
    FileView { id: pressure; path: "/proc/pressure/memory" }

    function field(text, name) {
        const m = text.match(new RegExp("^" + name + ":\\s+(\\d+)", "m"));
        return m ? Number(m[1]) : 0;
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            meminfo.reload();
            pressure.reload();
            const m = meminfo.text();
            const total = root.field(m, "MemTotal");
            if (total > 0)
                root.available = (root.field(m, "MemAvailable") + root.field(m, "SwapFree") / 2) / total;
            const p = pressure.text();
            const some = p.match(/^some avg10=([\d.]+)/m);
            const full = p.match(/^full avg10=([\d.]+)/m);
            root.pressureSome = some ? Number(some[1]) : 0;
            root.pressureFull = full ? Number(full[1]) : 0;
        }
    }

    // ---- low: the macOS window (at most every 10 minutes) ----
    property bool warning: false   // Force Quit window opened by low memory
    property double lastWarning: 0
    onLevelChanged: {
        if (level === "ok") return;
        if (level === "critical") { rescue(); return; }
        if (Date.now() - lastWarning < 10 * 60 * 1000) return;
        lastWarning = Date.now();
        warning = true;
        Panels.forceQuit = true;
    }

    // ---- critical: quit the largest app ----
    property bool rescuing: false
    function rescue() {
        if (rescuing) return;
        rescuing = true;
        rescueProc.running = true;
    }
    Process {
        id: rescueProc
        command: ["foxtail-memory", "apps"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list = [];
                try { list = JSON.parse(text); } catch (e) {}
                const top = list[0];
                if (top && top.kib > 0) {
                    const id = Apps.idForToplevel({ appId: top.class }) || top.class;
                    const name = Apps.nameFor(id) || top.class;
                    root.quitPids(top.pids);
                    // KDE's "Memory Shortage Avoided", with Reopen.
                    Quickshell.execDetached(["sh", "-c",
                        'a=$(notify-send -a "$1" -i dialog-warning -u critical -A reopen="$4" "$2" "$3"); '
                        + '[ "$a" = reopen ] && exec foxtail-ipc launchApp "$5"',
                        "sh", I18n.tr("Memory"), I18n.tr("Memory Shortage Avoided"),
                        I18n.tr("%1 was quit because your computer ran out of memory.").arg(name),
                        I18n.tr("Reopen"), id]);
                }
                cooldown.restart();
            }
        }
    }
    // Give memory a moment to come back before judging again.
    Timer {
        id: cooldown
        interval: 15000
        onTriggered: {
            root.rescuing = false;
            if (root.level === "critical") root.rescue();
        }
    }

    Process {
        id: appsProc
        command: ["foxtail-memory", "apps"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.apps = JSON.parse(text); } catch (e) {}
            }
        }
    }
}
