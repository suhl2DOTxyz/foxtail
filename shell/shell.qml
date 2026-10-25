//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma IconTheme WhiteSur
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.services
import qs.modules
import qs.windows

// Foxtail desktop shell.
//
// Keybinds and scripts talk to it over IPC, e.g.
//   qs -c foxtail ipc call foxtail spotlight
ShellRoot {
    id: root

    Variants {
        model: Quickshell.screens
        Scope {
            id: perScreen
            required property var modelData
            Wallpaper { modelData: perScreen.modelData }
            MenuBar { modelData: perScreen.modelData }
            Dock { modelData: perScreen.modelData }
            Overlay { modelData: perScreen.modelData }
            Launchpad { modelData: perScreen.modelData }
            Banners { modelData: perScreen.modelData }
            Osd { modelData: perScreen.modelData }
        }
    }

    LockScreen {}

    // Auto-lock and display sleep. Idle inhibitors (video playback, a
    // presentation) are respected, as on macOS. The monitors are recreated
    // whenever a timeout changes: an idle notification's timeout is fixed
    // once it has been registered with the compositor.
    Variants {
        model: Settings.lockAfter > 0 ? [Settings.lockAfter] : []
        IdleMonitor {
            required property int modelData
            timeout: modelData * 60
            respectInhibitors: true
            onIsIdleChanged: if (isIdle) Lock.lock()
        }
    }
    Variants {
        model: Settings.displayOffAfter > 0 ? [Settings.displayOffAfter] : []
        IdleMonitor {
            required property int modelData
            timeout: modelData * 60
            respectInhibitors: true
            onIsIdleChanged: Hypr.dispatch(`hl.dsp.dpms({ action = "${isIdle ? "off" : "on"}" })`)
        }
    }

    SettingsWindow {}
    AboutWindow {}
    ForceQuitWindow {}
    InstallerWindow {}

    // Keep GTK/libadwaita apps in step with Foxtail's appearance settings.
    Connections {
        target: Settings
        function onDarkModeChanged() { root.syncGtk(); }
        function onAccentChanged() { root.syncGtk(); }
    }
    Component.onCompleted: syncGtk()

    function syncGtk() {
        Quickshell.execDetached(["foxtail-sync-appearance",
                                 Settings.darkMode ? "dark" : "light", Settings.accent]);
    }

    IpcHandler {
        target: "foxtail"

        function spotlight(): void {
            Panels.popover = "";
            Panels.spotlight = !Panels.spotlight;
        }
        function launchpad(): void {
            Panels.popover = "";
            Panels.spotlight = false;
            Panels.launchpad = !Panels.launchpad;
        }
        function controlCenter(): void {
            Panels.anchorX = 99999;
            Panels.toggle("controlcenter", Quickshell.screens[0]);
        }
        function notificationCenter(): void {
            Panels.toggle("calendar", Quickshell.screens[0]);
        }
        function settings(pane: string): void { Panels.openSettings(pane); }
        function about(): void { Panels.about = true; }
        function forceQuit(): void { Panels.forceQuit = true; }
        function installer(): void { Panels.installer = true; }
        function lock(): void { Lock.lock(); }
        function power(kind: string): void { Panels.confirm = kind; }
        function closeAll(): void { Panels.closeAll(); }
        function restoreAll(): void { Hypr.restoreAll(); }

        function volumeUp(): void { Audio.setVolume(Audio.volume + 0.0625); }
        function volumeDown(): void { Audio.setVolume(Audio.volume - 0.0625); }
        function volumeMute(): void { Audio.toggleMute(); }
        function brightnessUp(): void { Brightness.set(Brightness.value + 0.0625); }
        function brightnessDown(): void { Brightness.set(Brightness.value - 0.0625); }

        function toggleLiquidGlass(): void { Settings.liquidGlass = !Settings.liquidGlass; }
        function toggleDarkMode(): void { Settings.darkMode = !Settings.darkMode; }
        function liquidGlass(): bool { return Settings.liquidGlass; }
    }
}
