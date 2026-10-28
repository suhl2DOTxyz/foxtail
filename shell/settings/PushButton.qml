import QtQuick
import qs.services
import qs.components

Rectangle {
    id: pb
    property string text
    property bool primary: false
    property bool destructive: false
    signal clicked()
    width: pbl.implicitWidth + 24
    height: 24
    radius: Theme.liquid ? 12 : 6
    opacity: enabled ? 1 : 0.45
    color: primary ? (pbm.pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent)
                   : (pbm.pressed ? Theme.pressed : Theme.control)
    border.color: primary ? "transparent" : Theme.separator
    Label {
        id: pbl
        anchors.centerIn: parent
        text: pb.text
        font.pixelSize: Theme.px(12)
        color: pb.primary ? "white" : pb.destructive ? "#FF453A" : Theme.text
    }
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: if (enabled) pb.clicked()
    // A click on a window that isn't active yet gets cancelled when the window
    // is activated mid-click; macOS buttons work on that first click, so
    // count it (see also components/TrafficLights.qml).
    MouseArea {
        id: pbm
        property bool armed: false
        anchors.fill: parent
        enabled: pb.enabled
        onPressed: armed = true
        onClicked: { armed = false; pb.clicked(); }
        onCanceled: { if (armed) pb.clicked(); armed = false; }
        onReleased: if (!containsMouse) armed = false
    }
}
