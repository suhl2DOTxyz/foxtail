import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.services
import qs.components

// macOS-style lock screen: large clock over the blurred wallpaper, avatar and
// password field at the bottom. Uses ext-session-lock, so it is a real lock.
Scope {
    id: lock

    property string status: ""
    property bool busy: false

    PamContext {
        id: pam
        onResponseRequiredChanged: if (responseRequired && lock.pending !== "") {
            respond(lock.pending);
            lock.pending = "";
        }
        onCompleted: result => {
            lock.busy = false;
            if (result === PamResult.Success) {
                lock.status = "";
                Lock.locked = false;
            } else {
                lock.status = "Incorrect password";
                lock.shake();
            }
        }
    }

    property string pending: ""
    signal shake()

    function submit(pw) {
        if (busy || pw === "") return;
        busy = true;
        status = "";
        pending = pw;
        pam.start();
    }

    WlSessionLock {
        locked: Lock.locked

        WlSessionLockSurface {
            id: surface
            color: "black"

            Image {
                id: wall
                anchors.fill: parent
                source: "file://" + Settings.wallpaper
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(surface.width, surface.height)
                visible: false
            }
            MultiEffect {
                anchors.fill: parent
                source: wall
                blurEnabled: true
                blur: 1.0
                blurMax: 64
                saturation: 0.1
                brightness: -0.06
            }

            SystemClock { id: clock; precision: SystemClock.Seconds }

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.09
                spacing: 0
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: I18n.date(clock.date, I18n.english ? "dddd, MMMM d" : "dddd, d. MMMM")
                    color: Qt.rgba(1, 1, 1, 0.9)
                    font.pixelSize: Theme.px(24)
                    font.weight: Font.DemiBold
                }
                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatTime(clock.date, Settings.clock24h ? "HH:mm" : "h:mm")
                    color: Qt.rgba(1, 1, 1, 0.92)
                    font.family: Theme.fontDisplay
                    font.pixelSize: Theme.px(112)
                    font.weight: Font.Bold
                }
            }

            Column {
                id: login
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: parent.height * 0.1
                spacing: 12

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64; height: 64; radius: 32
                    color: Qt.rgba(1, 1, 1, 0.25)
                    clip: true
                    Image {
                        id: face
                        anchors.fill: parent
                        source: "file://" + Quickshell.env("HOME") + "/.face"
                        fillMode: Image.PreserveAspectCrop
                    }
                    Icon {
                        visible: face.status !== Image.Ready
                        anchors.centerIn: parent
                        size: 36
                        name: "person"
                        color: "white"
                    }
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: SystemInfo.fullName || SystemInfo.user
                    color: "white"
                    font.pixelSize: Theme.px(15)
                    font.weight: Font.DemiBold
                }

                Rectangle {
                    id: field
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 200
                    height: 30
                    radius: 15
                    color: Qt.rgba(1, 1, 1, 0.22)
                    border.color: Qt.rgba(1, 1, 1, 0.3)

                    SequentialAnimation {
                        id: shakeAnim
                        loops: 2
                        NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: -10; duration: Theme.ms(50) }
                        NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 10; duration: Theme.ms(100) }
                        NumberAnimation { target: field; property: "anchors.horizontalCenterOffset"; to: 0; duration: Theme.ms(50) }
                    }
                    Connections { target: lock; function onShake() { shakeAnim.restart(); pw.text = ""; } }

                    TextInput {
                        selectionColor: Theme.accent
                        selectedTextColor: "white"
                        id: pw
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 32
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "●"
                        color: "white"
                        font.family: Theme.font
                        font.pixelSize: Theme.px(13)
                        focus: true
                        enabled: !lock.busy
                        onAccepted: lock.submit(text)
                        Label {
                            visible: !pw.text
                            text: I18n.tr("Enter Password")
                            color: Qt.rgba(1, 1, 1, 0.6)
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Icon {
                        anchors.right: parent.right
                        anchors.rightMargin: 7
                        anchors.verticalCenter: parent.verticalCenter
                        visible: pw.text.length > 0
                        size: 18
                        name: "arrow-right-circle"
                        color: "white"
                        MouseArea { anchors.fill: parent; onClicked: lock.submit(pw.text) }
                    }
                }

                Label {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: lock.status || "Enter your password to unlock"
                    color: lock.status ? "#FFB4A8" : Qt.rgba(1, 1, 1, 0.55)
                    font.pixelSize: Theme.px(11)
                }
            }
        }
    }
}
