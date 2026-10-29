import QtQuick
import Quickshell
import qs.services
import qs.components

// The administrator password prompt (polkit), like macOS's "Foxtail wants to
// make changes. Enter your password to allow this." Shown for
// Panels.authFlow, which shell.qml's PolkitAgent sets.
Item {
    id: root

    property point windowOffset
    property size screenSize

    readonly property var flow: Panels.authFlow

    width: 300
    height: col.implicitHeight + 40

    function submit() {
        if (!flow || !flow.isResponseRequired || pw.text === "") return;
        flow.submit(pw.text);
        pw.text = "";
    }

    // A wrong password: shake, then polkit asks again.
    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onAuthenticationFailed() { shake.restart(); }
    }

    Keys.onEscapePressed: Panels.confirm = ""

    scale: 0.9
    opacity: 0
    Component.onCompleted: { scale = 1; opacity = 1; pw.forceActiveFocus(); }
    Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

    Glass {
        anchors.fill: parent
        radius: Theme.liquid ? 28 : 14
        color: Theme.glassStrong
        windowOffset: root.windowOffset
        screenSize: root.screenSize
        rimOpacity: 0.85
        exposure: 0.9   // the overlay dims the desktop by 10% behind this dialog
        bezel: 18
    }

    Column {
        id: col
        y: 20
        width: parent.width
        spacing: 10

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 64; height: 64
            Image {
                anchors.fill: parent
                sourceSize: Qt.size(128, 128)
                source: Qt.resolvedUrl("../icons/foxtail-logo.png")
            }
            // The padlock badge macOS puts on the app icon.
            Rectangle {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                width: 26; height: 26; radius: 13
                color: Theme.dark ? "#3A3A3C" : "#FFFFFF"
                Icon { anchors.centerIn: parent; name: "lock"; size: 14; color: Theme.text }
            }
        }

        Text {
            width: parent.width - 40
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: I18n.tr("Foxtail wants to make changes.")
            font.family: Theme.font
            font.pixelSize: Theme.px(13)
            font.weight: Font.Bold
            color: Theme.text
        }

        Text {
            width: parent.width - 40
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            // polkit's own message says what for ("Authentication is
            // required to ..."); it is in the system language already.
            text: (root.flow?.message ? root.flow.message + "\n" : "") + I18n.tr("Enter your password to allow this.")
            font.family: Theme.font
            font.pixelSize: Theme.px(11)
            color: Theme.textSecondary
        }

        Item { width: 1; height: 2 }

        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 40
            height: 28
            radius: Theme.liquid ? 14 : 6
            color: Theme.control
            border.width: pw.activeFocus ? 2 : 0
            border.color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.6)

            SequentialAnimation {
                id: shake
                loops: 2
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -10; duration: Theme.ms(50) }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 10; duration: Theme.ms(100) }
                NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 0; duration: Theme.ms(50) }
            }

            Text {
                anchors.fill: parent
                anchors.leftMargin: 10
                verticalAlignment: Text.AlignVCenter
                visible: pw.text === ""
                text: I18n.tr("Password")
                font.family: Theme.font
                font.pixelSize: Theme.px(13)
                color: Theme.textTertiary
            }
            TextInput {
                id: pw
                selectionColor: Theme.accent
                selectedTextColor: "white"
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                passwordCharacter: "•"
                font.family: Theme.font
                font.pixelSize: Theme.px(13)
                color: Theme.text
                clip: true
                onAccepted: root.submit()
                Keys.onEscapePressed: Panels.confirm = ""
            }
        }

        Text {
            width: parent.width - 40
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: text !== ""
            text: root.flow?.failed ? I18n.tr("Incorrect password. Try again.")
                  : (root.flow?.supplementaryMessage ?? "")
            font.family: Theme.font
            font.pixelSize: Theme.px(11)
            color: root.flow?.failed || root.flow?.supplementaryIsError ? "#FF453A" : Theme.textSecondary
        }

        Item { width: 1; height: 4 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            DialogButton { text: I18n.tr("Cancel"); onClicked: Panels.confirm = "" }
            DialogButton { text: I18n.tr("OK"); primary: true; onClicked: root.submit() }
        }
    }

    component DialogButton: Rectangle {
        id: b
        property string text
        property bool primary: false
        signal clicked()
        width: 126
        height: 28
        radius: Theme.liquid ? 14 : 6
        color: primary ? Theme.accent : Theme.control
        Label {
            anchors.centerIn: parent
            text: b.text
            color: b.primary ? "white" : Theme.text
        }
        MouseArea { anchors.fill: parent; onClicked: b.clicked() }
    }
}
