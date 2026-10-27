import QtQuick
import Quickshell
import qs.services
import qs.components

// System Settings › Mouse.
Column {
    spacing: 14

    Group {
        SettingRow {
            label: I18n.tr("Tracking speed")
            Row {
                spacing: 10
                Label { text: I18n.tr("Slow"); font.pixelSize: Theme.px(11); color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                PlainSlider { width: 160; anchors.verticalCenter: parent.verticalCenter; from: -1; to: 1; value: Settings.pointerSpeed; onMoved: v => Settings.pointerSpeed = v }
                Label { text: I18n.tr("Fast"); font.pixelSize: Theme.px(11); color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        SettingRow {
            label: I18n.tr("Natural scrolling")
            sub: I18n.tr("Content tracks finger movement, as on a trackpad.")
            last: true
            Switch { checked: Settings.mouseNaturalScroll; onToggled: c => Settings.mouseNaturalScroll = c }
        }
    }
    Note { text: I18n.tr("Tracking speed is shared with the trackpad.") }
}
