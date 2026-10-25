import QtQuick
import qs.services

// macOS-style toggle switch.
Item {
    id: root

    property bool checked: false
    property bool small: false
    signal toggled(bool checked)

    implicitWidth: small ? 32 : 40
    implicitHeight: small ? 18 : 22

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.checked ? Theme.accent : Theme.controlOff
        Behavior on color { ColorAnimation { duration: Theme.animFast } }

        Rectangle {
            id: knob
            width: parent.height - 4
            height: width
            radius: width / 2
            y: 2
            x: root.checked ? parent.width - width - 2 : 2
            color: "white"
            Behavior on x { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -0.5
                radius: width / 2
                color: "transparent"
                border.color: Qt.rgba(0, 0, 0, 0.12)
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.checked = !root.checked;
            root.toggled(root.checked);
        }
    }
}
