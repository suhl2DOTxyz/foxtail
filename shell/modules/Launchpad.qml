import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.components

// Launchpad: a full-screen, blurred grid of every app, paged horizontally,
// with type-to-filter search at the top.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData
    visible: Panels.launchpad && modelData === (Panels.screen ?? Quickshell.screens[0])

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "foxtail-launchpad"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    readonly property var apps: search.text ? Apps.search(search.text) : Apps.all
    readonly property int cols: 7
    readonly property int rows: 5
    readonly property int perPage: cols * rows
    readonly property int pages: Math.max(1, Math.ceil(apps.length / perPage))

    onVisibleChanged: if (visible) { search.text = ""; pager.currentIndex = 0; search.forceActiveFocus(); }

    Rectangle {
        anchors.fill: parent
        color: Theme.dark ? Qt.rgba(0, 0, 0, 0.45) : Qt.rgba(0, 0, 0, 0.32)
        opacity: root.visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: Panels.launchpad = false
    }

    Item {
        id: content
        anchors.fill: parent
        scale: root.visible ? 1 : 1.08
        opacity: root.visible ? 1 : 0
        Behavior on scale { NumberAnimation { duration: Theme.animSlow; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }

        // Search field
        Rectangle {
            id: field
            anchors.horizontalCenter: parent.horizontalCenter
            y: 56
            width: 260
            height: 30
            radius: 15
            color: Qt.rgba(1, 1, 1, 0.18)
            border.color: Qt.rgba(1, 1, 1, 0.28)

            Icon {
                id: mag
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                size: 13
                name: "search"
                color: Qt.rgba(1, 1, 1, 0.8)
            }
            TextInput {
                selectionColor: Theme.accent
                selectedTextColor: "white"
                id: search
                anchors.left: mag.right
                anchors.leftMargin: 6
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: "white"
                font.family: Theme.font
                font.pixelSize: Theme.px(14)
                clip: true
                Label {
                    visible: !search.text
                    text: I18n.tr("Search")
                    color: Qt.rgba(1, 1, 1, 0.6)
                    font.pixelSize: Theme.px(14)
                    anchors.verticalCenter: parent.verticalCenter
                }
                Keys.onEscapePressed: Panels.launchpad = false
                Keys.onReturnPressed: if (root.apps.length) root.launch(root.apps[0])
                Keys.onRightPressed: pager.incrementCurrentIndex()
                Keys.onLeftPressed: pager.decrementCurrentIndex()
            }
        }

        ListView {
            id: pager
            anchors.top: field.bottom
            anchors.topMargin: 40
            anchors.bottom: dots.top
            anchors.bottomMargin: 20
            anchors.left: parent.left
            anchors.right: parent.right
            orientation: ListView.Horizontal
            snapMode: ListView.SnapOneItem
            highlightRangeMode: ListView.StrictlyEnforceRange
            highlightMoveDuration: 350
            boundsBehavior: Flickable.StopAtBounds
            model: root.pages
            clip: true

            delegate: Item {
                id: page
                required property int index
                width: pager.width
                height: pager.height

                Grid {
                    id: pageGrid
                    anchors.centerIn: parent
                    columns: root.cols
                    readonly property real cellW: Math.min(150, (page.width - 200) / root.cols)
                    readonly property real cellH: Math.min(150, page.height / root.rows)

                    Repeater {
                        model: root.apps.slice(page.index * root.perPage, (page.index + 1) * root.perPage)

                        Item {
                            id: cell
                            required property var modelData
                            width: pageGrid.cellW
                            height: pageGrid.cellH

                            Image {
                                id: icon
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: (parent.height - height - name.height - 8) / 2
                                width: Math.min(84, parent.width * 0.62)
                                height: width
                                sourceSize: Qt.size(width * 2, height * 2)
                                source: Quickshell.iconPath(cell.modelData.icon, "application-x-executable")
                                scale: ma.pressed ? 0.9 : 1
                                Behavior on scale { NumberAnimation { duration: Theme.ms(90) } }
                            }
                            Label {
                                id: name
                                anchors.top: icon.bottom
                                anchors.topMargin: 8
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: parent.width - 10
                                horizontalAlignment: Text.AlignHCenter
                                text: Apps.title(cell.modelData)
                                color: "white"
                                font.pixelSize: Theme.px(12)
                                style: Text.Raised
                                styleColor: Qt.rgba(0, 0, 0, 0.35)
                            }
                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                onClicked: root.launch(cell.modelData)
                            }
                        }
                    }
                }
            }

            WheelHandler {
                onWheel: e => {
                    if (e.angleDelta.y < 0 || e.angleDelta.x < 0) pager.incrementCurrentIndex();
                    else pager.decrementCurrentIndex();
                }
            }
        }

        Row {
            id: dots
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Settings.dockIconSize + 50
            spacing: 10
            visible: root.pages > 1
            Repeater {
                model: root.pages
                Rectangle {
                    required property int index
                    width: 7; height: 7; radius: 3.5
                    color: index === pager.currentIndex ? "white" : Qt.rgba(1, 1, 1, 0.35)
                    MouseArea { anchors.fill: parent; anchors.margins: -5; onClicked: pager.currentIndex = parent.index }
                }
            }
        }
    }

    function launch(entry) {
        Panels.launchpad = false;
        entry.execute();
    }
}
