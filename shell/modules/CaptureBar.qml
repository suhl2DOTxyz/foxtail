import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.components

// ⇧⌘5: the macOS screenshot toolbar. Pick what to capture, then Capture
// (or Record). Options set a timer and whether the pointer is included.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    visible: Panels.screenshotBar && (Hyprland.focusedMonitor?.name === modelData.name)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "foxtail-popover"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    property bool optionsOpen: false
    onVisibleChanged: optionsOpen = false

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.12
    }
    MouseArea { anchors.fill: parent; onClicked: Panels.screenshotBar = false }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: Panels.screenshotBar = false
        Keys.onReturnPressed: Capture.capture()
    }

    readonly property var tools: [
        { id: "screen", icon: "screen-capture", tip: "Capture Entire Screen" },
        { id: "pick-window", icon: "window-capture", tip: "Capture Selected Window" },
        { id: "area", icon: "selection-capture", tip: "Capture Selected Portion" },
        { sep: true },
        { id: "record-screen", icon: "screen-record", tip: "Record Entire Screen" },
        { id: "record-area", icon: "selection-record", tip: "Record Selected Portion" },
        { sep: true }
    ]

    Item {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 120
        width: row.width + 20
        height: 56

        Glass {
            anchors.fill: parent
            radius: Theme.liquid ? height / 2 : 14
            color: Theme.glassStrong
            screenSize: Qt.size(root.width, root.height)
            windowOffset: Qt.point(bar.x, bar.y)
            rimOpacity: 0.7
            bezel: 16
        }
        MouseArea { anchors.fill: parent }

        Row {
            id: row
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            // Close
            ToolButton {
                icon: "xmark"
                tip: "Close"
                small: true
                onClicked: Panels.screenshotBar = false
            }
            Sep {}

            Repeater {
                model: root.tools
                Loader {
                    id: ld
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    sourceComponent: modelData.sep ? sepC : toolC
                    Component { id: sepC; Sep {} }
                    Component {
                        id: toolC
                        ToolButton {
                            icon: ld.modelData.icon
                            tip: ld.modelData.tip
                            selected: Capture.mode === ld.modelData.id
                            onClicked: Capture.mode = ld.modelData.id
                        }
                    }
                }
            }

            // Options
            Rectangle {
                id: optButton
                anchors.verticalCenter: parent.verticalCenter
                width: optLabel.implicitWidth + 34
                height: 36
                radius: Theme.liquid ? 18 : 8
                color: optMouse.containsMouse || root.optionsOpen ? Theme.hover : "transparent"
                Row {
                    anchors.centerIn: parent
                    spacing: 4
                    Label { id: optLabel; text: "Options"; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                    Icon { size: 10; name: "chevron-down"; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                }
                MouseArea { id: optMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.optionsOpen = !root.optionsOpen }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: goLabel.implicitWidth + 32
                height: 36
                radius: Theme.liquid ? 18 : 8
                color: goMouse.pressed ? Qt.darker(Theme.accent, 1.15) : Theme.accent
                Label {
                    id: goLabel
                    anchors.centerIn: parent
                    text: Capture.recordMode ? "Record" : "Capture"
                    color: "white"
                    font.weight: Font.DemiBold
                }
                MouseArea { id: goMouse; anchors.fill: parent; onClicked: Capture.capture() }
            }
        }

        // Options menu (opens upward)
        Rectangle {
            visible: root.optionsOpen
            x: optButton.mapToItem(bar, 0, 0).x
            y: -height - 8
            width: 210
            height: optCol.implicitHeight + 12
            radius: Theme.liquid ? 16 : 10
            color: Theme.dark ? "#2C2C2E" : "#FFFFFF"
            border.color: Theme.glassOutline
            Column {
                id: optCol
                x: 6; y: 6
                width: parent.width - 12
                OptHeader { text: "Save to" }
                Repeater {
                    model: [["desktop", "Desktop"], ["documents", "Documents"], ["pictures", "Pictures"], ["clipboard", "Clipboard"]]
                    OptItem {
                        required property var modelData
                        text: modelData[1]
                        checked: Settings.screenshotSaveTo === modelData[0]
                        onClicked: Settings.screenshotSaveTo = modelData[0]
                    }
                }
                OptHeader { text: "Timer" }
                Repeater {
                    model: [[0, "None"], [5, "5 Seconds"], [10, "10 Seconds"]]
                    OptItem {
                        required property var modelData
                        text: modelData[1]
                        checked: Settings.screenshotTimer === modelData[0]
                        onClicked: Settings.screenshotTimer = modelData[0]
                    }
                }
                OptHeader { text: "Options" }
                OptItem {
                    text: "Show Mouse Pointer"
                    checked: Settings.screenshotPointer
                    onClicked: Settings.screenshotPointer = !Settings.screenshotPointer
                }
            }
        }
    }

    // Tooltip-less label under the bar, like macOS's hint
    Label {
        anchors.horizontalCenter: bar.horizontalCenter
        anchors.top: bar.bottom
        anchors.topMargin: 10
        text: (root.tools.find(t => t.id === Capture.mode) ?? {}).tip ?? ""
        color: "white"
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.35)
        font.pixelSize: 12
    }

    component Sep: Rectangle {
        anchors.verticalCenter: parent?.verticalCenter
        width: 1; height: 28
        color: Theme.separator
    }

    component ToolButton: Rectangle {
        id: tb
        property string icon
        property string tip
        property bool selected: false
        property bool small: false
        signal clicked()
        anchors.verticalCenter: parent?.verticalCenter
        width: small ? 30 : 44
        height: small ? 30 : 40
        radius: Theme.liquid ? height / 2 : 8
        color: selected ? (Theme.dark ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(0, 0, 0, 0.1))
                        : (tbm.containsMouse ? Theme.hover : "transparent")
        Icon { anchors.centerIn: parent; size: tb.small ? 13 : 24; name: tb.icon; color: tb.selected ? Theme.accent : Theme.text }
        MouseArea { id: tbm; anchors.fill: parent; hoverEnabled: true; onClicked: tb.clicked() }
    }

    component OptHeader: Label {
        leftPadding: 10
        topPadding: 6
        bottomPadding: 2
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: Theme.textSecondary
    }

    component OptItem: Rectangle {
        id: oi
        property string text
        property bool checked: false
        signal clicked()
        width: parent?.width ?? 0
        height: 26
        radius: Theme.liquid ? 8 : 5
        color: oim.containsMouse ? Theme.accent : "transparent"
        Icon { x: 8; anchors.verticalCenter: parent.verticalCenter; visible: oi.checked; size: 11; name: "check"; color: oim.containsMouse ? "white" : Theme.text }
        Label { x: 26; anchors.verticalCenter: parent.verticalCenter; text: oi.text; font.pixelSize: 13; color: oim.containsMouse ? "white" : Theme.text }
        MouseArea { id: oim; anchors.fill: parent; hoverEnabled: true; onClicked: oi.clicked() }
    }
}
