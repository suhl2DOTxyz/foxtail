import QtQuick
import Quickshell
import qs.services
import qs.components

// System Settings › Displays: arrangement, resolution, refresh rate, scale,
// rotation, mirroring, brightness and Night Shift.
Column {
    id: pane
    spacing: 14

    Component.onCompleted: Displays.refresh()

    property string selectedName: ""
    readonly property var usable: Displays.monitors
    readonly property var mon: usable.find(m => m.name === selectedName) ?? usable[0] ?? null
    readonly property var cfg: mon ? Displays.config(mon) : null
    readonly property string res: cfg ? cfg.mode.split("@")[0] : ""
    readonly property real hz: cfg ? parseFloat(cfg.mode.split("@")[1] ?? "60") : 60

    // ---------- "Keep these settings?" ----------
    Rectangle {
        visible: Displays.confirming
        width: parent.width
        height: 64
        radius: Theme.liquid ? 18 : 10
        color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
        border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.5)
        Column {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            Label { text: "Keep these display settings?"; font.weight: Font.DemiBold }
            Label { text: `Reverting in ${Displays.countdown} seconds`; font.pixelSize: 12; color: Theme.textSecondary }
        }
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            PushButton { text: "Revert"; onClicked: Displays.revert() }
            PushButton { text: "Keep Changes"; primary: true; onClicked: Displays.keep() }
        }
    }

    // ---------- arrangement ----------
    Rectangle {
        id: arrange
        width: parent.width
        height: 190
        radius: Theme.liquid ? 18 : 10
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.04) : Qt.rgba(0, 0, 0, 0.04)
        border.color: Theme.separator

        readonly property var shown: pane.usable.filter(m => !Displays.config(m).disabled && !Displays.config(m).mirror)
        readonly property var boxes: shown.map(m => {
            const c = Displays.config(m), s = Displays.logicalSize(m);
            return { name: m.name, x: c.x, y: c.y, w: s.w, h: s.h };
        })
        readonly property real minX: Math.min(...boxes.map(b => b.x), 0)
        readonly property real minY: Math.min(...boxes.map(b => b.y), 0)
        readonly property real spanW: Math.max(...boxes.map(b => b.x + b.w), 1) - minX
        readonly property real spanH: Math.max(...boxes.map(b => b.y + b.h), 1) - minY
        readonly property real k: Math.min((width - 60) / spanW, (height - 40) / spanH)
        readonly property real ox: (width - spanW * k) / 2
        readonly property real oy: (height - spanH * k) / 2

        // Snap a dragged display against the nearest other display.
        function drop(name, lx, ly) {
            const me = boxes.find(b => b.name === name);
            const others = boxes.filter(b => b.name !== name);
            if (!me || others.length === 0) return;
            const cx = lx + me.w / 2, cy = ly + me.h / 2;
            let best = null, bestD = Infinity;
            for (const o of others) {
                const d = Math.hypot(cx - (o.x + o.w / 2), cy - (o.y + o.h / 2));
                if (d < bestD) { bestD = d; best = o; }
            }
            const o = best;
            const dx = cx - (o.x + o.w / 2), dy = cy - (o.y + o.h / 2);
            let nx, ny;
            if (Math.abs(dx) / (o.w + me.w) >= Math.abs(dy) / (o.h + me.h)) {
                nx = dx > 0 ? o.x + o.w : o.x - me.w;
                ny = Math.max(o.y - me.h + 40, Math.min(o.y + o.h - 40, ly));
                if (Math.abs(ny - o.y) < 60) ny = o.y;
            } else {
                ny = dy > 0 ? o.y + o.h : o.y - me.h;
                nx = Math.max(o.x - me.w + 40, Math.min(o.x + o.w - 40, lx));
                if (Math.abs(nx - o.x) < 60) nx = o.x;
            }
            // Keep coordinates non-negative: shift everything if needed.
            const placed = boxes.map(b => b.name === name ? Object.assign({}, b, { x: nx, y: ny }) : b);
            const mx = Math.min(...placed.map(b => b.x)), my = Math.min(...placed.map(b => b.y));
            const out = {};
            for (const b of placed) out[b.name] = { x: Math.round(b.x - mx), y: Math.round(b.y - my) };
            Displays.arrange(out);
        }

        Label {
            visible: arrange.shown.length < 2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 8
            text: "Connect another display to arrange it here."
            font.pixelSize: 11
            color: Theme.textTertiary
        }

        Repeater {
            model: arrange.boxes
            Rectangle {
                id: box
                required property var modelData
                readonly property bool selected: pane.mon?.name === modelData.name
                property bool dragging: false
                property real dx: 0
                property real dy: 0
                x: arrange.ox + (modelData.x - arrange.minX) * arrange.k + dx
                y: arrange.oy + (modelData.y - arrange.minY) * arrange.k + dy
                width: modelData.w * arrange.k - 3
                height: modelData.h * arrange.k - 3
                radius: 6
                clip: true
                border.width: selected ? 3 : 1
                border.color: selected ? Theme.accent : Theme.separator
                color: "#2B2B2E"
                Image {
                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    source: "file://" + Settings.wallpaper
                    sourceSize: Qt.size(320, 200)
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.85
                }
                Rectangle {   // menu bar strip
                    x: parent.border.width; y: parent.border.width
                    width: parent.width - 2 * x
                    height: Math.max(3, parent.height * 0.06)
                    color: Qt.rgba(1, 1, 1, 0.7)
                }
                Label {
                    anchors.centerIn: parent
                    text: box.modelData.name
                    color: "white"
                    font.weight: Font.DemiBold
                    font.pixelSize: 11
                    style: Text.Outline
                    styleColor: Qt.rgba(0, 0, 0, 0.4)
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: arrange.shown.length > 1 ? Qt.OpenHandCursor : Qt.ArrowCursor
                    property point start
                    onPressed: m => { pane.selectedName = box.modelData.name; start = mapToItem(arrange, m.x, m.y); }
                    onPositionChanged: m => {
                        if (!pressed || arrange.shown.length < 2) return;
                        const p = mapToItem(arrange, m.x, m.y);
                        box.dragging = true;
                        box.dx += p.x - start.x;
                        box.dy += p.y - start.y;
                        start = p;
                    }
                    onReleased: {
                        if (box.dragging) {
                            const lx = box.modelData.x + box.dx / arrange.k;
                            const ly = box.modelData.y + box.dy / arrange.k;
                            box.dragging = false;
                            box.dx = 0;
                            box.dy = 0;
                            arrange.drop(box.modelData.name, lx, ly);
                        }
                    }
                }
            }
        }
    }

    // ---------- the selected display ----------
    Group {
        visible: pane.mon !== null
        Item {
            width: parent.width
            height: 56
            Rectangle {
                id: dicon
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 32; height: 32; radius: 8
                color: "#0A84FF"
                Icon { anchors.centerIn: parent; size: 18; name: "display"; color: "white" }
            }
            Column {
                anchors.left: dicon.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                Label { text: pane.mon ? (pane.mon.model || pane.mon.description || pane.mon.name) : ""; font.weight: Font.DemiBold }
                Label {
                    text: pane.mon ? `${pane.mon.name} · ${pane.res} · ${Math.round(pane.hz)} Hz` : ""
                    font.pixelSize: 11
                    color: Theme.textSecondary
                }
            }
            Rectangle { anchors.bottom: parent.bottom; x: 14; width: parent.width - 28; height: 1; color: Theme.separator }
        }
        SettingRow {
            label: "Use as"
            visible: pane.usable.length > 1
            Choice {
                options: [["extend", "Extended display"]].concat(
                    pane.usable.filter(m => m.name !== pane.mon?.name).map(m => ["mirror:" + m.name, "Mirror for " + m.name]))
                    .concat([["off", "Turn off"]])
                value: pane.cfg?.disabled ? "off" : (pane.cfg?.mirror ? "mirror:" + pane.cfg.mirror : "extend")
                onPicked: v => Displays.set(pane.mon.name, {
                    disabled: v === "off",
                    mirror: v.startsWith("mirror:") ? v.slice(7) : ""
                }, true)
            }
        }
        SettingRow {
            label: "Resolution"
            Choice {
                options: Displays.resolutions(pane.mon).map(r => [r.key, `${r.w} × ${r.h}`])
                value: pane.res
                onPicked: v => {
                    const rates = Displays.rates(pane.mon, v);
                    const hz = rates.find(r => Math.abs(r - pane.hz) < 0.6) ?? rates[0];
                    Displays.set(pane.mon.name, { mode: `${v}@${hz.toFixed(2)}` }, true);
                }
            }
        }
        SettingRow {
            label: "Refresh rate"
            Choice {
                options: Displays.rates(pane.mon, pane.res).map(r => [r.toFixed(2), `${r.toFixed(r % 1 ? 2 : 0)} Hz`])
                value: pane.hz.toFixed(2)
                onPicked: v => Displays.set(pane.mon.name, { mode: `${pane.res}@${v}` }, true)
            }
        }
        SettingRow {
            label: "Scale"
            sub: "Larger makes text and controls bigger; smaller fits more on screen."
            Choice {
                options: [[1, "100%"], [1.25, "125%"], [1.5, "150%"], [1.666667, "167%"], [2, "200%"], [3, "300%"]]
                value: pane.cfg ? ([1, 1.25, 1.5, 1.666667, 2, 3].find(s => Math.abs(s - pane.cfg.scale) < 0.02) ?? 1) : 1
                onPicked: v => Displays.set(pane.mon.name, { scale: v }, true)
            }
        }
        SettingRow {
            label: "Rotation"
            last: true
            Choice {
                options: [[0, "Standard"], [1, "90°"], [2, "180°"], [3, "270°"]]
                value: (pane.cfg?.transform ?? 0) % 4
                onPicked: v => Displays.set(pane.mon.name, { transform: v }, true)
            }
        }
    }

    Group {
        visible: Brightness.available
        SettingRow {
            label: "Brightness"
            last: true
            PlainSlider { value: Brightness.value; onMoved: v => Brightness.set(v) }
        }
    }

    // ---------- Night Shift ----------
    SectionTitle { text: "Night Shift" }
    Note { text: "Night Shift shifts the colors of your display to the warmer end of the spectrum after dark. This may help you get a better night's sleep." }
    Group {
        SettingRow {
            label: "Turn on now"
            sub: Settings.nightShiftSchedule && Displays.scheduledNow ? "On because of the schedule" : ""
            Switch {
                checked: Displays.nightShiftActive
                onToggled: c => Settings.nightShiftNow = c
            }
        }
        SettingRow {
            label: "Schedule"
            Choice {
                options: [[false, "Off"], [true, "Custom"]]
                value: Settings.nightShiftSchedule
                onPicked: v => Settings.nightShiftSchedule = v
            }
        }
        SettingRow {
            visible: Settings.nightShiftSchedule
            label: "From"
            Row {
                spacing: 8
                readonly property var times: Array.from({ length: 48 }, (_, i) => [i * 30, Displays.formatMinutes(i * 30)])
                Choice { options: parent.times; value: Settings.nightShiftFrom; onPicked: v => Settings.nightShiftFrom = v }
                Label { text: "to"; anchors.verticalCenter: parent.verticalCenter; color: Theme.textSecondary }
                Choice { options: parent.times; value: Settings.nightShiftTo; onPicked: v => Settings.nightShiftTo = v }
            }
        }
        SettingRow {
            label: "Color temperature"
            last: true
            Row {
                spacing: 10
                Label { text: "Less Warm"; font.pixelSize: 11; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                PlainSlider {
                    width: 150
                    anchors.verticalCenter: parent.verticalCenter
                    value: Settings.nightShiftWarmth
                    onMoved: v => Settings.nightShiftWarmth = Math.round(v * 20) / 20
                }
                Label { text: "More Warm"; font.pixelSize: 11; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    PushButton {
        anchors.right: parent.right
        text: "Reset Display Settings"
        enabled: Object.keys(Settings.displays).length > 0
        onClicked: Displays.reset()
    }
}
