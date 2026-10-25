import QtQuick
import qs.services

// A Foxtail glyph from shell/icons, tinted to any color.
Item {
    id: root

    property string name
    property color color: Theme.text
    property real size: 16

    implicitWidth: size
    implicitHeight: size

    Image {
        id: img
        anchors.fill: parent
        visible: false
        source: root.name ? Qt.resolvedUrl("../icons/" + root.name + ".svg") : ""
        sourceSize: Qt.size(root.size * 2, root.size * 2)
        smooth: true
    }

    ShaderEffect {
        anchors.fill: parent
        property var source: img
        property vector4d color: Qt.vector4d(root.color.r, root.color.g, root.color.b, root.color.a)
        fragmentShader: Qt.resolvedUrl("../shaders/tint.frag.qsb")
    }
}
