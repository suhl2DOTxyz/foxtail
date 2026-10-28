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

            // macOS 27's glassy shading: a soft highlight across the top.
            Rectangle {
                visible: root.active || hover.hovered
                x: 2.5; y: 1
                width: parent.width - 5
                height: parent.height * 0.5
                radius: height / 2
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.55) }
                    GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
                }
            }

            Icon {
                anchors.centerIn: parent
                visible: hover.hovered
                size: modelData.s === "zoom" ? 7 : 8
                name: modelData.g
                color: Qt.rgba(0, 0, 0, 0.55)
            }

            Accessible.role: Accessible.Button
            Accessible.name: modelData.s === "close" ? I18n.tr("Close") : modelData.s === "minimize" ? I18n.tr("Minimize") : I18n.tr("Zoom")
            Accessible.onPressAction: root[modelData.s]()

            // macOS window buttons work on the first click, even in an
            // inactive window. Activating the window takes the pointer grab
            // away from us mid-click (canceled), so count that as a click too.
            MouseArea {
                property bool armed: false
                anchors.fill: parent
                onPressed: armed = true
                onClicked: { armed = false; root[modelData.s](); }
                onCanceled: { if (armed) root[modelData.s](); armed = false; }
                onReleased: if (!containsMouse) armed = false
            }
        }
    }
}
