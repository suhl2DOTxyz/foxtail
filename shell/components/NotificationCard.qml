import QtQuick
import Quickshell
import qs.services

// A single notification, as shown in banners and Notification Center: app
// icon, title, time and body; the app's action buttons on hover; and a Reply
// field for apps that support inline replies (messaging apps), as on macOS.
Item {
    id: root

    property var notification
    property point windowOffset
    property size screenSize
    // In a collapsed Notification Center stack, only the top card is live.
    property bool interactive: true
    signal closed()

    readonly property var buttons: (notification?.actions ?? []).filter(a => a.identifier !== "default" && a.text)
    readonly property bool canReply: notification?.hasInlineReply ?? false
    property bool replying: false
    onReplyingChanged: Notifs.replying = replying
    readonly property bool busy: hover.hovered || replying
    readonly property bool showActions: interactive && (hover.hovered || replying) && (buttons.length > 0 || canReply)

    implicitHeight: Math.max(64, body.y + body.implicitHeight + 12) + (showActions ? actionRow.height + 10 : 0)
    Behavior on implicitHeight { NumberAnimation { duration: Theme.animFast; easing.type: Easing.OutCubic } }

    HoverHandler { id: hover; enabled: root.interactive }

    Glass {
        anchors.fill: parent
        radius: Theme.liquid ? 24 : 16
        windowOffset: root.windowOffset
        screenSize: root.screenSize
        rimOpacity: 0.85
        bezel: 16
    }

    Image {
        id: icon
        x: 12
        y: 12
        width: 34; height: 34
        sourceSize: Qt.size(68, 68)
        source: {
            const n = root.notification;
            if (!n) return "";
            if (n.image) return n.image;
            if (n.appIcon) return n.appIcon.startsWith("/") ? "file://" + n.appIcon : Quickshell.iconPath(n.appIcon, true);
            const e = Apps.entry(n.desktopEntry || n.appName);
            return Quickshell.iconPath(e?.icon ?? "dialog-information", "dialog-information");
        }
    }

    Label {
        id: title
        anchors.left: icon.right
        anchors.leftMargin: 10
        anchors.right: time.left
        anchors.rightMargin: 6
        y: 12
        text: root.notification?.summary ?? ""
        font.weight: Font.DemiBold
        elide: Text.ElideRight
    }

    Label {
        id: time
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 13
        text: Notifs.ago(root.notification)
        font.pixelSize: Theme.px(11)
        color: Theme.textSecondary
    }

    Text {
        id: body
        anchors.left: title.left
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: title.y + title.height + 1
        text: root.notification?.body ?? ""
        textFormat: Text.StyledText
        wrapMode: Text.Wrap
        maximumLineCount: 4
        elide: Text.ElideRight
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: Theme.px(12)
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        enabled: root.interactive
        onClicked: {
            const a = root.notification?.actions?.find(a => a.identifier === "default");
            if (a) a.invoke();
            root.closed();
        }
    }

    // ---- actions and reply ----
    Item {
        id: actionRow
        visible: root.showActions
        anchors.left: title.left
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: body.y + body.implicitHeight + 10
        height: 28

        Row {
            visible: !root.replying
            spacing: 6
            Repeater {
                model: root.buttons.slice(0, 3)
                Pill {
                    required property var modelData
                    text: modelData.text
                    onClicked: { modelData.invoke(); root.closed(); }
                }
            }
            Pill {
                visible: root.canReply
                text: I18n.tr("Reply")
                onClicked: { root.replying = true; reply.forceActiveFocus(); }
            }
        }

        Rectangle {
            visible: root.replying
            anchors.fill: parent
            radius: height / 2
            color: Theme.control
            border.color: reply.activeFocus ? Theme.accent : Theme.separator
            TextInput {
                id: reply
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.right: send.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                font.family: Theme.font
                font.pixelSize: Theme.px(12)
                color: Theme.text
                clip: true
                Label {
                    visible: !reply.text
                    text: root.notification?.inlineReplyPlaceholder || "Reply"
                    font.pixelSize: Theme.px(12)
                    color: Theme.textTertiary
                    anchors.verticalCenter: parent.verticalCenter
                }
                Keys.onReturnPressed: root.sendReply()
                Keys.onEnterPressed: root.sendReply()
                Keys.onEscapePressed: root.replying = false
            }
            Rectangle {
                id: send
                anchors.right: parent.right
                anchors.rightMargin: 3
                anchors.verticalCenter: parent.verticalCenter
                width: 22; height: 22; radius: 11
                color: reply.text ? Theme.accent : Theme.controlOff
                Icon { anchors.centerIn: parent; size: 11; name: "arrow-right-circle"; color: "white" }
                MouseArea { anchors.fill: parent; onClicked: root.sendReply() }
            }
        }
    }

    function sendReply() {
        if (!reply.text.trim()) return;
        notification?.sendInlineReply(reply.text);
        replying = false;
        closed();
    }

    // Close button (top-left, on hover), like macOS.
    Rectangle {
        visible: hover.hovered
        x: -6; y: -6
        width: 20; height: 20; radius: 10
        color: Theme.glassStrong
        border.color: Theme.separator
        Icon { anchors.centerIn: parent; size: 9; name: "xmark"; color: Theme.textSecondary }
        MouseArea {
            anchors.fill: parent
            onClicked: { root.notification?.dismiss(); root.closed(); }
        }
    }

    component Pill: Rectangle {
        id: pill
        property string text
        signal clicked()
        width: pillLabel.implicitWidth + 22
        height: 26
        radius: 13
        color: pillMouse.pressed ? Theme.pressed : Theme.control
        Label { id: pillLabel; anchors.centerIn: parent; text: pill.text; font.pixelSize: Theme.px(12); font.weight: Font.Medium }
        MouseArea { id: pillMouse; anchors.fill: parent; onClicked: pill.clicked() }
    }
}
