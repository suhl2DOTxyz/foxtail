import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import qs.services
import qs.components

// Dock ▸ Downloads: the macOS stack in grid view - the newest downloads,
// click one to open it, or open the whole folder in Files.
Item {
    id: root

    property point windowOffset
    property size screenSize

    readonly property string dir: Quickshell.env("HOME") + "/Downloads"
    readonly property int columns: 4
    readonly property int shown: Math.min(files.count, 12)

    width: columns * 96 + 24
    height: Math.max(1, Math.ceil(shown / columns)) * 100 + 70 + (shown === 0 ? 20 : 0)

    FolderListModel {
        id: files
        folder: "file://" + root.dir
        showDirsFirst: false
        showHidden: false
        showDotAndDotDot: false
        sortField: FolderListModel.Time     // newest first
    }

    scale: 0.94
    opacity: 0
    transformOrigin: Item.Bottom
    Component.onCompleted: { scale = 1; opacity = 1; }
    Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutBack } }
    Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

    MouseArea { anchors.fill: parent }

    Glass {
        anchors.fill: parent
        radius: Theme.liquid ? 24 : 14
        color: Theme.glassStrong
        windowOffset: root.windowOffset
        screenSize: root.screenSize
        rimOpacity: 0.85
    }

    Label {
        x: 18; y: 12
        text: "Downloads"
        font.weight: Font.Bold
        font.pixelSize: 15
    }

    Label {
        visible: root.shown === 0
        anchors.centerIn: parent
        text: "No downloads yet"
        color: Theme.textSecondary
    }

    Grid {
        x: 12; y: 40
        columns: root.columns
        Repeater {
            model: root.shown
            Item {
                id: tile
                required property int index
                readonly property string name: files.get(index, "fileName") ?? ""
                readonly property string path: files.get(index, "filePath") ?? ""
                width: 96; height: 100
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 3
                    radius: 10
                    color: tileMouse.containsMouse ? Theme.hover : "transparent"
                }
                FileIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 8
                    size: 52
                    file: ({ name: tile.name, isDir: files.get(tile.index, "fileIsDir"), suffix: tile.name.lastIndexOf(".") > 0 ? tile.name.slice(tile.name.lastIndexOf(".") + 1).toLowerCase() : "" })
                    path: tile.path
                    uri: "file://" + encodeURI(tile.path)
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 64
                    width: 88
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideMiddle
                    text: tile.name
                    font.family: Theme.font
                    font.pixelSize: 11
                    color: Theme.text
                }
                MouseArea {
                    id: tileMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: {
                        Panels.closeAll();
                        Quickshell.execDetached(["xdg-open", tile.path]);
                    }
                }
            }
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        width: openLabel.implicitWidth + 28
        height: 26
        radius: 13
        color: openMouse.containsMouse ? Theme.pressed : Theme.control
        Label { id: openLabel; anchors.centerIn: parent; text: "Open in Files"; font.pixelSize: 12 }
        MouseArea {
            id: openMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                Panels.closeAll();
                Quickshell.execDetached(["xdg-open", root.dir]);
            }
        }
    }
}
