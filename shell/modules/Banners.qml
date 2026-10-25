import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// Notification banners, sliding in from the top-right corner.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    visible: Notifs.banners.length > 0 && modelData === Quickshell.screens[0]

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "foxtail-banner"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins { top: Theme.menuBarHeight + 6; right: 10 }
    implicitWidth: 370
    implicitHeight: col.implicitHeight + 20
    color: "transparent"

    Column {
        id: col
        x: 6
        y: 6
        width: 356
        spacing: 8

        Repeater {
            model: Notifs.banners

            NotificationCard {
                id: card
                required property var modelData
                notification: modelData
                width: col.width
                windowOffset: Qt.point(root.screen.width - root.width - 10, Theme.menuBarHeight + 6)
                screenSize: Qt.size(root.screen.width, root.screen.height)
                onClosed: Notifs.dismissBanner(modelData)

                x: 380
                Component.onCompleted: x = 0
                Behavior on x { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }

                Timer {
                    running: true
                    interval: card.modelData.urgency === 2 ? 15000 : 5500
                    onTriggered: Notifs.dismissBanner(card.modelData)
                }
            }
        }
    }
}
