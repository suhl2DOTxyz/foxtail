pragma Singleton
import QtQuick
import qs.services
import Quickshell

// Which transient surfaces are open. Only one popover is open at a time, the
// way macOS closes a menu when you open Control Center.
Singleton {
    id: root

    // "" | "fox" | "app:<index>" | "controlcenter" | "calendar" | "wifi" | "dockmenu"
    property string popover: ""
    property bool spotlight: false
    property bool launchpad: false
    property bool settings: false
    property bool about: false
    property bool forceQuit: false
    property bool installer: false
    property bool missionControl: false
    property bool screenshotBar: false
    property string settingsPane: "appearance"

    // System Settings sidebar (also searched by Spotlight).
    readonly property var settingsPanes: [
        { id: "wifi", name: I18n.tr("Wi-Fi"), icon: "wifi", color: "#0A84FF", keywords: "network internet wireless" },
        { id: "bluetooth", name: I18n.tr("Bluetooth"), icon: "bluetooth", color: "#0A84FF", keywords: "devices headphones pair airpods" },
        { id: "sep" },
        { id: "general", name: I18n.tr("General"), icon: "gear", color: "#8E8E93", keywords: "about storage version login items open at login" },
        { id: "updates", name: I18n.tr("Software Update"), icon: "restart", color: "#8E8E93", keywords: "upgrade snapshots restore" },
        { id: "appearance", name: I18n.tr("Appearance"), icon: "half-circle", color: "#1C1C1E", keywords: "dark mode light auto accent color liquid glass clear tinted transparency" },
        { id: "menubar", name: I18n.tr("Menu Bar"), icon: "menubar", color: "#1C1C1E", keywords: "control center hide menu bar background clock battery sound" },
        { id: "desktop", name: I18n.tr("Desktop & Dock"), icon: "dock", color: "#1C1C1E", keywords: "dock magnification hot corners desktop icons windows minimize" },
        { id: "displays", name: I18n.tr("Displays"), icon: "sun", color: "#0A84FF", keywords: "resolution brightness night shift scale monitor arrangement" },
        { id: "battery", name: I18n.tr("Battery"), icon: "battery", color: "#30D158", keywords: "power low power energy" },
        { id: "wallpaper", name: I18n.tr("Wallpaper"), icon: "photo", color: "#30B0C7", keywords: "background desktop picture dynamic" },
        { id: "sep" },
        { id: "notifications", name: I18n.tr("Notifications"), icon: "bell", color: "#FF3B30", keywords: "alerts banners" },
        { id: "sound", name: I18n.tr("Sound"), icon: "speaker", color: "#FF2D55", keywords: "volume output input microphone speakers alert sound effects startup" },
        { id: "focus", name: I18n.tr("Focus"), icon: "moon", color: "#5E5CE6", keywords: "do not disturb" },
        { id: "sep" },
        { id: "accessibility", name: I18n.tr("Accessibility"), icon: "accessibility", color: "#0A84FF", keywords: "zoom text size larger contrast motion screen reader orca" },
        { id: "lock", name: I18n.tr("Lock Screen"), icon: "lock", color: "#1C1C1E", keywords: "password screen saver sleep" },
        { id: "users", name: I18n.tr("Users & Groups"), icon: "people", color: "#0A84FF", keywords: "accounts password admin" },
        { id: "datetime", name: I18n.tr("Date & Time"), icon: "clock", color: "#0A84FF", keywords: "timezone clock 24-hour" },
        { id: "sep" },
        { id: "keyboard", name: I18n.tr("Keyboard"), icon: "keyboard", color: "#8E8E93", keywords: "shortcuts input sources layout key repeat clipboard" },
        { id: "trackpad", name: I18n.tr("Trackpad"), icon: "trackpad", color: "#8E8E93", keywords: "tap to click natural scrolling gestures speed" },
        { id: "mouse", name: I18n.tr("Mouse"), icon: "mouse", color: "#8E8E93", keywords: "tracking speed natural scrolling" },
        { id: "printers", name: I18n.tr("Printers & Scanners"), icon: "printer", color: "#8E8E93", keywords: "cups print" },
        { id: "defaultapps", name: I18n.tr("Default Apps"), icon: "apps", color: "#FF7A1A", keywords: "browser mail open with" }
    ]
    // Pending power confirmation: "" | "restart" | "shutdown" | "logout"
    property string confirm: ""

    // Right-click menu anywhere (desktop, desktop icons): a MenuPanel model
    // shown at `contextPos` (screen coordinates) on `screen`.
    property var contextModel: []
    property point contextPos: Qt.point(0, 0)
    function showContext(model, x, y, scr) {
        spotlight = false;
        contextModel = model;
        contextPos = Qt.point(x, y);
        screen = scr ?? screen;
        popover = "context";
    }

    // A drag of files from the desktop ended without a taker, at x, y
    // (screen coordinates); the Dock checks whether it was over one of its items.
    signal fileDragEnded(var uris, real x, real y)

    // Dock ▸ Downloads stack: horizontal center of the icon it opens from.
    property real downloadsX: 0

    // Dock context menu payload
    property var dockMenuApp: null
    property real dockMenuX: 0

    // Horizontal extent of the menu-bar item a popover hangs from.
    property real anchorX: 0
    property real anchorRight: 0

    // Screen the popover belongs to
    property var screen: null

    readonly property bool anyOverlay: popover !== "" || spotlight

    function toggle(name, scr) {
        spotlight = false;
        if (popover === name) {
            popover = "";
        } else {
            popover = name;
            screen = scr ?? screen;
        }
    }

    // File ▸ New Folder while the desktop is in front.
    signal desktopNewFolder()
    // The desktop has keyboard focus (Files is the front app), and ⌘ keys
    // pressed there: "backspace", "A", "I", "O", "down", "SHIFT+N", "C".
    property bool desktopActive: false
    signal desktopKey(string key)
    // ⌘1–⌘4 while Spotlight is open (Applications, Files, Actions, Clipboard).
    signal spotlightMode(int index)

    function closeAll() {
        popover = "";
        spotlight = false;
        launchpad = false;
        missionControl = false;
    }

    function openSettings(pane) {
        closeAll();
        if (pane) settingsPane = pane;
        settings = true;
    }
}
