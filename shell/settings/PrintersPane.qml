import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// System Settings › Printers & Scanners. Lists CUPS printers and picks the
// default; adding, removing and configuring printers opens the printer tool.
Column {
    id: pane
    spacing: 14

    property var printers: []      // [{ name, state, uri }]
    property string defaultPrinter: ""
    property bool cupsUp: true

    function refresh() { lister.running = true; }
    Component.onCompleted: refresh()
    Timer { interval: 5000; running: true; repeat: true; onTriggered: pane.refresh() }

    Process {
        id: lister
        command: ["sh", "-c", "systemctl is-active --quiet cups.socket cups.service || systemctl is-active --quiet cups.service || echo DOWN; lpstat -d 2>/dev/null; lpstat -p 2>/dev/null; lpstat -v 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                const uris = {};
                pane.cupsUp = text.indexOf("DOWN") !== 0;
                pane.defaultPrinter = "";
                for (const l of text.split("\n")) {
                    let m;
                    if ((m = /^system default destination: (\S+)/.exec(l))) pane.defaultPrinter = m[1];
                    else if ((m = /^printer (\S+) (?:is )?(idle|now printing|disabled)/.exec(l))) list.push({ name: m[1], state: m[2] });
                    else if ((m = /^device for (\S+): (\S+)/.exec(l))) uris[m[1]] = m[2];
                }
                for (const p of list) p.uri = uris[p.name] ?? "";
                pane.printers = list;
            }
        }
    }

    function kind(uri) {
        if (uri.startsWith("usb:")) return "USB";
        if (uri.startsWith("ipp") || uri.startsWith("dnssd") || uri.startsWith("socket") || uri.startsWith("lpd")) return "Network";
        return "";
    }
    function stateText(s) {
        return s === "idle" ? "Idle" : s === "now printing" ? "Printing" : "Paused";
    }

    Group {
        visible: !pane.cupsUp
        SettingRow {
            label: "The printing service is off"
            sub: "Turn it on to use printers. It starts only when something is printed."
            last: true
            PushButton {
                text: "Turn On"
                onClicked: Quickshell.execDetached(["systemctl", "enable", "--now", "cups.socket", "avahi-daemon.service"])
            }
        }
    }

    Group {
        visible: pane.printers.length > 0
        Repeater {
            model: pane.printers
            SettingRow {
                id: prow
                required property var modelData
                required property int index
                icon: "printer"
                iconColor: Theme.text
                label: modelData.name.replace(/_/g, " ")
                sub: [pane.stateText(modelData.state), pane.kind(modelData.uri), modelData.name === pane.defaultPrinter ? "Default" : ""].filter(x => x).join(" · ")
                last: index === pane.printers.length - 1
                Row {
                    spacing: 6
                    PushButton {
                        visible: prow.modelData.name !== pane.defaultPrinter
                        text: "Make Default"
                        onClicked: { Quickshell.execDetached(["lpoptions", "-d", prow.modelData.name]); refreshSoon.restart(); }
                    }
                    PushButton {
                        text: "Options…"
                        onClicked: Quickshell.execDetached(["system-config-printer"])
                    }
                }
            }
        }
    }
    Timer { id: refreshSoon; interval: 500; onTriggered: pane.refresh() }

    Note {
        visible: pane.printers.length === 0 && pane.cupsUp
        text: "No printers yet. Most network printers are found automatically when you print; to set one up permanently, or to add a USB printer, click Add Printer."
    }
    Row {
        spacing: 8
        PushButton { text: "Add Printer…"; onClicked: Quickshell.execDetached(["system-config-printer"]) }
    }
}
