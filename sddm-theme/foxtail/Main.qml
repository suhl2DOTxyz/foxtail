import QtQuick
import QtQuick.Effects

// Foxtail login window, styled like the macOS login screen: big clock over
// a blurred wallpaper, avatar + name + password pill, power buttons below.
Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "black"

    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property int sessionIndex: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property string userName: users.currentItem ? users.currentItem.uname : ""
    property string status: ""
    readonly property string font: config.font || "Inter"

    Connections {
        target: sddm
        function onLoginFailed() {
            root.status = "Incorrect password";
            password.text = "";
            shake.restart();
        }
        function onLoginSucceeded() { root.status = ""; }
    }

    Image {
        id: wall
        anchors.fill: parent
        source: config.background
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        brightness: -0.05
    }

    // ---- clock ----
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.09
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDate(clock.now, "dddd, MMMM d")
            color: Qt.rgba(1, 1, 1, 0.9)
            font.family: root.font
            font.pixelSize: 24
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatTime(clock.now, "h:mm")
            color: Qt.rgba(1, 1, 1, 0.92)
            font.family: root.font
            font.pixelSize: 112
            font.weight: Font.Bold
        }
    }
    Timer {
        id: clock
        property date now: new Date()
        interval: 1000; running: true; repeat: true
        onTriggered: now = new Date()
    }

    // ---- users ----
    ListView {
        id: users
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: login.top
        anchors.bottomMargin: 14
        width: Math.min(count, 5) * 110
        height: 120
        orientation: ListView.Horizontal
        model: userModel
        currentIndex: root.userIndex
        interactive: false

        delegate: Item {
            id: u
            required property int index
            required property string name
            required property string realName
            required property string icon
            readonly property string uname: name
            width: 110
            height: 120
            opacity: ListView.isCurrentItem ? 1 : 0.55

            Rectangle {
                id: avatarBg
                anchors.horizontalCenter: parent.horizontalCenter
                width: u.ListView.isCurrentItem ? 76 : 60
                height: width
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.22)
                clip: true
                Behavior on width { NumberAnimation { duration: 180 } }
                Image {
                    id: face
                    anchors.fill: parent
                    source: u.icon
                    fillMode: Image.PreserveAspectCrop
                }
                Text {
                    visible: face.status !== Image.Ready
                    anchors.centerIn: parent
                    text: (u.realName || u.name).charAt(0).toUpperCase()
                    color: "white"
                    font.family: root.font
                    font.pixelSize: parent.width * 0.42
                    font.weight: Font.DemiBold
                }
            }
            Text {
                anchors.top: avatarBg.bottom
                anchors.topMargin: 8
                anchors.horizontalCenter: parent.horizontalCenter
                text: u.realName || u.name
                color: "white"
                font.family: root.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            MouseArea {
                anchors.fill: parent
                onClicked: { users.currentIndex = u.index; password.forceActiveFocus(); }
            }
        }
    }

    Column {
        id: login
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: parent.height * 0.16
        spacing: 10

        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: 210
            height: 32
            radius: 16
            color: Qt.rgba(1, 1, 1, 0.22)
            border.color: Qt.rgba(1, 1, 1, 0.3)

            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -10; duration: 50 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 10; duration: 100 }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50 }
            }

            TextInput {
                id: password
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 34
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "●"
                color: "white"
                font.family: root.font
                font.pixelSize: 13
                focus: true
                onAccepted: sddm.login(root.userName, text, root.sessionIndex)
                Text {
                    visible: !password.text
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Enter Password"
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.family: root.font
                    font.pixelSize: 13
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 5
                anchors.verticalCenter: parent.verticalCenter
                visible: password.text.length > 0
                width: 22; height: 22; radius: 11
                color: Qt.rgba(1, 1, 1, 0.85)
                Text {
                    anchors.centerIn: parent
                    text: "→"
                    color: "#333"
                    font.pixelSize: 14
                    font.weight: Font.Bold
                }
                MouseArea { anchors.fill: parent; onClicked: sddm.login(root.userName, password.text, root.sessionIndex) }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.status || ("Session: " + (sessionList.currentText || "Foxtail") + "  ▾")
            color: root.status ? "#FFB4A8" : Qt.rgba(1, 1, 1, 0.6)
            font.family: root.font
            font.pixelSize: 11
            MouseArea {
                anchors.fill: parent
                onClicked: root.sessionIndex = (root.sessionIndex + 1) % sessionModel.rowCount()
            }
        }
    }

    // Hidden helper to read the current session's name.
    ListView {
        id: sessionList
        visible: false
        model: sessionModel
        currentIndex: root.sessionIndex
        property string currentText: currentItem ? currentItem.sname : ""
        delegate: Item {
            required property string name
            property string sname: name
        }
    }

    // ---- power buttons ----
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 36
        spacing: 48

        Repeater {
            model: [
                { label: "Sleep", glyph: "☾", act: function() { sddm.suspend(); }, ok: sddm.canSuspend },
                { label: "Restart", glyph: "↻", act: function() { sddm.reboot(); }, ok: sddm.canReboot },
                { label: "Shut Down", glyph: "⏻", act: function() { sddm.powerOff(); }, ok: sddm.canPowerOff }
            ]
            Column {
                required property var modelData
                visible: modelData.ok
                spacing: 6
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 40; height: 40; radius: 20
                    color: pm.containsMouse ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.2)
                    Text {
                        anchors.centerIn: parent
                        text: modelData.glyph
                        color: "white"
                        font.pixelSize: 18
                    }
                    MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; onClicked: modelData.act() }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: modelData.label
                    color: Qt.rgba(1, 1, 1, 0.8)
                    font.family: root.font
                    font.pixelSize: 11
                }
            }
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}
