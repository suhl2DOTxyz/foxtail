import QtQuick
import Quickshell
import qs.services
import qs.components

// System Settings › Accessibility: Display (text size, contrast, motion,
// transparency), Zoom and the screen reader.
Column {
    spacing: 14

    SectionTitle { text: I18n.tr("Display") }
    Group {
        SettingRow {
            label: I18n.tr("Text size")
            sub: I18n.tr("Larger text in the menu bar, Dock, menus and apps.")
            Row {
                spacing: 10
                Label { text: "A"; font.pixelSize: 11; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                PlainSlider {
                    id: textSize
                    // Applied on release: resizing every label while dragging is slow.
                    property real pending: Settings.textScale
                    width: 160
                    anchors.verticalCenter: parent.verticalCenter
                    from: 0.9; to: 1.35
                    value: Settings.textScale
                    onMoved: v => pending = v
                    onReleased: Settings.textScale = Math.round(pending * 20) / 20
                }
                Label { text: "A"; font.pixelSize: 17; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        SettingRow {
            label: I18n.tr("Increase contrast")
            sub: I18n.tr("Solid backgrounds, stronger borders and darker secondary text.")
            Switch { checked: Settings.increaseContrast; onToggled: c => Settings.increaseContrast = c }
        }
        SettingRow {
            label: I18n.tr("Reduce motion")
            sub: I18n.tr("Windows, menus and desktops change without animating.")
            Switch { checked: Settings.reduceMotion; onToggled: c => Settings.reduceMotion = c }
        }
        SettingRow {
            label: I18n.tr("Reduce transparency")
            sub: I18n.tr("Glass becomes solid.")
            last: true
            Switch { checked: Settings.reduceTransparency; onToggled: c => Settings.reduceTransparency = c }
        }
    }

    SectionTitle { text: I18n.tr("Zoom") }
    Group {
        SettingRow {
            label: I18n.tr("Use keyboard shortcuts to zoom")
            sub: I18n.tr("⌥⌘8 turns zoom on or off; ⌥⌘= and ⌥⌘- zoom in and out. The zoomed view follows the pointer.")
            last: true
            Switch { checked: Settings.zoomKeys; onToggled: c => Settings.zoomKeys = c }
        }
    }

    SectionTitle { text: I18n.tr("Spoken Content") }
    Group {
        SettingRow {
            label: I18n.tr("Screen reader")
            sub: I18n.tr("Orca reads out what's on screen in apps. Foxtail's own menus aren't read yet.")
            last: true
            Switch { checked: Settings.screenReader; onToggled: c => Settings.screenReader = c }
        }
    }
}
