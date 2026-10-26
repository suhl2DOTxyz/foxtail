import QtQuick
import Quickshell
import qs.services
import qs.components

// Clipboard history: everything you've copied recently. Type to filter,
// ↑/↓ and Return to paste; the × on an entry forgets it.
Item {
    id: root

    property point windowOffset
    property size screenSize

    width: 560
    height: 58 + Math.min(list.contentHeight, 380) + (shown.length ? 14 : 44)

    property int current: 0
    readonly property var shown: {
        const q = input.text.trim().toLowerCase();
        return q ? Clipboard.items.filter(i => i.text.toLowerCase().indexOf(q) >= 0) : Clipboard.items;
    }
    onShownChanged: current = 0

    opacity: 0
    scale: 0.97
    Component.onCompleted: { Clipboard.refresh(); opacity = 1; scale = 1; input.forceActiveFocus(); }
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }
    Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }

    MouseArea { anchors.fill: parent }

    Glass {
        anchors.fill: parent
        radius: Theme.liquid ? 30 : 16
        color: Theme.glassStrong
        windowOffset: root.windowOffset
        screenSize: root.screenSize
        rimOpacity: 0.85
        bezel: 20
        refraction: 14
    }

    Item {
        id: field
        width: parent.width
        height: 58
        Icon { id: icon; x: 20; anchors.verticalCenter: parent.verticalCenter; size: 20; name: "clipboard"; color: Theme.textSecondary }
        TextInput {
            id: input
            anchors.left: icon.right
            anchors.leftMargin: 12
            anchors.right: clearButton.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 20
            clip: true
            Label {
                visible: !input.text
                anchors.verticalCenter: parent.verticalCenter
                text: "Clipboard History"
                font.pixelSize: 20
                color: Theme.textTertiary
            }
            Keys.onUpPressed: root.current = Math.max(0, root.current - 1)
            Keys.onDownPressed: root.current = Math.min(root.shown.length - 1, root.current + 1)
            Keys.onReturnPressed: if (root.shown[root.current]) Clipboard.paste(root.shown[root.current])
            Keys.onEscapePressed: Panels.closeAll()
        }
        Rectangle {
            id: clearButton
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            visible: Clipboard.items.length > 0
            width: clearLabel.implicitWidth + 20
            height: 24
            radius: 12
            color: clearMouse.containsMouse ? Theme.hover : "transparent"
            Label { id: clearLabel; anchors.centerIn: parent; text: "Clear"; font.pixelSize: 12; color: Theme.textSecondary }
            MouseArea { id: clearMouse; anchors.fill: parent; hoverEnabled: true; onClicked: Clipboard.clear() }
        }
    }

    Rectangle {
        y: field.height
        x: 16
        width: parent.width - 32
        height: 1
        color: Theme.separator
    }

    Label {
        visible: root.shown.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        y: field.height + 14
        text: Settings.clipboardHistory ? (Clipboard.items.length ? "No matches" : "Nothing copied yet")
                                        : "Clipboard history is turned off in System Settings › Keyboard"
        color: Theme.textSecondary
    }

    ListView {
        id: list
        x: 8
        y: field.height + 7
        width: parent.width - 16
        height: Math.min(contentHeight, 380)
        clip: true
        model: root.shown
        currentIndex: root.current
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
        delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            width: ListView.view.width
            height: 34
            radius: Theme.liquid ? 12 : 7
            color: index === root.current ? Theme.accent : "transparent"
            readonly property color fg: index === root.current ? "white" : Theme.text
            Icon {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                size: 14
                name: row.modelData.image ? "photo" : "clipboard"
                color: row.index === root.current ? "white" : Theme.textSecondary
            }
            Label {
                x: 36
                width: parent.width - 80
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.text.replace(/\s+/g, " ")
                color: row.fg
                elide: Text.ElideRight
            }
            Icon {
                anchors.right: parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                visible: rowMouse.containsMouse
                size: 11
                name: "xmark"
                color: row.fg
                MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: Clipboard.remove(row.modelData) }
            }
            MouseArea {
                id: rowMouse
                anchors.fill: parent
                anchors.rightMargin: 34
                hoverEnabled: true
                onEntered: root.current = row.index
                onClicked: Clipboard.paste(row.modelData)
            }
        }
    }
}
