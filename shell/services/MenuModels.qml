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
    // The focused window is actually on screen (not minimized or hidden).
    readonly property bool frontWindow: !!Hypr.activeClass && !Hypr.isMinimized(Hypr.activeToplevel) && !Hypr.isHidden(Hypr.activeToplevel)
    readonly property string appName: {
        if (Panels.desktopActive || !frontWindow) return "Files";
        if (Apps.isShellWindow(Hypr.activeToplevel)) return activeEntry ? Apps.title(activeEntry) : Hypr.activeTitle;
        return activeEntry ? Apps.title(activeEntry) : prettify(Hypr.activeClass);
    }

    // Files (and the desktop, which belongs to Files as it does to Finder)
    // gets Finder's menus, Go included.
    readonly property bool filesActive: Panels.desktopActive || !frontWindow || Hypr.activeClass === "org.gnome.Nautilus"
    readonly property bool filesWindow: !Panels.desktopActive && frontWindow && Hypr.activeClass === "org.gnome.Nautilus"
    // Menus written for the apps Foxtail ships (Wayland has no global menu,
    // so these send each app's own shortcuts); other apps get the generic set.
    readonly property var appSet: filesActive ? null : (appMenuSets[Hypr.activeClass] ?? null)
    readonly property var menuTitles: filesActive ? ["File", "Edit", "View", "Go", "Window", "Help"]
                                    : appSet ? appSet.titles.concat(["Window", "Help"])
                                    : ["File", "Edit", "View", "Window", "Help"]

    // Go menu: in a Files window, type the place into its location bar;
    // from the desktop, open a new window there.
    function goTo(place) {
        return () => {
            if (filesWindow) {
                Hypr.sendKeys(["ctrl"], "l");
                Quickshell.execDetached(["sh", "-c", 'sleep 0.3; p="$1"; case "$p" in xdg:*) p=$(xdg-user-dir "${p#xdg:}");; esac; wtype -- "$p"; wtype -k Return', "sh", place]);
            } else {
                Quickshell.execDetached(["sh", "-c", 'p="$1"; case "$p" in xdg:*) p=$(xdg-user-dir "${p#xdg:}");; esac; exec nautilus --new-window "$p"', "sh", place]);
            }
        };
    }

    readonly property var filesMenus: [
        // File
        [
            { text: "New Files Window", shortcut: "⌘N", action: filesWindow ? keys(["ctrl"], "n") : run("nautilus --new-window") },
            { text: "New Folder", shortcut: "⇧⌘N", action: filesWindow ? keys(["ctrl", "shift"], "n") : () => Panels.desktopNewFolder() },
            { text: "New Tab", shortcut: "⌘T", enabled: filesWindow, action: keys(["ctrl"], "t") },
            { text: "Open", shortcut: "⌘↓", enabled: filesWindow, action: keys([], "Return") },
            { separator: true },
            { text: "Close Window", shortcut: "⌘W", enabled: filesWindow, action: keys(["ctrl"], "w") },
            { separator: true },
            { text: "Get Info", shortcut: "⌘I", enabled: filesWindow, action: keys(["alt"], "Return") },
            { text: "Rename", enabled: filesWindow, action: keys([], "F2") },
            { separator: true },
            { text: "Move to Trash", shortcut: "⌘⌫", enabled: filesWindow, action: keys([], "Delete") },
            { separator: true },
            { text: "Find", shortcut: "⌘F", enabled: filesWindow, action: keys(["ctrl"], "f") }
        ],
        null,   // Edit (shared)
        // View
        [
            { text: "as Icons", shortcut: "⌘1", enabled: filesWindow, action: keys(["ctrl"], "1") },
            { text: "as List", shortcut: "⌘2", enabled: filesWindow, action: keys(["ctrl"], "2") },
            { separator: true },
            { text: "Show Hidden Files", shortcut: "⇧⌘.", enabled: filesWindow, action: keys(["ctrl"], "h") },
            { separator: true },
            { text: "Zoom In", shortcut: "⌘+", enabled: filesWindow, action: keys(["ctrl"], "plus") },
            { text: "Zoom Out", shortcut: "⌘−", enabled: filesWindow, action: keys(["ctrl"], "minus") }
        ],
        // Go
        [
            { text: "Back", shortcut: "⌘[", enabled: filesWindow, action: keys(["alt"], "Left") },
            { text: "Forward", shortcut: "⌘]", enabled: filesWindow, action: keys(["alt"], "Right") },
            { text: "Enclosing Folder", shortcut: "⌘↑", enabled: filesWindow, action: keys(["alt"], "Up") },
            { separator: true },
            { text: "Recents", icon: "clock", action: goTo("recent:///") },
            { text: "Documents", icon: "folder", shortcut: "⇧⌘O", action: goTo("xdg:DOCUMENTS") },
            { text: "Desktop", icon: "display", shortcut: "⇧⌘D", action: goTo("xdg:DESKTOP") },
            { text: "Downloads", icon: "arrow-right-circle", shortcut: "⌥⌘L", action: goTo("xdg:DOWNLOAD") },
            { text: "Home", icon: "person", shortcut: "⇧⌘H", action: goTo(Quickshell.env("HOME")) },
            { text: "Network", icon: "globe", action: goTo("network:///") },
            { text: "Trash", icon: "trash", action: goTo("trash:///") },
            { separator: true },
            { text: "Go to Folder…", shortcut: "⇧⌘G", action: filesWindow ? keys(["ctrl"], "l") : goTo(Quickshell.env("HOME")) }
        ]
    ]

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
        { text: Updates.count ? `Software Update… (${Updates.count})` : "Software Update…", icon: "restart",
          action: () => { Panels.openSettings("updates"); Updates.check(); } },
        { text: "App Store…", icon: "grid", action: run("gnome-software") },
        { separator: true },
        { text: "Recent Items", icon: "clock", submenu: recentItems },
        { separator: true },
        { text: "Force Quit…", icon: "xmark", shortcut: "⌥⌘⎋", action: () => Panels.forceQuit = true },
        { separator: true },
        { text: "Sleep", icon: "moon", action: run("systemctl suspend") },
        { text: "Restart…", icon: "restart", action: () => Panels.confirm = "restart" },
        { text: "Shut Down…", icon: "power", action: () => Panels.confirm = "shutdown" },
        { separator: true },
        { text: "Lock Screen", icon: "lock", shortcut: "⌃⌘Q", action: () => Lock.lock() },
        { text: `Log Out ${SystemInfo.fullName || SystemInfo.user}…`, icon: "logout", shortcut: "⌥⇧⌘Q", action: () => Panels.confirm = "logout" }
    ]

    // Apple menu ▸ Recent Items: the apps used most recently this session.
    readonly property var recentItems: {
        const apps = Apps.mruApps.filter(id => Apps.entry(id)).slice(0, 10);
        if (!apps.length) return [{ text: "No Recent Items", enabled: false }];
        return [{ header: true, text: "Applications" }].concat(apps.map(id => ({
            text: Apps.nameFor(id), action: () => Apps.focus(id)
        })));
    }

    readonly property var appNameMenu: [
        { text: "Settings…", shortcut: "⌘,", action: keys(["ctrl"], "comma") },
        { separator: true },
        { text: `Hide ${appName}`, shortcut: "⌘H", enabled: !!Hypr.activeClass,
          action: () => Hypr.hideActiveApp() },
        { text: "Hide Others", shortcut: "⌥⌘H", enabled: !!Hypr.activeClass,
          action: () => Hypr.hideOthers() },
        { text: "Show All", enabled: Hypr.hidden.length > 0, action: () => Hypr.showAll() },
        { separator: true },
        { text: `Quit ${appName}`, shortcut: "⌘Q", enabled: !!Hypr.activeClass, action: () => Hypr.quitActiveApp() }
    ]

    readonly property var appMenus: [
        // File
        [
            { text: "New Window", shortcut: "⌘N", action: keys(["ctrl"], "n") },
            { text: "New Tab", shortcut: "⌘T", action: keys(["ctrl"], "t") },
            { text: "Open…", shortcut: "⌘O", action: keys(["ctrl"], "o") },
            { separator: true },
            { text: "Close Window", shortcut: "⌘W", action: keys(["ctrl"], "w") },
            { text: "Save", shortcut: "⌘S", action: keys(["ctrl"], "s") },
            { text: "Save As…", shortcut: "⇧⌘S", action: keys(["ctrl", "shift"], "s") },
            { separator: true },
            { text: "Print…", shortcut: "⌘P", action: keys(["ctrl"], "p") }
        ],
        // Edit
        [
            { text: "Undo", shortcut: "⌘Z", action: keys(["ctrl"], "z") },
            { text: "Redo", shortcut: "⇧⌘Z", action: keys(["ctrl", "shift"], "z") },
            { separator: true },
            { text: "Cut", shortcut: "⌘X", action: keys(["ctrl"], "x") },
            { text: "Copy", shortcut: "⌘C", action: keys(["ctrl"], "c") },
            { text: "Paste", shortcut: "⌘V", action: keys(["ctrl"], "v") },
            { text: "Select All", shortcut: "⌘A", action: keys(["ctrl"], "a") },
            { separator: true },
            { text: "Find…", shortcut: "⌘F", action: keys(["ctrl"], "f") },
            { separator: true },
            { text: "Emoji & Symbols", shortcut: "⌃⌘Space", action: () => Panels.toggle("emoji", Panels.screen) }
        ],
        // View
        [
            { text: "Enter Full Screen", shortcut: "⌃⌘F", action: () => Hypr.toggleFullscreen() },
            { separator: true },
            { text: "Zoom In", shortcut: "⌘+", action: keys(["ctrl"], "plus") },
            { text: "Zoom Out", shortcut: "⌘−", action: keys(["ctrl"], "minus") },
            { text: "Actual Size", shortcut: "⌘0", action: keys(["ctrl"], "0") }
        ],
        // Window
        windowMenu,
        // Help
        [
            { header: true, text: "Foxtail Help" },
            { text: "Keyboard Shortcuts", action: () => Panels.openSettings("keyboard") },
            { text: "Foxtail Tips", action: () => Panels.about = true }
        ]
    ]

    readonly property var stdEdit: [
        { text: "Undo", shortcut: "⌘Z", action: keys(["ctrl"], "z") },
        { text: "Redo", shortcut: "⇧⌘Z", action: keys(["ctrl", "shift"], "z") },
        { separator: true },
        { text: "Cut", shortcut: "⌘X", action: keys(["ctrl"], "x") },
        { text: "Copy", shortcut: "⌘C", action: keys(["ctrl"], "c") },
        { text: "Paste", shortcut: "⌘V", action: keys(["ctrl"], "v") },
        { text: "Select All", shortcut: "⌘A", action: keys(["ctrl"], "a") }
    ]
    readonly property var emojiItem: { "text": "Emoji & Symbols", "shortcut": "⌃⌘Space", "action": () => Panels.toggle("emoji", Panels.screen) }
    readonly property var zoomItems: [
        { text: "Zoom In", shortcut: "⌘+", action: keys(["ctrl"], "plus") },
        { text: "Zoom Out", shortcut: "⌘−", action: keys(["ctrl"], "minus") },
        { text: "Actual Size", shortcut: "⌘0", action: keys(["ctrl"], "0") }
    ]
    readonly property var fullScreenItem: { "text": "Enter Full Screen", "shortcut": "⌃⌘F", "action": () => Hypr.toggleFullscreen() }

    readonly property var appMenuSets: ({
        "org.gnome.TextEditor": {
            titles: ["File", "Edit", "View"],
            menus: [
                [
                    { text: "New Tab", shortcut: "⌘T", action: keys(["ctrl"], "t") },
                    { text: "New Window", shortcut: "⌘N", action: keys(["ctrl"], "n") },
                    { text: "Open…", shortcut: "⌘O", action: keys(["ctrl"], "o") },
                    { separator: true },
                    { text: "Close Tab", shortcut: "⌘W", action: keys(["ctrl"], "w") },
                    { text: "Save", shortcut: "⌘S", action: keys(["ctrl"], "s") },
                    { text: "Save As…", shortcut: "⇧⌘S", action: keys(["ctrl", "shift"], "s") },
                    { separator: true },
                    { text: "Print…", shortcut: "⌘P", action: keys(["ctrl"], "p") }
                ],
                stdEdit.concat([
                    { separator: true },
                    { text: "Find…", shortcut: "⌘F", action: keys(["ctrl"], "f") },
                    { text: "Find and Replace…", action: keys(["ctrl"], "h") },
                    { text: "Go to Line…", shortcut: "⌘I", action: keys(["ctrl"], "i") },
                    { separator: true },
                    emojiItem
                ]),
                zoomItems.concat([{ separator: true }, fullScreenItem])
            ]
        },
        "firefox": {
            titles: ["File", "Edit", "View", "History", "Bookmarks"],
            menus: [
                [
                    { text: "New Tab", shortcut: "⌘T", action: keys(["ctrl"], "t") },
                    { text: "New Window", shortcut: "⌘N", action: keys(["ctrl"], "n") },
                    { text: "New Private Window", shortcut: "⇧⌘P", action: keys(["ctrl", "shift"], "p") },
                    { separator: true },
                    { text: "Open Location…", shortcut: "⌘L", action: keys(["ctrl"], "l") },
                    { text: "Open File…", shortcut: "⌘O", action: keys(["ctrl"], "o") },
                    { separator: true },
                    { text: "Close Tab", shortcut: "⌘W", action: keys(["ctrl"], "w") },
                    { text: "Save Page As…", shortcut: "⌘S", action: keys(["ctrl"], "s") },
                    { separator: true },
                    { text: "Print…", shortcut: "⌘P", action: keys(["ctrl"], "p") }
                ],
                stdEdit.concat([
                    { separator: true },
                    { text: "Find in Page…", shortcut: "⌘F", action: keys(["ctrl"], "f") },
                    { separator: true },
                    emojiItem
                ]),
                [
                    { text: "Reload Page", shortcut: "⌘R", action: keys(["ctrl"], "r") },
                    { separator: true }
                ].concat(zoomItems, [{ separator: true }, fullScreenItem]),
                [
                    { text: "Back", shortcut: "⌘[", action: keys(["alt"], "Left") },
                    { text: "Forward", shortcut: "⌘]", action: keys(["alt"], "Right") },
                    { text: "Home", action: keys(["alt"], "Home") },
                    { separator: true },
                    { text: "Reopen Closed Tab", shortcut: "⇧⌘T", action: keys(["ctrl", "shift"], "t") },
                    { text: "Show All History", shortcut: "⇧⌘H", action: keys(["ctrl", "shift"], "h") }
                ],
                [
                    { text: "Bookmark This Page", shortcut: "⌘D", action: keys(["ctrl"], "d") },
                    { text: "Show All Bookmarks", shortcut: "⇧⌘O", action: keys(["ctrl", "shift"], "o") }
                ]
            ]
        },
        "org.gnome.Ptyxis": {
            titles: ["Shell", "Edit", "View"],
            menus: [
                [
                    { text: "New Tab", shortcut: "⌘T", action: keys(["ctrl"], "t") },
                    { text: "New Window", shortcut: "⌘N", action: keys(["ctrl"], "n") },
                    { separator: true },
                    { text: "Close Tab", shortcut: "⌘W", action: keys(["ctrl"], "w") }
                ],
                [
                    { text: "Copy", shortcut: "⌘C", action: keys(["ctrl"], "c") },
                    { text: "Paste", shortcut: "⌘V", action: keys(["ctrl"], "v") },
                    { text: "Select All", shortcut: "⌘A", action: keys(["ctrl"], "a") },
                    { separator: true },
                    { text: "Find…", shortcut: "⌘F", action: keys(["ctrl"], "f") }
                ],
                zoomItems.concat([{ separator: true }, fullScreenItem])
            ]
        },
        "org.gnome.Calculator": {
            titles: ["Edit", "View"],
            menus: [
                [
                    { text: "Undo", shortcut: "⌘Z", action: keys(["ctrl"], "z") },
                    { separator: true },
                    { text: "Copy", shortcut: "⌘C", action: keys(["ctrl"], "c") },
                    { text: "Paste", shortcut: "⌘V", action: keys(["ctrl"], "v") }
                ],
                [
                    { text: "Basic", shortcut: "⌘B", action: keys(["ctrl"], "b") },
                    { text: "Advanced", shortcut: "⌘A", action: keys(["ctrl"], "a") },
                    { text: "Financial", shortcut: "⌘F", action: keys(["ctrl"], "f") },
                    { text: "Programming", shortcut: "⌘P", action: keys(["ctrl"], "p") },
                    { separator: true },
                    { text: "Keyboard Mode", shortcut: "⌘K", action: keys(["ctrl"], "k") }
                ]
            ]
        }
    })

    // Window menu, macOS Sequoia style: tiling, then the app's windows.
    readonly property var windowMenu: {
        const has = !!Hypr.activeClass;
        const tile = where => () => Hypr.tile(where);
        const items = [
            { text: "Minimize", shortcut: "⌘M", enabled: has, action: () => Hypr.minimizeActive() },
            { text: "Zoom", enabled: has, action: () => Hypr.zoom() },
            { text: "Fill", shortcut: "⌃⌥F", enabled: has, action: tile("fill") },
            { text: "Center", shortcut: "⌃⌥C", enabled: has, action: tile("center") },
            { separator: true },
            { text: "Move & Resize", enabled: has, submenu: [
                { header: true, text: "Halves" },
                { text: "Left", shortcut: "⌃⌥←", action: tile("left") },
                { text: "Right", shortcut: "⌃⌥→", action: tile("right") },
                { text: "Top", shortcut: "⌃⌥↑", action: tile("top") },
                { text: "Bottom", shortcut: "⌃⌥↓", action: tile("bottom") },
                { separator: true },
                { header: true, text: "Quarters" },
                { text: "Top Left", action: tile("top_left") },
                { text: "Top Right", action: tile("top_right") },
                { text: "Bottom Left", action: tile("bottom_left") },
                { text: "Bottom Right", action: tile("bottom_right") },
                { separator: true },
                { text: "Return to Previous Size", shortcut: "⌃⌥R", action: tile("restore") }
            ] },
            { text: "Float / Tile Window", shortcut: "⌥⌘T", enabled: has, action: () => Hypr.toggleFloat() },
            { separator: true },
            { text: "Bring All to Front", enabled: has, action: () => {
                const id = Apps.idForToplevel(Hypr.activeToplevel);
                for (const w of Apps.windowsFor(id)) w.activate();
                Hypr.activeToplevel?.activate();
            } }
        ];
        const wins = Apps.windowsFor(Apps.idForToplevel(Hypr.activeToplevel))
            .filter(w => !Hypr.isHidden(w));
        if (wins.length) {
            items.push({ separator: true });
            for (const w of wins)
                items.push({ text: w.title || appName, checkable: true, checked: w.activated, action: () => w.activate() });
        }
        return items;
    }

    function model(key) {
        if (key === "fox") return foxMenu;
        if (key === "app:name") return appNameMenu;
        if (!key.startsWith("app:")) return [];
        const i = parseInt(key.slice(4));
        if (filesActive) {
            // File, Edit, View, Go, Window, Help
            return [filesMenus[0], appMenus[1], filesMenus[2], filesMenus[3], windowMenu, appMenus[4]][i] ?? [];
        }
        if (appSet) return appSet.menus.concat([windowMenu, appMenus[4]])[i] ?? [];
        return appMenus[i] ?? [];
    }
}
