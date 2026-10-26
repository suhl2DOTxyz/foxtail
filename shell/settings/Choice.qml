import QtQuick
import Quickshell
import qs.services
import qs.components

// Pop-up button: shows the current option; clicking opens a menu of all of them.
// options: [[value, label], ...]
Rectangle {
    id: ch
    property var options: []
    property var value
    property real menuWidth: 0
    signal picked(var value)
    readonly property int idx: options.findIndex(o => o[0] === value)
    width: Math.max(90, chl.implicitWidth + 36)
    height: 24
    radius: Theme.liquid ? 12 : 6
    opacity: enabled ? 1 : 0.45
    color: Theme.control
    border.color: Theme.separator
    Label {
        id: chl
        x: 12
        width: parent.width - 34
        anchors.verticalCenter: parent.verticalCenter
        text: ch.idx >= 0 ? ch.options[ch.idx][1] : "—"
        font.pixelSize: 12
    }
    Icon { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; size: 10; name: "chevron-down"; color: Theme.textSecondary }
    MouseArea { anchors.fill: parent; enabled: ch.enabled; onClicked: menu.visible = !menu.visible }

    PopupWindow {
        id: menu
        anchor.item: ch
        anchor.rect.y: ch.height + 4
        anchor.rect.x: 0
        grabFocus: true
        color: "transparent"
        implicitWidth: Math.max(ch.width, ch.menuWidth, list.longest + 44)
        implicitHeight: Math.min(list.contentHeight + 12, 320)

        Rectangle {
            anchors.fill: parent
            radius: Theme.liquid ? 14 : 8
            color: Theme.dark ? "#2C2C2E" : "#FFFFFF"
            border.color: Theme.glassOutline
            ListView {
                id: list
                property real longest: 0
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                model: ch.options
                boundsBehavior: Flickable.StopAtBounds
                Component.onCompleted: positionViewAtIndex(Math.max(0, ch.idx), ListView.Center)
                delegate: Rectangle {
                    id: opt
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: 26
                    radius: Theme.liquid ? 8 : 5
                    color: om.containsMouse ? Theme.accent : "transparent"
                    Icon {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: opt.index === ch.idx
                        size: 11; name: "check"
                        color: om.containsMouse ? "white" : Theme.text
                    }
                    Label {
                        id: ol
                        x: 24
                        anchors.verticalCenter: parent.verticalCenter
                        text: opt.modelData[1]
                        font.pixelSize: 12
                        color: om.containsMouse ? "white" : Theme.text
                        Component.onCompleted: list.longest = Math.max(list.longest, implicitWidth)
                    }
                    MouseArea {
                        id: om
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: { menu.visible = false; ch.picked(opt.modelData[0]); }
                    }
                }
            }
        }
    }
}
