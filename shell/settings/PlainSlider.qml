import QtQuick
import qs.services

Item {
    id: ps
    property real value: 0.5
    property real from: 0
    property real to: 1
    signal moved(real value)
    signal released()
    width: 200
    height: 20
    opacity: enabled ? 1 : 0.4
    readonly property real t: Math.max(0, Math.min(1, (value - from) / (to - from)))
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width; height: 4; radius: 2
        color: Theme.controlOff
        Rectangle { width: parent.width * ps.t; height: parent.height; radius: 2; color: Theme.accent }
    }
    Rectangle {
        x: ps.t * (parent.width - width)
        anchors.verticalCenter: parent.verticalCenter
        width: 20; height: 20; radius: 10
        color: "white"
        border.color: Qt.rgba(0, 0, 0, 0.15)
    }
    MouseArea {
        anchors.fill: parent
        function upd(mx) {
            const v = ps.from + Math.max(0, Math.min(1, mx / width)) * (ps.to - ps.from);
            ps.value = v;
            ps.moved(v);
        }
        onPressed: m => upd(m.x)
        onPositionChanged: m => { if (pressed) upd(m.x); }
        onReleased: ps.released()
    }
}
