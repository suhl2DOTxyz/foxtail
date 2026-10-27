import QtQuick
import qs.services
import qs.components

// A row in a Group: label (and optional subtitle) on the left, a control on the right.
Item {
    id: sr
    property string label
    property string sub: ""
    property bool last: false
    property string icon: ""
    property color iconColor: Theme.accent
    default property alias control: ctl.data
    width: parent?.width ?? 0
    // Grows with its text (long subtitles, larger text sizes).
    height: Math.max(sub ? 52 : 40, textCol.implicitHeight + 18, ctl.height + 16)

    Rectangle {
        id: badge
        visible: sr.icon !== ""
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        width: visible ? 28 : 0; height: 28; radius: 14
        color: Theme.control
        Icon { anchors.centerIn: parent; size: 16; name: sr.icon; color: sr.iconColor }
    }
    Column {
        id: textCol
        x: sr.icon ? 52 : 14
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - ctl.width - x - 26
        Label { width: parent.width; text: sr.label }
        Label { visible: sr.sub !== ""; width: parent.width; text: sr.sub; font.pixelSize: Theme.px(11); color: Theme.textSecondary; wrapMode: Text.Wrap; elide: Text.ElideNone }
    }
    Item {
        id: ctl
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
    Rectangle {
        visible: !sr.last
        anchors.bottom: parent.bottom
        x: 14
        width: parent.width - 28
        height: 1
        color: Theme.separator
    }
}
