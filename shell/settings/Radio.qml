import QtQuick
import qs.services

// A round selection mark: filled with the accent color when checked.
Rectangle {
    id: r
    property bool checked: false
    signal clicked()
    width: 20; height: 20; radius: 10
    color: checked ? Theme.accent : "transparent"
    border.width: checked ? 0 : 1.5
    border.color: Theme.textTertiary
    Rectangle { anchors.centerIn: parent; width: 8; height: 8; radius: 4; color: "white"; visible: r.checked }
    MouseArea { anchors.fill: parent; anchors.margins: -6; onClicked: r.clicked() }
}
