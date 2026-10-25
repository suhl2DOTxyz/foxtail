import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Desktop picture. Cross-fades when the wallpaper setting changes.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "foxtail-wallpaper"
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "black"

    property string current: Settings.wallpaper

    Image {
        id: back
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width, root.height)
        asynchronous: true
    }

    Image {
        id: front
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(root.width, root.height)
        asynchronous: true
        source: "file://" + root.current
        onStatusChanged: if (status === Image.Ready) fade.restart()
    }

    NumberAnimation {
        id: fade
        target: front
        property: "opacity"
        from: 0
        to: 1
        duration: 600
        easing.type: Easing.InOutQuad
        onFinished: back.source = front.source
    }
}
