//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma IconTheme WhiteSur
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Polkit
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
            property bool launchpadUsed: false
            Connections {
                target: Panels
                function onLaunchpadChanged() { if (Panels.launchpad) perScreen.launchpadUsed = true; }
            }
            Wallpaper { modelData: perScreen.modelData }
            Desktop { modelData: perScreen.modelData }
            MenuBar { modelData: perScreen.modelData }
            Dock { modelData: perScreen.modelData }
            Overlay { modelData: perScreen.modelData }
            // Loaded on first use, then kept so they open instantly.
            LazyLoader { active: perScreen.launchpadUsed; Launchpad { modelData: perScreen.modelData } }
            Banners { modelData: perScreen.modelData }
            Osd { modelData: perScreen.modelData }
            AppSwitcher { modelData: perScreen.modelData }
            MissionControl { modelData: perScreen.modelData }
            LazyLoader { active: Panels.screenshotBar || Capture.recording; CaptureBar { modelData: perScreen.modelData } }
            ScreenshotThumb { modelData: perScreen.modelData }
            HotCorners { modelData: perScreen.modelData }
        }
    }

    LockScreen {}

    // Foxtail's polkit agent: apps and Software Update ask for the
    // administrator password in modules/AuthDialog.qml.
    PolkitAgent {
        id: polkit
        onIsActiveChanged: {
            if (isActive) Panels.confirm = "auth";
            else if (Panels.confirm === "auth") Panels.confirm = "";
        }
    }
    Binding { target: Panels; property: "authFlow"; value: polkit.flow }

    // A dismissed Bluetooth Connection Request or password prompt (Cancel,
    // Escape) is a "no".
    Connections {
        target: Panels
        function onConfirmChanged() {
            if (Panels.confirm !== "bluetooth" && Panels.bluetoothRequest) Panels.answerBluetooth(false);
            if (Panels.confirm !== "auth" && polkit.flow && !polkit.flow.isCompleted) polkit.flow.cancelAuthenticationRequest();
        }
    }

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

    // Appearance "Auto": Light by day, Dark from 7 PM to 7 AM. (macOS follows
    // sunset; Foxtail has no location service, so it uses fixed hours.)
    Timer {
        interval: 60000
        repeat: true
        triggeredOnStart: true
        running: Settings.appearanceAuto
        onTriggered: {
            const h = new Date().getHours();
            const dark = h >= 19 || h < 7;
            if (Settings.darkMode !== dark) Settings.darkMode = dark;
        }
    }

    // Services that work in the background (Night Shift, generated Hyprland
    // config, clipboard history) start with the shell, not on first use.
    readonly property var backgroundServices: [HyprConfig, Displays, Keyboard, Clipboard, Capture]

    // Global shortcuts bound in hypr/foxtail.lua with hl.dsp.global("foxtail:<name>").
    GlobalShortcut { appid: "foxtail"; name: "switcherNext"; onPressed: Switcher.step(1) }
    GlobalShortcut { appid: "foxtail"; name: "switcherPrev"; onPressed: Switcher.step(-1) }
    GlobalShortcut { appid: "foxtail"; name: "switcherCommit"; onPressed: Switcher.commit() }
    GlobalShortcut {
        appid: "foxtail"
        name: "missionControl"
        onPressed: { Panels.popover = ""; Panels.spotlight = false; Panels.missionControl = !Panels.missionControl; }
    }

    // App windows exist only while open, so they cost no memory otherwise.
    LazyLoader { active: Panels.settings; SettingsWindow {} }
    LazyLoader { active: Panels.about; AboutWindow {} }
    LazyLoader { active: Panels.forceQuit; ForceQuitWindow {} }
    LazyLoader { active: Panels.installer; InstallerWindow {} }
    LazyLoader { active: Panels.setupAssistant; SetupAssistant {} }

    // Setup Assistant: on an account's first login, and once after each major
    // update (like macOS's setup screens). Not in the live session, where the
    // installer opens instead.
    Timer {
        interval: 2500
        running: Settings.loaded && Settings.setupVersion < 2 && Quickshell.env("USER") !== "liveuser"
        onTriggered: Panels.setupAssistant = true
    }

    // Keep GTK/libadwaita apps in step with Foxtail's appearance settings.
    Connections {
        target: Settings
        function onDarkModeChanged() {
            root.syncGtk();
            // Dynamic wallpaper follows the appearance.
            if (Settings.dynamicWallpaper)
                Settings.wallpaper = Settings.dynamicFile(Settings.darkMode);
        }
        function onAccentChanged() { root.syncGtk(); }
    }
    // Accessibility settings reach GTK apps (and Orca) too.
    Connections {
        target: Settings
        function onTextScaleChanged() { root.syncA11y(); }
        function onIncreaseContrastChanged() { root.syncA11y(); }
        function onReduceMotionChanged() { root.syncA11y(); }
        function onScreenReaderChanged() { root.syncA11y(); }
    }
    function syncA11y() {
        Quickshell.execDetached(["foxtail-sync-a11y", Settings.textScale.toFixed(2),
                                 Settings.increaseContrast ? "1" : "0", Settings.reduceMotion ? "1" : "0",
                                 Settings.screenReader ? "1" : "0"]);
    }

    Component.onCompleted: {
        syncGtk();
        syncA11y();
        Sounds.startup();
    }
    // Dynamic wallpaper: on for the Foxtail pictures that have a light and a
    // dark version; a wallpaper picked before it existed stays put. Checked
    // once settings.json has been read (not against the defaults).
    Connections {
        target: Settings
        function onLoadedChanged() {
            if (!Settings.loaded || !Settings.dynamicWallpaper) return;
            if (!/foxtail-(dawn|dusk|vixen-day|vixen-night)\.jpg$/.test(Settings.wallpaper)) Settings.dynamicWallpaper = false;
            else Settings.wallpaper = Settings.dynamicFile(Settings.darkMode);
        }
    }

    function syncGtk() {
        Quickshell.execDetached(["foxtail-sync-appearance",
                                 Settings.darkMode ? "dark" : "light", Settings.accent]);
    }

    IpcHandler {
        target: "foxtail"

        function spotlight(): void {
            Panels.popover = "";
            Panels.launchpad = false;
            Panels.spotlight = !Panels.spotlight;
        }
        function spotlightMode(index: int): void { Panels.spotlightMode(index); }
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
        function launchApp(id: string): void { Apps.launch(id); }
        function forceQuit(): void { Panels.forceQuit = true; }
        function installer(): void { Panels.installer = true; }
        function setupAssistant(): void { Panels.setupAssistant = true; }
        function bluetoothRequest(id: string, kind: string, name: string, code: string): void {
            Panels.bluetoothRequest = { id: id, kind: kind, name: name, code: code };
            Panels.confirm = "bluetooth";
        }
        function bluetoothRequestDone(id: string): void {
            if (Panels.bluetoothRequest && (id === "0" || Panels.bluetoothRequest.id === id)) {
                Panels.bluetoothRequest = null;
                if (Panels.confirm === "bluetooth") Panels.confirm = "";
            }
        }
        function lock(): void { Lock.lock(); }
        function power(kind: string): void { Panels.confirm = kind; }
        function closeAll(): void { Panels.closeAll(); }
        function restoreAll(): void { Hypr.restoreAll(); }
        function missionControl(): void { Panels.missionControl = !Panels.missionControl; }
        function emoji(): void {
            Panels.toggle("emoji", Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]);
        }
        function clipboard(): void {
            Panels.anchorX = 0;
            Panels.toggle("clipboard", Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]);
        }
        function screenshotToolbar(): void {
            Panels.closeAll();
            if (Capture.recording) Capture.stop();
            else Panels.screenshotBar = !Panels.screenshotBar;
        }
        function stopRecording(): void { Capture.stop(); }
        function desktopKey(key: string): void { Panels.desktopKey(key); }
        function desktopBlur(): void { Panels.desktopActive = false; }
        function screenshot(kind: string): void { Capture.shoot(kind, 0, false, false); }
        function screenshotToClipboard(kind: string): void { Capture.shoot(kind, 0, false, true); }
        function nightShift(): void { Settings.nightShiftNow = !Settings.nightShiftNow; }

        function volumeUp(): void { Audio.setVolume(Audio.volume + 0.0625); Sounds.volumeChanged(); }
        function volumeDown(): void { Audio.setVolume(Audio.volume - 0.0625); Sounds.volumeChanged(); }
        function volumeMute(): void { Audio.toggleMute(); }
        function brightnessUp(): void { Brightness.set(Brightness.value + 0.0625); }
        function brightnessDown(): void { Brightness.set(Brightness.value - 0.0625); }

        function toggleLiquidGlass(): void { Settings.liquidGlass = !Settings.liquidGlass; }
        function toggleDarkMode(): void { Settings.appearanceAuto = false; Settings.darkMode = !Settings.darkMode; }
        function liquidGlass(): bool { return Settings.liquidGlass; }
    }
}
