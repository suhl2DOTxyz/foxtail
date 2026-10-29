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
//  oom kill  If memory ran out too fast for that, the kernel's last-resort
//            killer quits an app; that gets the same notification, so an
//            app never just vanishes.
//
// Measured from /proc/meminfo (what's left, counting swap) and the kernel's
// memory pressure (/proc/pressure/memory: how much time processes spend
// waiting for memory), every 2 seconds.
Singleton {
    id: root

    // 0..1: memory still available, counting free swap at half its size
    // (zram swap is compressed RAM, and swapping is slow).
    property real available: 1
    // RAM alone (MemAvailable), and how much of the swap is still free (1
    // without swap).
    property real ram: 1
    property real swapFree: 1
    // % of the last 10 s that some / all processes were stalled on memory.
    property real pressureSome: 0
    property real pressureFull: 0
    // Measured with an app that keeps allocating: pressure stays low almost
    // to the end, and MemAvailable still shows ~10% (cache that can't be
    // freed in time) while swap runs out; the kernel's own last-resort
    // killer strikes ~5 s after swap is gone. So swap running out is the
    // early sign, and critical is decided before that killer acts.
    readonly property string level: (available < 0.04 || (swapFree < 0.05 && ram < 0.15) || pressureFull > 30) ? "critical"
                                  : (available < 0.15 || (swapFree < 0.25 && ram < 0.25) || pressureSome > 40) ? "low" : "ok"

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

    // Every 2 s; every second once memory is low.
    Timer {
        interval: root.level === "ok" ? 2000 : 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            meminfo.reload();
            pressure.reload();
            const m = meminfo.text();
            const total = root.field(m, "MemTotal");
            if (total > 0) {
                const swapTotal = root.field(m, "SwapTotal");
                root.ram = root.field(m, "MemAvailable") / total;
                root.swapFree = swapTotal > 0 ? root.field(m, "SwapFree") / swapTotal : 1;
                root.available = (root.field(m, "MemAvailable") + root.field(m, "SwapFree") / 2) / total;
            }
            const p = pressure.text();
            const some = p.match(/^some avg10=([\d.]+)/m);
            const full = p.match(/^full avg10=([\d.]+)/m);
            root.pressureSome = some ? Number(some[1]) : 0;
            root.pressureFull = full ? Number(full[1]) : 0;
            // Keep the app list fresh while memory is low, so a rescue can
            // act on it at once instead of measuring first.
            if (root.level !== "ok") root.refreshApps();
            if (root.level === "critical") root.rescue();
            root.checkOomKills();
        }
    }

    // ---- low: the macOS window (at most every 10 minutes) ----
    property bool warning: false   // Force Quit window opened by low memory
    property double lastWarning: 0
    onLevelChanged: {
        if (level === "ok") return;
        if (level === "critical") return;   // the timer rescues
        if (Date.now() - lastWarning < 10 * 60 * 1000) return;
        lastWarning = Date.now();
        warning = true;
        Panels.forceQuit = true;
    }

    // ---- critical: quit the largest app ----
    property bool rescuing: false
    function rescue() {
        if (rescuing) return;
        const top = apps[0];
        if (!top || top.kib <= 0) { refreshApps(); return; }   // nothing measured yet: next second
        rescuing = true;
        const id = Apps.idForToplevel({ appId: top.class }) || top.class;
        const name = Apps.nameFor(id) || top.class;
        apps = apps.slice(1);
        console.info(`Memory: quitting ${top.class} (${formatKib(top.kib)}) before memory runs out`);
        // At once: there may be seconds left before the system stalls. Only
        // say so if it worked (the kernel may have been quicker; then the
        // oom-kill watch below reports it).
        notifyQuit(name, id, ["kill", "-KILL"].concat(top.pids.map(String)));
        cooldown.restart();
    }

    // KDE's "Memory Shortage Avoided", with Reopen; after `cmd` succeeds,
    // if one is given.
    function notifyQuit(name, id, cmd) {
        lastNotified = Date.now();
        Quickshell.execDetached(["sh", "-c",
            '[ -n "$6" ] && { eval "$6" 2>/dev/null || exit 0; }; '
            + 'a=$(notify-send -a "$1" -i dialog-warning -u critical -A reopen="$4" "$2" "$3"); '
            + '[ "$a" = reopen ] && exec foxtail-ipc launchApp "$5"',
            "sh", I18n.tr("Memory"), I18n.tr("Memory Shortage Avoided"),
            I18n.tr("%1 was quit because your computer ran out of memory.").arg(name),
            I18n.tr("Reopen"), id, cmd ? cmd.join(" ") : ""]);
    }
    property double lastNotified: 0

    // ---- oom kill: the kernel was quicker ----
    // The session's cgroup counts kernel OOM kills (memory.events). The app
    // that was killed is the one whose windows were open a moment ago and
    // are gone now.
    FileView { id: selfCgroup; path: "/proc/self/cgroup"; blockLoading: true }
    readonly property string cgroupEvents: {
        const m = selfCgroup.text().match(/^0::(\S+)$/m);
        return m ? "/sys/fs/cgroup" + m[1] + "/memory.events" : "";
    }
    FileView { id: events; path: root.cgroupEvents }
    property int oomKills: -1
    property var openIds: []      // app ids with windows, as of the last tick
    property var beforeOom: null  // openIds from just before a kill
    property int oomChecks: 0
    function runningIds() {
        const ids = [];
        for (const t of Apps.toplevels) {
            const id = Apps.idForToplevel(t);
            if (id && ids.indexOf(id) < 0) ids.push(id);
        }
        return ids;
    }
    function checkOomKills() {
        const now = runningIds();
        // Windows close a moment after their app dies: look for a few ticks.
        if (beforeOom) {
            const gone = beforeOom.find(id => now.indexOf(id) < 0);
            if (gone || ++oomChecks > 4) {
                console.info(`Memory: the kernel quit ${gone ?? "a process without windows"} (out of memory)`);
                if (gone && Date.now() - lastNotified > 5000) notifyQuit(Apps.nameFor(gone) || gone, gone, null);
                beforeOom = null;
            }
        }
        if (cgroupEvents) {
            events.reload();
            const m = events.text().match(/^oom_kill (\d+)$/m);
            if (m) {
                const n = Number(m[1]);
                if (oomKills >= 0 && n > oomKills && !beforeOom) { beforeOom = openIds; oomChecks = 0; }
                oomKills = n;
            }
        }
        openIds = now;
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
