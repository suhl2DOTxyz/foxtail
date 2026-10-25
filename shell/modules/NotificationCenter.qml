import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

// Notification Center: notification history above a calendar widget.
Item {
    id: root

    property point windowOffset
    property size screenSize

    width: 356
    height: col.implicitHeight

    opacity: 0
    x: 30
    Component.onCompleted: { opacity = 1; x = 0; }
    Behavior on opacity { NumberAnimation { duration: Theme.anim } }
    Behavior on x { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

    MouseArea { anchors.fill: parent }

    Column {
        id: col
        width: parent.width
        spacing: 10

        Item {
            width: parent.width
            height: 22
            visible: Notifs.history.length > 0
            Label { x: 4; text: "Notifications"; font.weight: Font.Bold; color: "white"; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.25) }
            Label {
                anchors.right: parent.right
                anchors.rightMargin: 4
                text: "Clear All"
                color: "white"
                style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.25)
                MouseArea { anchors.fill: parent; onClicked: Notifs.clearAll() }
            }
        }

        Repeater {
            model: Notifs.history.slice().reverse().slice(0, 6)
            NotificationCard {
                required property var modelData
                notification: modelData
                width: col.width
                windowOffset: root.windowOffset
                screenSize: root.screenSize
            }
        }

        // ---- Calendar widget ----
        Item {
            width: parent.width
            height: 236

            Glass {
                anchors.fill: parent
                radius: Theme.liquid ? 26 : 20
                windowOffset: root.windowOffset
                screenSize: root.screenSize
        rimOpacity: 0.55
            }

            SystemClock { id: clock; precision: SystemClock.Minutes }

            readonly property date today: clock.date
            readonly property int year: today.getFullYear()
            readonly property int month: today.getMonth()
            readonly property int firstDow: new Date(year, month, 1).getDay()
            readonly property int days: new Date(year, month + 1, 0).getDate()

            Label {
                x: 18; y: 14
                text: Qt.formatDate(parent.today, "MMMM").toUpperCase()
                color: Theme.accent
                font.weight: Font.Bold
                font.pixelSize: 12
            }

            Grid {
                id: grid
                x: 14; y: 40
                columns: 7
                columnSpacing: 0
                rowSpacing: 2
                readonly property real cell: (parent.width - 28) / 7

                Repeater {
                    model: ["S", "M", "T", "W", "T", "F", "S"]
                    Label {
                        required property string modelData
                        width: grid.cell; height: 22
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        color: Theme.textSecondary
                    }
                }

                Repeater {
                    model: 42
                    Item {
                        required property int index
                        readonly property int day: index - grid.parent.firstDow + 1
                        readonly property bool valid: day >= 1 && day <= grid.parent.days
                        readonly property bool isToday: day === grid.parent.today.getDate()
                        width: grid.cell; height: 26
                        Rectangle {
                            anchors.centerIn: parent
                            width: 24; height: 24; radius: 12
                            color: parent.isToday && parent.valid ? Theme.accent : "transparent"
                        }
                        Label {
                            anchors.centerIn: parent
                            visible: parent.valid
                            text: parent.day
                            font.pixelSize: 12
                            font.weight: parent.isToday ? Font.Bold : Font.Normal
                            color: parent.isToday ? "white" : Theme.text
                        }
                    }
                }
            }
        }
    }
}
