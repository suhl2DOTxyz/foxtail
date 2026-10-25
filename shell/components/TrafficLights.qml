import QtQuick
import qs.services

// Close / minimize / zoom buttons. Glyphs appear when the group is hovered,
// exactly like macOS.
Row {
    id: root

    property bool active: true
    signal close()
    signal minimize()
    signal zoom()

    spacing: 8

    HoverHandler { id: hover }

    Repeater {
        model: [
            { c: "#FF5F57", b: "#E0443E", g: "xmark", s: "close" },
            { c: "#FEBC2E", b: "#DEA123", g: "minus", s: "minimize" },
            { c: "#28C840", b: "#1AAB29", g: "fullscreen", s: "zoom" }
        ]

        Rectangle {
            required property var modelData
            width: 12
            height: 12
            radius: 6
            color: root.active || hover.hovered ? modelData.c : (Theme.dark ? "#4A4A4C" : "#D0D0D2")
            border.width: 0.5
            border.color: root.active || hover.hovered ? modelData.b : "transparent"

            Icon {
                anchors.centerIn: parent
                visible: hover.hovered
                size: modelData.s === "zoom" ? 7 : 8
                name: modelData.g
                color: Qt.rgba(0, 0, 0, 0.55)
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root[modelData.s]()
            }
        }
    }
}
