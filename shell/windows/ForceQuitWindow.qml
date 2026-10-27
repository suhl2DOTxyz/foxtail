import QtQuick
import Quickshell
import qs.services
import qs.components

// Force Quit Applications (⌥⌘⎋).
FloatingWindow {
    id: win

    title: I18n.tr("Force Quit Applications")
    visible: Panels.forceQuit
    onVisibleChanged: if (!visible) Panels.forceQuit = false
    implicitWidth: 380
    implicitHeight: 400
    color: "transparent"

    property var selected: null

    readonly property var apps: {
        const seen = {};
        const out = [];
        for (const t of Apps.toplevels) {
            const id = Apps.idForToplevel(t);
            if (!id || seen[id]) continue;
            seen[id] = true;
            out.push({ id, name: Apps.nameFor(id), icon: Apps.iconFor(id) });
        }
        return out;
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.windowRadius
        color: Theme.dark ? "#262628" : "#F3F3F5"
        border.color: Theme.glassOutline
    }

    TrafficLights { x: 14; y: 14; onClose: Panels.forceQuit = false; onMinimize: Panels.forceQuit = false }

    Label {
        x: 20; y: 44
        width: parent.width - 40
        wrapMode: Text.Wrap
        elide: Text.ElideNone
        text: I18n.tr("If an app doesn't respond for a while, select its name and click Force Quit.")
        font.pixelSize: Theme.px(12)
    }

    Rectangle {
        x: 20; y: 84
        width: parent.width - 40
        height: parent.height - 140
        radius: 6
        color: Theme.dark ? "#1C1C1E" : "white"
        border.color: Theme.separator
        clip: true

        ListView {
            anchors.fill: parent
            anchors.margins: 4
            model: win.apps
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 28
                radius: 4
                color: win.selected === modelData.id ? Theme.accent : "transparent"
                Image { x: 8; anchors.verticalCenter: parent.verticalCenter; width: 20; height: 20; sourceSize: Qt.size(40, 40); source: modelData.icon }
                Label {
                    x: 36
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name
                    color: win.selected === modelData.id ? "white" : Theme.text
                }
                MouseArea { anchors.fill: parent; onClicked: win.selected = modelData.id }
            }
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        width: 100; height: 26
        radius: Theme.liquid ? 13 : 6
        color: win.selected ? Theme.accent : Theme.control
        Label { anchors.centerIn: parent; text: I18n.tr("Force Quit"); color: win.selected ? "white" : Theme.textTertiary }
        MouseArea {
            anchors.fill: parent
            onClicked: if (win.selected) {
                for (const w of Apps.windowsFor(win.selected)) w.close();
                Quickshell.execDetached(["pkill", "-9", "-f", win.selected]);
                win.selected = null;
            }
        }
    }
}
