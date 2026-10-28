import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// Desktop widgets, as on macOS Sonoma and later: glass tiles that sit on the
// wallpaper under all windows. Drag them anywhere (positions snap to a grid
// and are saved); right-click or the desktop menu ▸ Edit Widgets… opens the
// gallery to add and remove them.
//
// Settings.desktopWidgets: [{ id, kind, x, y }], kinds below.
Item {
    id: root

    property size screenSize
    property point windowOffset
    signal contextMenu(var model, real x, real y)

    readonly property real small: 158
    readonly property real gap: 20
    readonly property var kinds: [
        { kind: "clock", name: I18n.tr("Clock"), w: 1 },
        { kind: "calendar", name: I18n.tr("Calendar"), w: 1 },
        { kind: "battery", name: I18n.tr("Battery"), w: 1 },
        { kind: "system", name: I18n.tr("System"), w: 1 },
        { kind: "notes", name: I18n.tr("Notes"), w: 2 }
    ]
    function info(kind) { return kinds.find(k => k.kind === kind) ?? kinds[0]; }
    function widthOf(kind) { return info(kind).w === 2 ? small * 2 + gap : small; }

    // ---- placement ----
    function freeSpot(kind) {
        const w = widthOf(kind), h = small;
        const taken = Settings.desktopWidgets.map(d => Qt.rect(d.x, d.y, widthOf(d.kind), small));
        for (let y = 24; y + h < height - 120; y += small + gap)
            for (let x = 24; x + w < width - 140; x += small + gap) {
                const r = Qt.rect(x, y, w, h);
                if (!taken.some(t => r.x < t.x + t.width + 8 && t.x < r.x + r.width + 8
                                     && r.y < t.y + t.height + 8 && t.y < r.y + r.height + 8))
                    return Qt.point(x, y);
            }
        return Qt.point(24, 24);
    }
    function add(kind) {
        const p = freeSpot(kind);
        Settings.desktopWidgets = Settings.desktopWidgets.concat([{ id: String(Date.now()), kind: kind, x: p.x, y: p.y }]);
    }
    function remove(id) {
        Settings.desktopWidgets = Settings.desktopWidgets.filter(d => d.id !== id);
    }
    function moveTo(id, x, y) {
        const snap = v => Math.round(v / 8) * 8;
        Settings.desktopWidgets = Settings.desktopWidgets.map(d => d.id === id
            ? Object.assign({}, d, { x: snap(Math.max(8, Math.min(x, width - widthOf(d.kind) - 8))),
                                     y: snap(Math.max(8, Math.min(y, height - small - 8))) })
            : d);
    }

    // ---- shared data ----
    property date now: new Date()
    Timer {
        interval: 1000
        running: Settings.desktopWidgets.length > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    // CPU and memory for the System widget, sampled every 2 s while it's shown.
    readonly property bool wantsStats: Settings.desktopWidgets.some(d => d.kind === "system")
    property real cpu: 0
    property real mem: 0
    property var lastCpu: null
    FileView { id: stat; path: "/proc/stat"; blockLoading: true }
    FileView { id: meminfo; path: "/proc/meminfo"; blockLoading: true }
    Timer {
        interval: 2000
        running: root.wantsStats
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload(); meminfo.reload();
            const f = (stat.text().split("\n")[0] ?? "").trim().split(/\s+/).slice(1).map(Number);
            if (f.length >= 4) {
                const idle = f[3] + (f[4] ?? 0), total = f.reduce((a, b) => a + b, 0);
                if (root.lastCpu) {
                    const dt = total - root.lastCpu.total;
                    root.cpu = dt > 0 ? Math.max(0, Math.min(1, 1 - (idle - root.lastCpu.idle) / dt)) : 0;
                }
                root.lastCpu = { idle: idle, total: total };
            }
            const m = meminfo.text();
            const kb = k => Number((m.match(new RegExp("^" + k + ":\\s+(\\d+)", "m")) ?? [0, 0])[1]);
            const total = kb("MemTotal");
            root.mem = total > 0 ? 1 - kb("MemAvailable") / total : 0;
        }
    }

    // The Notes widget shows (and opens) ~/Documents/Notes.txt.
    readonly property string notesPath: Quickshell.env("HOME") + "/Documents/Notes.txt"
    FileView { id: notes; path: root.notesPath; watchChanges: true; printErrors: false; onFileChanged: reload() }

    // ---- the widgets ----
    Repeater {
        model: Settings.desktopWidgets

        Item {
            id: w
            required property var modelData
            x: modelData.x
            y: modelData.y
            width: root.widthOf(modelData.kind)
            height: root.small
            z: drag.drag.active ? 10 : 0

            Accessible.role: Accessible.Grouping
            Accessible.name: root.info(modelData.kind).name

            scale: drag.pressed && drag.drag.active ? 1.04 : 1
            Behavior on scale { NumberAnimation { duration: Theme.animFast } }

            Glass {
                anchors.fill: parent
                radius: 24
                color: Theme.glassStrong
                screenSize: root.screenSize
                windowOffset: root.windowOffset
                bezel: 16
                shadowStrength: 0.8
            }

            Loader {
                anchors.fill: parent
                anchors.margins: 14
                sourceComponent: {
                    switch (w.modelData.kind) {
                    case "clock": return clockW;
                    case "calendar": return calendarW;
                    case "battery": return batteryW;
                    case "system": return systemW;
                    case "notes": return notesW;
                    }
                    return null;
                }
            }

            MouseArea {
                id: drag
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                drag.target: w
                drag.threshold: 6
                cursorShape: drag.drag.active ? Qt.ClosedHandCursor : Qt.ArrowCursor
                onReleased: if (drag.drag.active || w.x !== w.modelData.x || w.y !== w.modelData.y) root.moveTo(w.modelData.id, w.x, w.y)
                onClicked: m => {
                    if (m.button === Qt.RightButton) {
                        const p = mapToItem(root, m.x, m.y);
                        root.contextMenu([
                            { text: I18n.tr("Remove Widget"), action: () => root.remove(w.modelData.id) },
                            { separator: true },
                            { text: I18n.tr("Edit Widgets…"), action: () => Panels.editingWidgets = true }
                        ], p.x, p.y);
                    } else if (!Panels.editingWidgets && w.modelData.kind === "notes") {
                        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && touch "$1" && xdg-open "$1"', "sh", root.notesPath]);
                    } else if (!Panels.editingWidgets && w.modelData.kind === "calendar") {
                        Panels.popover = "notifications";
                    }
                }
            }

            // Edit mode: a remove button on the corner, like macOS.
            Rectangle {
                visible: Panels.editingWidgets
                x: -8; y: -8
                width: 24; height: 24; radius: 12
                color: Theme.dark ? "#3A3A3C" : "#E5E5EA"
                border.width: 1
                border.color: Theme.separator
                Icon { anchors.centerIn: parent; size: 12; name: "minus"; color: Theme.text }
                MouseArea { anchors.fill: parent; anchors.margins: -4; onClicked: root.remove(w.modelData.id) }
                Accessible.role: Accessible.Button
                Accessible.name: I18n.tr("Remove Widget")
            }
        }
    }

    // ---- gallery (edit mode) ----
    Item {
        id: gallery
        visible: opacity > 0
        opacity: Panels.editingWidgets ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 110
        width: galleryRow.implicitWidth + 40
        height: 214

        MouseArea { anchors.fill: parent }   // clicks on the sheet stay here

        Glass {
            anchors.fill: parent
            radius: 30
            color: Theme.glassStrong
            screenSize: root.screenSize
            windowOffset: root.windowOffset
        }
        Label {
            x: 22; y: 16
            text: I18n.tr("Widgets")
            font.pixelSize: Theme.px(15)
            font.weight: Font.DemiBold
        }
        Rectangle {
            anchors.right: parent.right
            anchors.rightMargin: 16
            y: 12
            width: doneLabel.implicitWidth + 28
            height: 28
            radius: 14
            color: Theme.accent
            Label { id: doneLabel; anchors.centerIn: parent; text: I18n.tr("Done"); color: "white"; font.weight: Font.DemiBold }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Panels.editingWidgets = false }
            Accessible.role: Accessible.Button
            Accessible.name: I18n.tr("Done")
        }
        Row {
            id: galleryRow
            x: 20
            y: 56
            spacing: 14
            Repeater {
                model: root.kinds
                Column {
                    required property var modelData
                    spacing: 6
                    Rectangle {
                        width: modelData.w === 2 ? 236 : 112
                        height: 112
                        radius: 20
                        color: Theme.tile
                        border.width: 1
                        border.color: Theme.separator
                        Icon {
                            anchors.centerIn: parent
                            size: 34
                            color: Theme.accent
                            name: ({ clock: "clock", calendar: "calendar", battery: "battery", system: "gear", notes: "doc" })[modelData.kind]
                        }
                        Rectangle {   // the "+" badge
                            x: -6; y: -6
                            width: 24; height: 24; radius: 12
                            color: "#34C759"
                            Icon { anchors.centerIn: parent; size: 12; name: "plus"; color: "white" }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.add(modelData.kind) }
                        Accessible.role: Accessible.Button
                        Accessible.name: I18n.tr("Add %1").replace("%1", modelData.name)
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.name
                        font.pixelSize: Theme.px(12)
                    }
                }
            }
        }
    }

    // ================= widget faces =================

    // Analog clock, like the macOS Clock widget.
    Component {
        id: clockW
        Item {
            id: clock
            readonly property real h: root.now.getHours() % 12 + root.now.getMinutes() / 60
            readonly property real m: root.now.getMinutes() + root.now.getSeconds() / 60
            readonly property real s: root.now.getSeconds()
            Rectangle {
                id: face
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height)
                height: width
                radius: width / 2
                color: Theme.dark ? "#1C1C1E" : "#FFFFFF"
                border.width: 1
                border.color: Theme.separator
                Repeater {
                    model: 12
                    Item {
                        required property int index
                        anchors.fill: parent
                        rotation: index * 30
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: 6
                            width: index % 3 === 0 ? 3 : 1.5
                            height: index % 3 === 0 ? 9 : 6
                            radius: 1
                            color: Theme.textSecondary
                        }
                    }
                }
                Hand { angle: clock.h * 30; length: face.width * 0.26; thickness: 4 }
                Hand { angle: clock.m * 6; length: face.width * 0.38; thickness: 3 }
                Hand { angle: clock.s * 6; length: face.width * 0.42; thickness: 1.5; tint: Theme.accent }
                Rectangle { anchors.centerIn: parent; width: 7; height: 7; radius: 3.5; color: Theme.accent }
            }
        }
    }

    // Today, and this month.
    Component {
        id: calendarW
        Column {
            id: cal
            spacing: 2
            readonly property date first: new Date(root.now.getFullYear(), root.now.getMonth(), 1)
            readonly property int startDay: I18n.locale.firstDayOfWeek % 7
            readonly property int lead: (first.getDay() - startDay + 7) % 7
            readonly property int days: new Date(root.now.getFullYear(), root.now.getMonth() + 1, 0).getDate()
            Label {
                text: I18n.date(root.now, "MMMM").toUpperCase()
                color: "#FF3B30"
                font.pixelSize: Theme.px(10)
                font.weight: Font.Bold
            }
            Grid {
                columns: 7
                columnSpacing: 0
                rowSpacing: 0
                Repeater {
                    model: 7
                    Label {
                        required property int index
                        width: 18.5; height: 15
                        horizontalAlignment: Text.AlignHCenter
                        text: I18n.locale.dayName((index + cal.startDay) % 7, Locale.NarrowFormat)
                        color: Theme.textSecondary
                        font.pixelSize: Theme.px(8)
                        font.weight: Font.DemiBold
                    }
                }
                Repeater {
                    model: cal.lead + cal.days
                    Item {
                        required property int index
                        readonly property int day: index - cal.lead + 1
                        readonly property bool today: day === root.now.getDate()
                        width: 18.5; height: 16
                        Rectangle {
                            visible: parent.today
                            anchors.centerIn: parent
                            width: 16; height: 16; radius: 8
                            color: "#FF3B30"
                        }
                        Label {
                            anchors.centerIn: parent
                            visible: parent.day > 0
                            text: parent.day
                            color: parent.today ? "white" : Theme.text
                            font.pixelSize: Theme.px(9)
                            font.weight: parent.today ? Font.Bold : Font.Normal
                        }
                    }
                }
            }
        }
    }

    // Battery ring (or the power adapter on a desktop computer).
    Component {
        id: batteryW
        Item {
            Ring {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 4
                size: 84
                value: Power.hasBattery ? Power.percent / 100 : 1
                tint: !Power.hasBattery ? "#30D158" : Power.percent < 20 && !Power.charging ? "#FF453A" : "#30D158"
                Icon {
                    anchors.centerIn: parent
                    size: 24
                    name: Power.charging || !Power.hasBattery ? "bolt" : "battery"
                    color: Theme.text
                }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                text: Power.hasBattery ? Power.percent + "%" : I18n.tr("Power Adapter")
                font.pixelSize: Theme.px(Power.hasBattery ? 17 : 12)
                font.weight: Font.DemiBold
            }
        }
    }

    // CPU and memory, like Activity Monitor at a glance.
    Component {
        id: systemW
        Item {
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 10
                spacing: 12
                Repeater {
                    model: [{ label: "CPU", v: root.cpu, tint: Theme.accent },
                            { label: I18n.tr("Memory"), v: root.mem, tint: "#0A84FF" }]
                    Column {
                        required property var modelData
                        spacing: 8
                        Ring {
                            size: 54
                            value: modelData.v
                            tint: modelData.tint
                            Label {
                                anchors.centerIn: parent
                                text: Math.round(modelData.v * 100) + "%"
                                font.pixelSize: Theme.px(11)
                                font.weight: Font.DemiBold
                            }
                        }
                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: modelData.label
                            color: Theme.textSecondary
                            font.pixelSize: Theme.px(11)
                        }
                    }
                }
            }
        }
    }

    // The start of ~/Documents/Notes.txt; click to open it.
    Component {
        id: notesW
        Column {
            spacing: 6
            Row {
                spacing: 6
                Icon { size: 14; name: "doc"; color: "#FFCC00"; anchors.verticalCenter: parent.verticalCenter }
                Label { text: I18n.tr("Notes"); color: "#FFB800"; font.weight: Font.Bold; font.pixelSize: Theme.px(12) }
            }
            Text {
                width: parent.width
                height: parent.height - 26
                text: notes.text().trim() || I18n.tr("Click to write a note.")
                color: notes.text().trim() ? Theme.text : Theme.textSecondary
                font.family: Theme.font
                font.pixelSize: Theme.px(12)
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                clip: true
                lineHeight: 1.15
            }
        }
    }

    // A clock hand, pivoting on the centre of its parent.
    component Hand: Item {
        property real angle
        property real length
        property real thickness
        property color tint: Theme.text
        anchors.fill: parent
        rotation: angle
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 - parent.length
            width: parent.thickness
            height: parent.length + 8
            radius: width / 2
            color: parent.tint
            antialiasing: true
        }
    }

    // A progress ring.
    component Ring: Item {
        id: ring
        property real size: 60
        property real value: 0
        property color tint: Theme.accent
        width: size; height: size
        Canvas {
            anchors.fill: parent
            property real v: ring.value
            property color c: ring.tint
            onVChanged: requestPaint()
            onCChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                const r = width / 2 - 5;
                ctx.reset();
                ctx.lineWidth = 7;
                ctx.lineCap = "round";
                ctx.strokeStyle = Theme.dark ? "rgba(255,255,255,0.14)" : "rgba(0,0,0,0.08)";
                ctx.beginPath(); ctx.arc(width / 2, height / 2, r, 0, Math.PI * 2); ctx.stroke();
                ctx.strokeStyle = c;
                ctx.beginPath();
                ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.001, Math.min(1, v)));
                ctx.stroke();
            }
        }
    }
}
