pragma Singleton
import QtQuick
import Quickshell
import qs.services

// Contents of the fox menu and the "global" app menus.
//
// Wayland has no standard global-menu protocol, so the app menus are a
// common set whose items send the conventional keyboard shortcut to the
// focused app (via wtype) or act on its window through Hyprland.
Singleton {
    id: root

    readonly property var activeEntry: Apps.entryForToplevel(Hypr.activeToplevel)
    readonly property string appName: {
        if (!Hypr.activeClass || Hypr.isMinimized(Hypr.activeToplevel)) return "Files";
        if (Apps.isShellWindow(Hypr.activeToplevel)) return activeEntry?.name ?? Hypr.activeTitle;
        return activeEntry?.name ?? prettify(Hypr.activeClass);
    }

    readonly property var menuTitles: ["File", "Edit", "View", "Window", "Help"]

    function prettify(cls) {
        const last = cls.split(".").pop();
        return last.charAt(0).toUpperCase() + last.slice(1);
    }

    function keys(mods, key) {
        return () => Hypr.sendKeys(mods, key);
    }

    function run(cmd) {
        return () => Quickshell.execDetached(["sh", "-c", cmd]);
    }

    readonly property var foxMenu: [
        { text: "About This Foxtail", icon: "info", action: () => Panels.about = true },
        { separator: true },
        { text: "System Settings…", icon: "gear", action: () => Panels.openSettings() },
        { text: "App Store…", icon: "grid", action: run("gnome-software") },
        { separator: true },
        { text: "Force Quit…", icon: "xmark", shortcut: "⌥⌘⎋", action: () => Panels.forceQuit = true },
        { separator: true },
        { text: "Sleep", icon: "moon", action: run("systemctl suspend") },
        { text: "Restart…", icon: "restart", action: () => Panels.confirm = "restart" },
        { text: "Shut Down…", icon: "power", action: () => Panels.confirm = "shutdown" },
        { separator: true },
        { text: "Lock Screen", icon: "lock", shortcut: "⌃⌘Q", action: () => Lock.lock() },
        { text: `Log Out ${SystemInfo.fullName || SystemInfo.user}…`, icon: "logout", shortcut: "⇧⌘Q", action: () => Panels.confirm = "logout" }
    ]

    readonly property var appNameMenu: [
        { text: "Settings…", shortcut: "⌃,", action: keys(["ctrl"], "comma") },
        { separator: true },
        { text: `Hide ${appName}`, shortcut: "⌘H", enabled: !!Hypr.activeClass,
          action: () => Hypr.minimizeActive() },
        { text: "Show All", action: () => Hypr.restoreAll() },
        { separator: true },
        { text: `Quit ${appName}`, shortcut: "⌘Q", enabled: !!Hypr.activeClass, action: () => Hypr.closeActive() }
    ]

    readonly property var appMenus: [
        // File
        [
            { text: "New Window", shortcut: "⌃N", action: keys(["ctrl"], "n") },
            { text: "New Tab", shortcut: "⌃T", action: keys(["ctrl"], "t") },
            { text: "Open…", shortcut: "⌃O", action: keys(["ctrl"], "o") },
            { separator: true },
            { text: "Close Window", shortcut: "⌘W", action: () => Hypr.closeActive() },
            { text: "Save", shortcut: "⌃S", action: keys(["ctrl"], "s") },
            { text: "Save As…", shortcut: "⇧⌃S", action: keys(["ctrl", "shift"], "s") },
            { separator: true },
            { text: "Print…", shortcut: "⌃P", action: keys(["ctrl"], "p") }
        ],
        // Edit
        [
            { text: "Undo", shortcut: "⌃Z", action: keys(["ctrl"], "z") },
            { text: "Redo", shortcut: "⇧⌃Z", action: keys(["ctrl", "shift"], "z") },
            { separator: true },
            { text: "Cut", shortcut: "⌃X", action: keys(["ctrl"], "x") },
            { text: "Copy", shortcut: "⌃C", action: keys(["ctrl"], "c") },
            { text: "Paste", shortcut: "⌃V", action: keys(["ctrl"], "v") },
            { text: "Select All", shortcut: "⌃A", action: keys(["ctrl"], "a") },
            { separator: true },
            { text: "Find…", shortcut: "⌃F", action: keys(["ctrl"], "f") },
            { separator: true },
            { text: "Emoji & Symbols", shortcut: "⌘.", action: run("gnome-characters") }
        ],
        // View
        [
            { text: "Enter Full Screen", shortcut: "⌘F", action: () => Hypr.toggleFullscreen() },
            { separator: true },
            { text: "Zoom In", shortcut: "⌃+", action: keys(["ctrl"], "plus") },
            { text: "Zoom Out", shortcut: "⌃−", action: keys(["ctrl"], "minus") },
            { text: "Actual Size", shortcut: "⌃0", action: keys(["ctrl"], "0") }
        ],
        // Window
        [
            { text: "Minimize", shortcut: "⌘M",
              action: () => Hypr.minimizeActive() },
            { text: "Zoom", action: () => Hypr.dispatch("hl.dsp.window.fullscreen({ mode = \"maximized\" })") },
            { text: "Center", action: () => Hypr.dispatch("hl.dsp.window.center()") },
            { separator: true },
            { text: "Float / Tile Window", shortcut: "⌘T", action: () => Hypr.toggleFloat() },
            { separator: true },
            { text: "Bring All to Front", action: () => Hypr.restoreAll() }
        ],
        // Help
        [
            { header: true, text: "Foxtail Help" },
            { text: "Keyboard Shortcuts", action: () => Panels.openSettings("keyboard") },
            { text: "Foxtail Tips", action: () => Panels.about = true }
        ]
    ]

    function model(key) {
        if (key === "fox") return foxMenu;
        if (key === "app:name") return appNameMenu;
        if (key.startsWith("app:")) return appMenus[parseInt(key.slice(4))] ?? [];
        return [];
    }
}
