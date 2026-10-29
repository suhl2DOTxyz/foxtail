import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.components

// Emoji & Symbols (⌃⌘Space), like macOS's compact Character Viewer: search,
// categories along the bottom, recently used first. Picking one types it
// into the app you were using.
Item {
    id: root

    property point windowOffset
    property size screenSize

    width: 8 * 42 + 24
    height: 400

    // Emoji 12 test data from Unicode (shell/data/emoji.json):
    // [{ g: group, e: [[emoji, name], ...] }]
    property var groups: []
    FileView {
        path: Qt.resolvedUrl("../data/emoji.json").toString().replace("file://", "")
        onLoaded: root.groups = JSON.parse(text())
    }

    property int group: Settings.emojiRecent.length ? -1 : 0     // -1 = Frequently Used
    readonly property var icons: ["😀", "🐻", "🍔", "✈️", "⚽", "💡", "❤️", "🏳️"]

    readonly property var shown: {
        const q = search.text.trim().toLowerCase();
        if (q) {
            const out = [];
            for (const g of groups) for (const e of g.e) if (e[1].indexOf(q) >= 0) out.push(e);
            return out.slice(0, 200);
        }
        if (group < 0) return Settings.emojiRecent.map(c => [c, ""]);
        return groups[group]?.e ?? [];
    }
    readonly property string title: search.text.trim() ? "Search Results"
                                  : group < 0 ? "Frequently Used" : (groups[group]?.g ?? "")

    function pick(e) {
        Settings.emojiRecent = [e].concat(Settings.emojiRecent.filter(x => x !== e)).slice(0, 24);
        Panels.closeAll();
        // Let focus return to the app, then type it there.
        Quickshell.execDetached(["sh", "-c", 'sleep 0.15; exec wtype -- "$1"', "sh", e]);
    }

    scale: 0.95
    opacity: 0
    Component.onCompleted: { scale = 1; opacity = 1; search.forceActiveFocus(); }
    Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

    MouseArea { anchors.fill: parent }

    Glass {
        anchors.fill: parent
        radius: Theme.liquid ? 24 : 12
        color: Theme.glassStrong
        windowOffset: root.windowOffset
        screenSize: root.screenSize
        rimOpacity: 0.85
    }

    // Search
    Rectangle {
        id: searchBox
        x: 12; y: 12
        width: parent.width - 24
        height: 30
        radius: 15
        color: Theme.control
        Icon { id: mag; x: 10; anchors.verticalCenter: parent.verticalCenter; size: 13; name: "search"; color: Theme.textSecondary }
        TextInput {
            id: search
            anchors.left: mag.right
            anchors.leftMargin: 8
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            font.family: Theme.font
            font.pixelSize: Theme.px(13)
            color: Theme.text
            selectionColor: Theme.accent
            clip: true
            Label { visible: !search.text; text: I18n.tr("Search"); color: Theme.textTertiary; anchors.verticalCenter: parent.verticalCenter }
            Keys.onEscapePressed: Panels.closeAll()
            Keys.onReturnPressed: if (root.shown.length) root.pick(root.shown[0][0])
        }
    }

    Label {
        x: 16
        y: searchBox.y + searchBox.height + 10
        text: root.title
        font.pixelSize: Theme.px(11)
        font.weight: Font.DemiBold
        color: Theme.textSecondary
    }

    GridView {
        id: grid
        x: 12
        y: searchBox.y + searchBox.height + 30
        width: parent.width - 24
        height: parent.height - y - 46
        cellWidth: 42
        cellHeight: 42
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: root.shown
        delegate: Item {
            id: cell
            required property var modelData
            width: 42; height: 42
            Rectangle {
                anchors.fill: parent
                anchors.margins: 2
                radius: 8
                color: cellMouse.containsMouse ? Theme.hover : "transparent"
            }
            Text {
                anchors.centerIn: parent
                text: cell.modelData[0]
                font.family: "Twemoji"
                font.pixelSize: Theme.px(26)
            }
            MouseArea {
                id: cellMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: root.pick(cell.modelData[0])
            }
        }
    }

    // Categories
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        spacing: 2
        Repeater {
            model: [-1].concat(root.groups.map((g, i) => i))
            Rectangle {
                id: tab
                required property int modelData
                readonly property bool on: root.group === modelData && !search.text
                width: 34; height: 30
                radius: 8
                color: on ? Theme.pressed : (tabMouse.containsMouse ? Theme.hover : "transparent")
                Icon { visible: tab.modelData < 0; anchors.centerIn: parent; size: 15; name: "clock"; color: Theme.textSecondary }
                Text {
                    visible: tab.modelData >= 0
                    anchors.centerIn: parent
                    text: root.icons[tab.modelData] ?? ""
                    font.family: "Twemoji"
                    font.pixelSize: Theme.px(16)
                    opacity: tab.on ? 1 : 0.6
                }
                MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: { search.text = ""; root.group = tab.modelData; grid.positionViewAtBeginning(); }
                }
            }
        }
    }
}
