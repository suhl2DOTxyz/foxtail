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
    property alias glassTinted: adapter.glassTinted
    // Liquid Glass transparency, macOS 27 style: 0 = clearest, 1 = fully
    // tinted. Accounts from before the slider keep their Clear/Tinted choice.
    property alias glassTint: adapter.glassTint
    readonly property real glassTintLevel: adapter.glassTint >= 0 ? adapter.glassTint : (adapter.glassTinted ? 1 : 0.25)
    property alias darkMode: adapter.darkMode
    property alias appearanceAuto: adapter.appearanceAuto
    property alias accent: adapter.accent
    property alias wallpaper: adapter.wallpaper
    property alias dynamicWallpaper: adapter.dynamicWallpaper
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
    property alias reduceMotion: adapter.reduceMotion
    property alias increaseContrast: adapter.increaseContrast
    property alias textScale: adapter.textScale
    property alias zoomKeys: adapter.zoomKeys
    property alias screenReader: adapter.screenReader
    property alias lockAfter: adapter.lockAfter
    property alias refractWindows: adapter.refractWindows
    property alias autoCheckUpdates: adapter.autoCheckUpdates
    property alias showBatteryPercent: adapter.showBatteryPercent
    property alias autoLowPower: adapter.autoLowPower
    property alias lidAction: adapter.lidAction
    property alias customShortcuts: adapter.customShortcuts
    property alias displayOffAfter: adapter.displayOffAfter
    property alias displays: adapter.displays
    property alias nightShiftNow: adapter.nightShiftNow
    property alias nightShiftSchedule: adapter.nightShiftSchedule
    property alias nightShiftFrom: adapter.nightShiftFrom
    property alias nightShiftTo: adapter.nightShiftTo
    property alias nightShiftWarmth: adapter.nightShiftWarmth
    property alias keyboardLayouts: adapter.keyboardLayouts
    property alias keyRepeatDelay: adapter.keyRepeatDelay
    property alias keyRepeatRate: adapter.keyRepeatRate
    property alias layoutSwitchShortcut: adapter.layoutSwitchShortcut
    property alias clipboardHistory: adapter.clipboardHistory
    property alias screenshotTimer: adapter.screenshotTimer
    property alias screenshotPointer: adapter.screenshotPointer
    property alias screenshotSaveTo: adapter.screenshotSaveTo
    property alias showDesktopItems: adapter.showDesktopItems
    property alias desktopSort: adapter.desktopSort
    property alias uiSounds: adapter.uiSounds
    property alias volumeFeedback: adapter.volumeFeedback
    property alias notificationSounds: adapter.notificationSounds
    property alias startupSound: adapter.startupSound
    property alias emojiRecent: adapter.emojiRecent
    property alias hotCorners: adapter.hotCorners
    property alias menuBarBackground: adapter.menuBarBackground
    property alias menuBarAutoHide: adapter.menuBarAutoHide
    property alias menuBarWifi: adapter.menuBarWifi
    property alias menuBarSound: adapter.menuBarSound
    property alias menuBarSpotlight: adapter.menuBarSpotlight
    property alias pointerSpeed: adapter.pointerSpeed
    property alias mouseNaturalScroll: adapter.mouseNaturalScroll
    property alias trackpadNaturalScroll: adapter.trackpadNaturalScroll
    property alias tapToClick: adapter.tapToClick
    property alias twoFingerSecondary: adapter.twoFingerSecondary
    property alias trackpadScrollSpeed: adapter.trackpadScrollSpeed
    property alias trackpadGestures: adapter.trackpadGestures

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
            property bool glassTinted: false   // Liquid Glass "Tinted" (macOS 26.1); superseded by glassTint
            property real glassTint: -1        // 0..1 transparency slider (macOS 27); -1 = not set yet
            property bool darkMode: false
            property bool appearanceAuto: false   // Light by day, Dark from 7 PM to 7 AM
            property string accent: "#FF7A1A"
            property string wallpaper: "/usr/share/backgrounds/foxtail/foxtail-dawn.jpg"
            property bool dynamicWallpaper: true   // Dawn in Light mode, Dusk in Dark mode
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
            property bool dockMagnification: false   // off by default, as on macOS
            property real dockMagnifySize: 1.75
            property bool dockAutoHide: false
            property bool showRecents: true
            property bool clock24h: false
            property bool clockSeconds: false
            property bool doNotDisturb: false
            property bool reduceTransparency: false
            property bool reduceMotion: false
            property bool increaseContrast: false
            property real textScale: 1.0        // Accessibility ▸ Text size
            property bool zoomKeys: true        // ⌥⌘8 zoom, ⌥⌘= / ⌥⌘- in and out
            property bool screenReader: false   // Orca
            property bool autoCheckUpdates: true
            property bool showBatteryPercent: true
            property bool autoLowPower: true
            property string lidAction: "sleep"   // closing the lid: "sleep" | "lock" | "nothing"
            // Keyboard ▸ Custom shortcuts: [{ mods: ["SUPER", ...], key: "T", app: "<desktop id>" | "", command: "" }]
            property var customShortcuts: []
            property bool refractWindows: true  // Liquid Glass popovers refract windows, not just the wallpaper
            property int lockAfter: 5          // minutes idle before locking; 0 = never
            property int displayOffAfter: 10   // minutes idle before the display sleeps; 0 = never
            // Per-output display settings: { "DP-1": { mode, scale, x, y, transform, mirror, disabled } }
            property var displays: ({})
            property bool nightShiftNow: false
            property bool nightShiftSchedule: false
            property int nightShiftFrom: 1320  // minutes after midnight (22:00)
            property int nightShiftTo: 420     // 07:00
            property real nightShiftWarmth: 0.5
            property list<string> keyboardLayouts: []  // empty = the layout chosen in the installer
            property int keyRepeatDelay: 500   // ms
            property int keyRepeatRate: 30     // keys per second
            property bool layoutSwitchShortcut: true   // ⌃Space switches input source
            property bool clipboardHistory: true
            property int screenshotTimer: 0    // seconds
            property bool screenshotPointer: false
            property string screenshotSaveTo: "desktop"   // desktop | documents | pictures | clipboard
            property bool showDesktopItems: true
            property string desktopSort: "none"     // none | name | kind | date
            property bool uiSounds: true             // screenshot shutter, emptying the Trash, ...
            property bool volumeFeedback: true       // a click when the volume keys change the volume
            property bool notificationSounds: true
            property bool startupSound: true
            property list<string> emojiRecent: []
            // tl/tr/bl/br -> "" | mission | desktop | notifications | launchpad | lock | sleep
            property var hotCorners: ({ tl: "", tr: "", bl: "", br: "" })
            property bool menuBarBackground: false   // Tahoe's menu bar is clear unless this is on
            property bool menuBarAutoHide: false
            property bool menuBarWifi: true
            property bool menuBarSound: false
            property bool menuBarSpotlight: true
            property real pointerSpeed: 0            // -1..1, mouse and trackpad
            property bool mouseNaturalScroll: true   // macOS default
            property bool trackpadNaturalScroll: true
            property bool tapToClick: true
            property bool twoFingerSecondary: true   // click with two fingers = secondary click
            property real trackpadScrollSpeed: 0.6
            property bool trackpadGestures: true     // three-finger swipes
        }
    }
}
