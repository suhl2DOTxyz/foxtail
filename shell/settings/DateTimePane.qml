import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// System Settings › Date & Time. Changes go through systemd-timedated, which
// asks for an administrator password.
Column {
    id: pane
    spacing: 14

    property bool ntp: true
    property string zone: ""
    property var zones: []
    property bool picking: false
    property string pick: ""
    property string error: ""

    function refresh() { show.running = true; }
    Component.onCompleted: refresh()

    Process {
        id: show
        command: ["timedatectl", "show", "-p", "Timezone", "-p", "NTP"]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const l of text.split("\n")) {
                    if (l.startsWith("Timezone=")) pane.zone = l.slice(9);
                    if (l.startsWith("NTP=")) pane.ntp = l.slice(4) === "yes";
                }
            }
        }
    }
    Process {
        id: zoneList
        command: ["timedatectl", "list-timezones"]
        stdout: StdioCollector { onStreamFinished: pane.zones = text.trim().split("\n") }
    }
    Process {
        id: change
        stderr: StdioCollector { id: changeErr }
        onExited: code => {
            pane.error = code === 0 ? "" : (changeErr.text.trim() || "The change wasn't allowed.");
            pane.refresh();
        }
    }
    function run(args) {
        change.command = ["timedatectl"].concat(args);
        change.running = true;
    }

    SystemClock { id: clock; precision: Settings.clockSeconds ? SystemClock.Seconds : SystemClock.Minutes }

    Group {
        Item {
            width: parent.width
            height: 70
            Column {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                Label {
                    text: Qt.formatTime(clock.date, Settings.clock24h ? (Settings.clockSeconds ? "HH:mm:ss" : "HH:mm") : (Settings.clockSeconds ? "h:mm:ss AP" : "h:mm AP"))
                    font.pixelSize: Theme.px(26)
                    font.weight: Font.DemiBold
                }
                Label { text: I18n.date(clock.date, I18n.english ? "dddd, MMMM d, yyyy" : "dddd, d. MMMM yyyy"); color: Theme.textSecondary; font.pixelSize: Theme.px(12) }
            }
        }
    }

    Group {
        SettingRow {
            label: I18n.tr("Set time and date automatically")
            sub: I18n.tr("Uses internet time servers.")
            Switch { checked: pane.ntp; onToggled: c => pane.run(["set-ntp", c ? "true" : "false"]) }
        }
        SettingRow {
            label: I18n.tr("Time zone")
            sub: pane.zone.replace(/_/g, " ")
            last: true
            PushButton { text: pane.picking ? "Cancel" : "Change…"; onClicked: { pane.picking = !pane.picking; if (pane.picking && !pane.zones.length) zoneList.running = true; } }
        }
    }
    Column {
        visible: pane.picking
        width: parent.width
        spacing: 8
        TextField { id: filter; width: parent.width; placeholder: "Search cities and regions" }
        ListBox {
            width: parent.width
            height: 220
            current: pane.pick || pane.zone
            model: {
                const q = filter.text.trim().toLowerCase().replace(/ /g, "_");
                return pane.zones.filter(z => !q || z.toLowerCase().indexOf(q) >= 0).map(z => [z, z.replace(/_/g, " ").replace(/\//g, " › ")]);
            }
            onPicked: v => pane.pick = v
        }
        PushButton {
            anchors.right: parent.right
            text: I18n.tr("Set Time Zone")
            primary: true
            enabled: pane.pick !== "" && pane.pick !== pane.zone
            onClicked: { pane.run(["set-timezone", pane.pick]); pane.picking = false; }
        }
    }
    Label {
        visible: pane.error !== ""
        width: parent.width
        wrapMode: Text.Wrap
        text: pane.error
        color: "#FF453A"
        font.pixelSize: Theme.px(12)
    }

    SectionTitle { text: I18n.tr("Clock") }
    Group {
        SettingRow {
            label: I18n.tr("Use 24-hour time")
            Switch { checked: Settings.clock24h; onToggled: c => Settings.clock24h = c }
        }
        SettingRow {
            label: I18n.tr("Show seconds in menu bar")
            last: true
            Switch { checked: Settings.clockSeconds; onToggled: c => Settings.clockSeconds = c }
        }
    }
}
