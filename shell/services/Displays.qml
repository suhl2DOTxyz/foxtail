pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Connected displays (from Hyprland), their saved settings, and Night Shift.
//
// Settings are stored per output in Settings.displays and turned into
// Hyprland monitor rules by HyprConfig. A change that could leave the screen
// unusable (resolution, scale, rotation) must be confirmed within 15 seconds,
// as on macOS, or it is reverted.
Singleton {
    id: root

    // hyprctl monitors all -j: name, description, width, height, refreshRate,
    // x, y, scale, transform, availableModes, disabled, mirrorOf ...
    property var monitors: []
    readonly property var active: monitors.filter(m => !m.disabled)

    // Pending confirmation
    property var previous: null
    property int countdown: 0
    readonly property bool confirming: previous !== null

    function refresh() { query.running = true; }

    Process {
        id: query
        running: true
        command: ["hyprctl", "monitors", "all", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.monitors = JSON.parse(text).sort((a, b) => a.x - b.x || a.y - b.y); } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2", "configreloaded"].indexOf(event.name) >= 0)
                refreshSoon.restart();
        }
    }
    Timer { id: refreshSoon; interval: 300; onTriggered: root.refresh() }

    // "1920x1080@60.00Hz" -> { w, h, hz }
    function parseMode(s) {
        const m = /^(\d+)x(\d+)@([\d.]+)/.exec(s);
        return m ? { w: +m[1], h: +m[2], hz: +m[3] } : null;
    }
    function modes(mon) {
        return (mon?.availableModes ?? []).map(parseMode).filter(m => m);
    }
    function resolutions(mon) {
        const seen = {};
        const out = [];
        for (const m of modes(mon)) {
            const k = m.w + "x" + m.h;
            if (seen[k]) continue;
            seen[k] = true;
            out.push({ key: k, w: m.w, h: m.h });
        }
        return out.sort((a, b) => b.w * b.h - a.w * a.h);
    }
    function rates(mon, res) {
        const out = [];
        for (const m of modes(mon))
            if (m.w + "x" + m.h === res && out.indexOf(m.hz) < 0) out.push(m.hz);
        return out.sort((a, b) => b - a);
    }

    // The saved (or current) settings for an output.
    function config(mon) {
        const saved = Settings.displays[mon.name] ?? {};
        return {
            mode: saved.mode ?? `${mon.width}x${mon.height}@${mon.refreshRate.toFixed(2)}`,
            scale: saved.scale ?? mon.scale,
            x: saved.x ?? mon.x,
            y: saved.y ?? mon.y,
            transform: saved.transform ?? mon.transform,
            mirror: saved.mirror ?? "",
            disabled: saved.disabled ?? false
        };
    }

    // Change settings for one output. `risky` changes need confirming.
    function set(name, changes, risky) {
        const mon = monitors.find(m => m.name === name);
        if (!mon) return;
        const all = JSON.parse(JSON.stringify(Settings.displays));
        if (risky && !confirming) {
            previous = JSON.parse(JSON.stringify(Settings.displays));
            countdown = 15;
            tick.restart();
        }
        all[name] = Object.assign(config(mon), changes);
        Settings.displays = all;
    }

    // Place `name` next to `other`; side = "left" | "right" | "above" | "below".
    function arrange(positions) {
        const all = JSON.parse(JSON.stringify(Settings.displays));
        for (const name in positions) {
            const mon = monitors.find(m => m.name === name);
            if (!mon) continue;
            all[name] = Object.assign(config(mon), positions[name]);
        }
        Settings.displays = all;
    }

    function keep() {
        previous = null;
        tick.stop();
    }
    function revert() {
        if (previous === null) return;
        Settings.displays = previous;
        previous = null;
        tick.stop();
    }
    function reset() {
        keep();
        Settings.displays = ({});
    }
    Timer {
        id: tick
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdown -= 1;
            if (root.countdown <= 0) root.revert();
        }
    }

    // Logical size (what apps see) of an output at its scale and rotation.
    function logicalSize(mon) {
        const c = config(mon);
        const m = parseMode(c.mode) ?? { w: mon.width, h: mon.height };
        const rot = c.transform % 2 === 1;
        return { w: Math.round((rot ? m.h : m.w) / c.scale), h: Math.round((rot ? m.w : m.h) / c.scale) };
    }

    // ---------------- Night Shift ----------------
    readonly property int temperature: Math.round(5500 - Settings.nightShiftWarmth * 2600)
    property int nowMinutes: 0
    readonly property bool scheduledNow: {
        if (!Settings.nightShiftSchedule) return false;
        const a = Settings.nightShiftFrom, b = Settings.nightShiftTo, t = nowMinutes;
        return a <= b ? (t >= a && t < b) : (t >= a || t < b);
    }
    readonly property bool nightShiftActive: Settings.nightShiftNow || scheduledNow

    function updateClock() {
        const d = new Date();
        nowMinutes = d.getHours() * 60 + d.getMinutes();
    }
    Component.onCompleted: updateClock()
    Timer { interval: 30000; running: true; repeat: true; onTriggered: root.updateClock() }

    // When the schedule ends, a manual "on" ends with it (macOS: "until tomorrow").
    onScheduledNowChanged: if (!scheduledNow && Settings.nightShiftSchedule) Settings.nightShiftNow = false

    Process {
        id: sunset
        running: root.nightShiftActive
        command: ["hyprsunset", "-t", String(root.temperature)]
    }
    // hyprsunset reads the temperature at start; restart it to apply a new one.
    onTemperatureChanged: if (sunset.running) restartSunset.restart()
    Timer {
        id: restartSunset
        interval: 250
        onTriggered: { sunset.running = false; sunset.running = Qt.binding(() => root.nightShiftActive); }
    }

    function formatMinutes(m) {
        const d = new Date(2000, 0, 1, Math.floor(m / 60), m % 60);
        return Qt.formatTime(d, Settings.clock24h ? "HH:mm" : "h:mm AP");
    }
}
