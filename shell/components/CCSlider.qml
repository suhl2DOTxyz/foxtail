import QtQuick
import qs.services

// Control Center slider: a fat pill whose fill grows with the value and whose
// glyph sits inside the track, like macOS's Display and Sound modules.
Item {
    id: root

    property real value: 0.5
    property string icon: "sun-small"
    signal moved(real value)

    implicitHeight: 26
    implicitWidth: 200

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(0, 0, 0, 0.08)
        clip: true

        Rectangle {
            id: fill
            height: parent.height
            width: Math.max(height, parent.width * root.value)
            radius: height / 2
            color: "white"
            Behavior on width { enabled: !drag.pressed; NumberAnimation { duration: Theme.animFast } }

            // Knob shading at the leading edge, as on macOS.
            Rectangle {
                anchors.right: parent.right
                width: parent.height
                height: parent.height
                radius: height / 2
                color: "white"
                border.color: Qt.rgba(0, 0, 0, 0.10)
            }
        }

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            x: 7
            size: 13
            name: root.icon
            color: Qt.rgba(0, 0, 0, 0.55)
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function update(mx) {
            const v = Math.max(0, Math.min(1, mx / width));
            root.value = v;
            root.moved(v);
        }
        onPressed: m => update(m.x)
        onPositionChanged: m => { if (pressed) update(m.x); }
        onWheel: w => {
            const v = Math.max(0, Math.min(1, root.value + (w.angleDelta.y > 0 ? 0.05 : -0.05)));
            root.value = v;
            root.moved(v);
        }
    }
}
