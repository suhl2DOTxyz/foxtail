import QtQuick
import Quickshell
import qs.services
import qs.components

// "Are you sure you want to shut down your computer now?" with the macOS
// 60-second auto-confirm countdown.
Item {
    id: root

    property point windowOffset
    property size screenSize

    width: 300
    height: col.implicitHeight + 40

    readonly property var kinds: ({
        restart: { title: I18n.tr("Are you sure you want to restart your computer now?"), button: I18n.tr("Restart"), countdown: "If you do nothing, the computer will restart automatically in %1 seconds.", cmd: ["systemctl", "reboot"] },
        shutdown: { title: I18n.tr("Are you sure you want to shut down your computer now?"), button: I18n.tr("Shut Down"), countdown: "If you do nothing, the computer will shut down automatically in %1 seconds.", cmd: ["systemctl", "poweroff"] },
        logout: { title: I18n.tr("Are you sure you want to quit all applications and log out now?"), button: I18n.tr("Log Out"), countdown: "If you do nothing, you will be logged out automatically in %1 seconds.", cmd: ["hyprctl", "dispatch", "hl.dsp.exit()"] },
        emptyTrash: { title: I18n.tr("Are you sure you want to permanently erase the items in the Trash?"), button: I18n.tr("Empty Trash"),
                      note: I18n.tr("You can't undo this action."), noTimer: true, icon: "user-trash-full", cmd: ["gio", "trash", "--empty"] }
    })
    readonly property var kind: kinds[Panels.confirm] ?? kinds.shutdown
    property int seconds: 60

    function go() {
        const cmd = kind.cmd;
        if (Panels.confirm === "emptyTrash") Sounds.play("trash");
        Panels.confirm = "";
        Quickshell.execDetached(cmd);
    }

    Timer {
        interval: 1000
        repeat: true
        running: !root.kind.noTimer
        onTriggered: if (--root.seconds <= 0) root.go()
    }

    scale: 0.9
    opacity: 0
    Component.onCompleted: { scale = 1; opacity = 1; }
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

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 64; height: 64
            sourceSize: Qt.size(128, 128)
            source: root.kind.icon ? Quickshell.iconPath(root.kind.icon, "user-trash") : Qt.resolvedUrl("../icons/foxtail-logo.png")
        }

        Text {
            width: parent.width - 40
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: root.kind.title
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
            text: root.kind.note ?? I18n.tr(root.kind.countdown).arg(root.seconds)
            font.family: Theme.font
            font.pixelSize: Theme.px(11)
            color: Theme.textSecondary
        }

        Item { width: 1; height: 4 }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            DialogButton { text: I18n.tr("Cancel"); onClicked: Panels.confirm = "" }
            DialogButton { text: root.kind.button; primary: true; onClicked: root.go() }
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
