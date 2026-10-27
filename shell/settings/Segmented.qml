import QtQuick
import qs.services
import qs.components

// macOS segmented control: a short row of mutually exclusive choices.
//   options: [{ text, value }]
Rectangle {
    id: root

    property var options: []
    property var value
    signal picked(var value)

    implicitWidth: row.implicitWidth + 4
    implicitHeight: 24
    radius: 7
    color: Theme.control

    Row {
        id: row
        x: 2
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: root.options
            Rectangle {
                id: seg
                required property var modelData
                readonly property bool selected: root.value === modelData.value
                width: Math.max(64, segLabel.implicitWidth + 24)
                height: 20
                radius: 5
                color: selected ? (Theme.dark ? "#636366" : "white") : "transparent"
                border.width: selected && !Theme.dark ? 0.5 : 0
                border.color: Qt.rgba(0, 0, 0, 0.12)
                Behavior on color { ColorAnimation { duration: Theme.animFast } }
                Label {
                    id: segLabel
                    anchors.centerIn: parent
                    text: seg.modelData.text
                    font.pixelSize: Theme.px(12)
                    font.weight: seg.selected ? Font.Medium : Font.Normal
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: root.enabled
                    onClicked: root.picked(seg.modelData.value)
                }
            }
        }
    }
}
