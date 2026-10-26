import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.services
import qs.components

// Notification Center: notification history above widgets - a calendar, an
// analog clock, and batteries (or today's date on desktops), as on macOS.
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
                rimOpacity: 0.85
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
    
        // ---- small widgets ----
        Row {
            spacing: 10
            readonly property real side: (col.width - 10) / 2

            // World Clock: the local time on an analog face.
            Item {
                width: parent.side
                height: parent.side
                Glass {
                    anchors.fill: parent
                    radius: Theme.liquid ? 26 : 20
                    windowOffset: root.windowOffset
                    screenSize: root.screenSize
                    rimOpacity: 0.85
                }
                SystemClock { id: tick; precision: SystemClock.Seconds }
                Item {
                    id: face
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -8
                    width: parent.width - 44
                    height: width
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.dark ? "#1C1C1E" : "white"
                        border.width: 1
                        border.color: Theme.separator
                    }
                    Repeater {
                        model: 12
                        Rectangle {
                            required property int index
                            x: face.width / 2 - width / 2
                            y: 4
                            width: index % 3 === 0 ? 2 : 1
                            height: index % 3 === 0 ? 7 : 4
                            color: Theme.textSecondary
                            transform: Rotation { origin.x: width / 2; origin.y: face.height / 2 - 4; angle: index * 30 }
                        }
                    }
                    Rectangle {   // hour
                        x: face.width / 2 - 1.75; y: face.height / 2 - face.height * 0.26
                        width: 3.5; height: face.height * 0.26 + 4; radius: 2
                        color: Theme.text
                        antialiasing: true
                        transform: Rotation { origin.x: 1.75; origin.y: face.height * 0.26; angle: (tick.date.getHours() % 12 + tick.date.getMinutes() / 60) * 30 }
                    }
                    Rectangle {   // minute
                        x: face.width / 2 - 1.25; y: face.height / 2 - face.height * 0.38
                        width: 2.5; height: face.height * 0.38 + 4; radius: 1.5
                        color: Theme.text
                        antialiasing: true
                        transform: Rotation { origin.x: 1.25; origin.y: face.height * 0.38; angle: (tick.date.getMinutes() + tick.date.getSeconds() / 60) * 6 }
                    }
                    Rectangle {   // second
                        x: face.width / 2 - 0.6; y: face.height / 2 - face.height * 0.42
                        width: 1.2; height: face.height * 0.42 + 8
                        color: Theme.accent
                        antialiasing: true
                        transform: Rotation { origin.x: 0.6; origin.y: face.height * 0.42; angle: tick.date.getSeconds() * 6 }
                    }
                    Rectangle { anchors.centerIn: parent; width: 6; height: 6; radius: 3; color: Theme.accent }
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    text: (Quickshell.env("TZ") || SystemInfo.timezone || "Local").split("/").pop().replace(/_/g, " ")
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    color: Theme.textSecondary
                }
            }

            // Batteries (laptops) or today's date.
            Item {
                width: parent.side
                height: parent.side
                Glass {
                    anchors.fill: parent
                    radius: Theme.liquid ? 26 : 20
                    windowOffset: root.windowOffset
                    screenSize: root.screenSize
                    rimOpacity: 0.85
                }
                Column {
                    visible: Power.hasBattery
                    anchors.centerIn: parent
                    spacing: 8
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 74; height: 74
                        Canvas {
                            id: ring
                            anchors.fill: parent
                            readonly property real level: Power.percent / 100
                            onLevelChanged: requestPaint()
                            onPaint: {
                                const c = getContext("2d");
                                c.reset();
                                c.lineWidth = 7;
                                c.lineCap = "round";
                                c.strokeStyle = Theme.dark ? "rgba(255,255,255,0.15)" : "rgba(0,0,0,0.08)";
                                c.beginPath(); c.arc(37, 37, 32, 0, Math.PI * 2); c.stroke();
                                c.strokeStyle = Power.percent < 20 ? "#FF3B30" : "#30D158";
                                c.beginPath(); c.arc(37, 37, 32, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * level); c.stroke();
                            }
                        }
                        Icon { anchors.centerIn: parent; size: 26; name: Power.charging ? "bolt" : "battery"; color: Theme.text }
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Power.percent + "%"
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                    }
                }
                Column {
                    visible: !Power.hasBattery
                    anchors.centerIn: parent
                    spacing: 0
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDate(tick.date, "dddd").toUpperCase()
                        color: Theme.accent
                        font.pixelSize: 12
                        font.weight: Font.Bold
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tick.date.getDate()
                        font.pixelSize: 54
                        font.weight: Font.Light
                    }
                    Label {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Qt.formatDate(tick.date, "MMMM yyyy")
                        color: Theme.textSecondary
                        font.pixelSize: 11
                    }
                }
            }
        }
}
}
