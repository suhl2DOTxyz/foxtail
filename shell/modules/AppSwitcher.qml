import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// The ⌘Tab app switcher: a row of app icons on glass, centered on the
// focused display.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property bool focusedScreen: Hyprland.focusedMonitor?.name === modelData.name
    visible: Switcher.shown && focusedScreen

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "foxtail-popover"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region { item: panel }

    readonly property real cell: Math.min(112, (width - 80) / Math.max(1, Switcher.apps.length))
    readonly property real icon: cell * 0.78

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Switcher.close()
        Keys.onLeftPressed: Switcher.step(-1)
        Keys.onRightPressed: Switcher.step(1)
        Keys.onReturnPressed: Switcher.commit()
        // While the switcher has the keyboard, letting go of ⌘ arrives here
        // rather than at Hyprland's release bind.
        Keys.onReleased: event => {
            if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta
                    || !(event.modifiers & Qt.MetaModifier))
                Switcher.commit();
        }
    }

    Item {
        id: panel
        anchors.centerIn: parent
        width: row.width + 28
        height: root.cell + 46

        Glass {
            anchors.fill: parent
            radius: Theme.liquid ? 30 : 18
            color: Theme.glassStrong
            screenSize: Qt.size(root.width, root.height)
            windowOffset: Qt.point(panel.x, panel.y)
            rimOpacity: 0.7
            bezel: 18
        }

        Row {
            id: row
            x: 14
            y: 12
            Repeater {
                model: Switcher.apps
                Item {
                    id: tile
                    required property string modelData
                    required property int index
                    readonly property bool selected: index === Switcher.index
                    width: root.cell
                    height: root.cell

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.liquid ? 22 : 14
                        color: Theme.dark ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(0, 0, 0, 0.12)
                        visible: tile.selected
                    }
                    Image {
                        anchors.centerIn: parent
                        width: root.icon
                        height: root.icon
                        sourceSize: Qt.size(root.icon * 2, root.icon * 2)
                        source: Apps.iconFor(tile.modelData)
                        smooth: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: Switcher.index = tile.index
                        onClicked: { Switcher.index = tile.index; Switcher.commit(); }
                    }
                }
            }
        }

        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            text: Apps.nameFor(Switcher.apps[Switcher.index] ?? "")
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }
}
