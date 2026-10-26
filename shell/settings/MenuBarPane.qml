import QtQuick
import Quickshell
import qs.services
import qs.components

// System Settings › Menu Bar (macOS Tahoe): the clear bar's background,
// auto-hide, and which items it shows.
Column {
    spacing: 14

    Group {
        SettingRow {
            label: "Show menu bar background"
            sub: "Tahoe's menu bar is clear, so the wallpaper shows through. Turn this on for a frosted bar."
            Switch { checked: Settings.menuBarBackground; onToggled: c => Settings.menuBarBackground = c }
        }
        SettingRow {
            label: "Automatically hide and show the menu bar"
            sub: "Move the pointer to the top of the screen to show it."
            last: true
            Switch { checked: Settings.menuBarAutoHide; onToggled: c => Settings.menuBarAutoHide = c }
        }
    }

    SectionTitle { text: "Menu Bar Controls" }
    Group {
        SettingRow {
            icon: "wifi"; iconColor: "#0A84FF"
            label: "Wi-Fi"
            Switch { checked: Settings.menuBarWifi; onToggled: c => Settings.menuBarWifi = c }
        }
        SettingRow {
            icon: "speaker"; iconColor: "#FF2D55"
            label: "Sound"
            Switch { checked: Settings.menuBarSound; onToggled: c => Settings.menuBarSound = c }
        }
        SettingRow {
            icon: "battery"; iconColor: "#30D158"
            label: "Battery percentage"
            visible: Power.hasBattery
            Switch { checked: Settings.showBatteryPercent; onToggled: c => Settings.showBatteryPercent = c }
        }
        SettingRow {
            icon: "search"; iconColor: "#8E8E93"
            label: "Spotlight"
            last: true
            Switch { checked: Settings.menuBarSpotlight; onToggled: c => Settings.menuBarSpotlight = c }
        }
    }
    Note { text: "Control Center and the clock are always in the menu bar. Set the clock's format in Date & Time." }
}
