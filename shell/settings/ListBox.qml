import QtQuick
import qs.services
import qs.components

// A scrolling single-choice list. model: [[value, label], ...]
Rectangle {
    id: lb
    property var model: []
    property string current
    signal picked(string value)
    radius: 8
    color: "transparent"
    border.color: Theme.separator
    clip: true
    ListView {
        id: lbView
        anchors.fill: parent
        anchors.margins: 4
        model: lb.model
        boundsBehavior: Flickable.StopAtBounds
        function reveal() { positionViewAtIndex(Math.max(0, lb.model.findIndex(m => m[0] === lb.current)), ListView.Contain); }
        Component.onCompleted: reveal()
        Connections { target: lb; function onCurrentChanged() { lbView.reveal(); } }
        delegate: Rectangle {
            required property var modelData
            width: ListView.view.width
            height: 26
            radius: 5
            color: lb.current === modelData[0] ? Theme.accent : "transparent"
            Label {
                x: 10
                width: parent.width - 20
                anchors.verticalCenter: parent.verticalCenter
                text: modelData[1]
                color: lb.current === modelData[0] ? "white" : Theme.text
            }
            MouseArea { anchors.fill: parent; onClicked: lb.picked(parent.modelData[0]) }
        }
    }
}
