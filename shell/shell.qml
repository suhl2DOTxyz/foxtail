//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma IconTheme WhiteSur
import QtQuick
import Quickshell
import Quickshell.Io
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
