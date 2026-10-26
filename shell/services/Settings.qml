pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User preferences, persisted to ~/.config/foxtail/settings.json.
// Anything that writes these properties is saved automatically; edits made to
// the file from outside (e.g. by hand) are picked up live.
Singleton {
    id: root

    property alias liquidGlass: adapter.liquidGlass
    property alias darkMode: adapter.darkMode
    property alias accent: adapter.accent
    property alias wallpaper: adapter.wallpaper
    property alias pinnedApps: adapter.pinnedApps
    property alias dockIconSize: adapter.dockIconSize
    property alias dockMagnification: adapter.dockMagnification
    property alias dockMagnifySize: adapter.dockMagnifySize
    property alias dockAutoHide: adapter.dockAutoHide
    property alias showRecents: adapter.showRecents
    property alias clock24h: adapter.clock24h
    property alias clockSeconds: adapter.clockSeconds
    property alias doNotDisturb: adapter.doNotDisturb
    property alias reduceTransparency: adapter.reduceTransparency
    property alias lockAfter: adapter.lockAfter
    property alias refractWindows: adapter.refractWindows
    property alias autoCheckUpdates: adapter.autoCheckUpdates
    property alias showBatteryPercent: adapter.showBatteryPercent
    property alias autoLowPower: adapter.autoLowPower
    property alias displayOffAfter: adapter.displayOffAfter

    readonly property string dir: Quickshell.env("HOME") + "/.config/foxtail"
    readonly property string wallpaperDir: "/usr/share/backgrounds/foxtail"

    FileView {
        path: root.dir + "/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                Quickshell.execDetached(["mkdir", "-p", root.dir]);
                writeAdapter();
            }
        }

        JsonAdapter {
            id: adapter
            property bool liquidGlass: true
            property bool darkMode: false
            property string accent: "#FF7A1A"
            property string wallpaper: "/usr/share/backgrounds/foxtail/foxtail-dawn.jpg"
            property list<string> pinnedApps: [
                "org.gnome.Nautilus",
                "firefox",
                "org.gnome.Ptyxis",
                "org.gnome.TextEditor",
                "org.gnome.Calculator",
                "org.gnome.Loupe",
                "foxtail-settings"
            ]
            property real dockIconSize: 54
            property bool dockMagnification: true
            property real dockMagnifySize: 1.75
            property bool dockAutoHide: false
            property bool showRecents: true
            property bool clock24h: false
            property bool clockSeconds: false
            property bool doNotDisturb: false
            property bool reduceTransparency: false
            property bool autoCheckUpdates: true
            property bool showBatteryPercent: true
            property bool autoLowPower: true
            property bool refractWindows: true  // Liquid Glass popovers refract windows, not just the wallpaper
            property int lockAfter: 5          // minutes idle before locking; 0 = never
            property int displayOffAfter: 10   // minutes idle before the display sleeps; 0 = never
        }
    }
}
