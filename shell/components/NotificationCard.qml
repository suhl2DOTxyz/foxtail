import QtQuick
import Quickshell
import qs.services

// A single notification, as shown in banners and Notification Center.
Item {
    id: root

    property var notification
    property point windowOffset
    property size screenSize
    signal closed()

    implicitHeight: Math.max(64, body.y + body.implicitHeight + 12)

    HoverHandler { id: hover }

    Glass {
        anchors.fill: parent
        radius: Theme.liquid ? 24 : 16
        windowOffset: root.windowOffset
        screenSize: root.screenSize
        rimOpacity: 0.55
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
    }

    Label {
        id: time
        anchors.right: parent.right
        anchors.rightMargin: 14
        y: 13
        text: "now"
        font.pixelSize: 11
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
        font.pixelSize: 12
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

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            const a = root.notification?.actions?.find(a => a.identifier === "default");
            if (a) a.invoke();
            root.closed();
        }
    }
}
