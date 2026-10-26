import QtQuick
import Quickshell
import qs.services
import qs.components

// System Settings › Trackpad: speed, clicking, scrolling and gestures,
// with macOS's defaults (natural scrolling, two-finger secondary click).
Column {
    spacing: 14

    SectionTitle { text: "Point & Click" }
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
            label: "Tap to click"
            sub: "Tap with one finger to click."
            Switch { checked: Settings.tapToClick; onToggled: c => Settings.tapToClick = c }
        }
        SettingRow {
            label: "Secondary click"
            sub: "Click or tap with two fingers."
            last: true
            Switch { checked: Settings.twoFingerSecondary; onToggled: c => Settings.twoFingerSecondary = c }
        }
    }

    SectionTitle { text: "Scroll & Zoom" }
    Group {
        SettingRow {
            label: "Natural scrolling"
            sub: "Content tracks finger movement."
            Switch { checked: Settings.trackpadNaturalScroll; onToggled: c => Settings.trackpadNaturalScroll = c }
        }
        SettingRow {
            label: "Scrolling speed"
            last: true
            PlainSlider { width: 160; from: 0.2; to: 1.6; value: Settings.trackpadScrollSpeed; onMoved: v => Settings.trackpadScrollSpeed = v }
        }
    }

    SectionTitle { text: "More Gestures" }
    Group {
        SettingRow {
            label: "Swipe between desktops and Mission Control"
            sub: "Swipe left or right with three fingers to change desktop; swipe up for Mission Control."
            last: true
            Switch { checked: Settings.trackpadGestures; onToggled: c => Settings.trackpadGestures = c }
        }
    }
}
