import QtQuick
import Quickshell
import qs.services
import qs.components

// System Settings › Mouse.
Column {
    spacing: 14

    Group {
        SettingRow {
            label: "Tracking speed"
            Row {
                spacing: 10
                Label { text: "Slow"; font.pixelSize: 11; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                PlainSlider { width: 160; anchors.verticalCenter: parent.verticalCenter; from: -1; to: 1; value: Settings.pointerSpeed; onMoved: v => Settings.pointerSpeed = v }
                Label { text: "Fast"; font.pixelSize: 11; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        SettingRow {
            label: "Natural scrolling"
            sub: "Content tracks finger movement, as on a trackpad."
            last: true
            Switch { checked: Settings.mouseNaturalScroll; onToggled: c => Settings.mouseNaturalScroll = c }
        }
    }
    Note { text: "Tracking speed is shared with the trackpad." }
}
