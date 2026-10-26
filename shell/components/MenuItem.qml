import QtQuick
import qs.services

// One row of a macOS pull-down menu: rounded accent highlight on hover,
// optional checkmark, right-aligned shortcut (⌘C) or submenu chevron.
Item {
    id: root

    property string text
    property string shortcut: ""
    property bool checked: false
    property bool checkable: false
    property bool available: true
    property bool separator: false
    property bool header: false
    property string icon: ""
    // Has a submenu (macOS chevron); `open` while that submenu is showing.
    property bool hasSubmenu: false
    property bool open: false
    readonly property bool highlighted: (mouse.containsMouse || open) && available
    signal triggered()
    signal entered()

    implicitHeight: separator ? 11 : (header ? 24 : 24)
    implicitWidth: separator ? 0 : row.implicitWidth + 24

    Rectangle {
        visible: root.separator
        anchors.centerIn: parent
        width: parent.width - 20
        height: 1
        color: Theme.separator
    }

    Rectangle {
        id: hl
        visible: !root.separator && !root.header
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        radius: Theme.liquid ? 8 : 4
        color: root.highlighted ? Theme.accent : "transparent"
    }

    Row {
        id: row
        visible: !root.separator
        anchors.verticalCenter: parent.verticalCenter
        x: 10
        spacing: 6

        Item {
            width: 14
            height: 14
            visible: root.checkable || root.icon !== ""
            anchors.verticalCenter: parent.verticalCenter
            Icon {
                anchors.centerIn: parent
                size: 12
                name: root.checkable ? (root.checked ? "check" : "") : root.icon
                color: hl.color === Theme.accent ? "white" : Theme.text
            }
        }

        Label {
            text: root.text
            color: root.header ? Theme.textSecondary
                 : !root.available ? Theme.textTertiary
                 : (root.highlighted ? "white" : Theme.text)
            font.weight: root.header ? Font.DemiBold : Font.Normal
            font.pixelSize: root.header ? 11 : Theme.fontSize
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Label {
        visible: root.shortcut !== "" && !root.separator && !root.hasSubmenu
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        text: root.shortcut
        color: root.highlighted ? Qt.rgba(1, 1, 1, 0.8) : Theme.textTertiary
    }

    Icon {
        visible: root.hasSubmenu
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        size: 10
        name: "chevron-right"
        color: root.highlighted ? "white" : Theme.textSecondary
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        enabled: !root.separator && !root.header
        hoverEnabled: true
        onEntered: root.entered()
        onClicked: if (root.available && !root.hasSubmenu) {
            if (root.checkable) root.checked = !root.checked;
            root.triggered();
        }
    }
}
