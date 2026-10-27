import QtQuick
import Quickshell
import qs.services
import qs.components

// System Settings › Sound: pick output and input devices, set levels.
Column {
    spacing: 14

    SectionTitle { text: I18n.tr("Output") }
    Group {
        SettingRow {
            label: I18n.tr("Output volume")
            Row {
                spacing: 10
                Icon { size: 14; name: "speaker-low"; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                PlainSlider { width: 180; anchors.verticalCenter: parent.verticalCenter; value: Audio.volume; onMoved: v => Audio.setVolume(v) }
                Icon { size: 14; name: "speaker"; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        SettingRow {
            label: I18n.tr("Mute")
            last: true
            Switch { checked: Audio.muted; onToggled: Audio.toggleMute() }
        }
    }
    Note { visible: Audio.sinks.length > 0; text: I18n.tr("Play sound through") }
    Group {
        visible: Audio.sinks.length > 0
        Repeater {
            model: Audio.sinks
            SettingRow {
                required property var modelData
                required property int index
                icon: Audio.deviceIcon(modelData)
                label: Audio.deviceName(modelData)
                last: index === Audio.sinks.length - 1
                Radio { checked: Audio.sink === modelData; onClicked: Audio.setSink(modelData) }
            }
        }
    }
    Note { visible: Audio.sinks.length === 0; text: I18n.tr("No output devices found.") }

    SectionTitle { text: I18n.tr("Input") }
    Group {
        SettingRow {
            label: I18n.tr("Input volume")
            last: true
            Row {
                spacing: 10
                Icon { size: 14; name: "mic"; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                PlainSlider {
                    width: 180
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: Audio.sourceReady
                    value: Audio.inputVolume
                    onMoved: v => Audio.setInputVolume(v)
                }
            }
        }
    }
    Note { visible: Audio.sources.length > 0; text: I18n.tr("Use this microphone") }
    Group {
        visible: Audio.sources.length > 0
        Repeater {
            model: Audio.sources
            SettingRow {
                required property var modelData
                required property int index
                icon: Audio.deviceIcon(modelData)
                label: Audio.deviceName(modelData)
                last: index === Audio.sources.length - 1
                Radio { checked: Audio.source === modelData; onClicked: Audio.setSource(modelData) }
            }
        }
    }
    Note { visible: Audio.sources.length === 0; text: I18n.tr("No microphones found.") }

    SectionTitle { text: I18n.tr("Sound Effects") }
    Group {
        SettingRow {
            label: I18n.tr("Play sound on startup")
            Switch { checked: Settings.startupSound; onToggled: c => Settings.startupSound = c }
        }
        SettingRow {
            label: I18n.tr("Play user interface sound effects")
            sub: I18n.tr("Screenshots, emptying the Trash and other actions.")
            Switch { checked: Settings.uiSounds; onToggled: c => Settings.uiSounds = c }
        }
        SettingRow {
            label: I18n.tr("Play feedback when volume is changed")
            Switch { checked: Settings.volumeFeedback; onToggled: c => Settings.volumeFeedback = c }
        }
        SettingRow {
            label: I18n.tr("Play sound for notifications")
            last: true
            Switch { checked: Settings.notificationSounds; onToggled: c => Settings.notificationSounds = c }
        }
    }
}
