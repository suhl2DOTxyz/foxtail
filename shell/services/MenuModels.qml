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
        if (Hypr.activeClass === "org.gnome.NautilusPreviewer") return "Files";   // Quick Look
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
    readonly property var menuTitles: (filesActive ? ["File", "Edit", "View", "Go", "Window", "Help"]
                                    : appSet ? appSet.titles.concat(["Window", "Help"])
                                    : ["File", "Edit", "View", "Window", "Help"]).map(t => I18n.tr(t))

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
            { text: I18n.tr("New Files Window"), shortcut: "⌘N", action: filesWindow ? keys(["ctrl"], "n") : run("nautilus --new-window") },
            { text: I18n.tr("New Folder"), shortcut: "⇧⌘N", action: filesWindow ? keys(["ctrl", "shift"], "n") : () => Panels.desktopNewFolder() },
            { text: I18n.tr("New Tab"), shortcut: "⌘T", enabled: filesWindow, action: keys(["ctrl"], "t") },
            { text: I18n.tr("Open"), shortcut: "⌘↓", enabled: filesWindow, action: keys([], "Return") },
            { separator: true },
            { text: I18n.tr("Close Window"), shortcut: "⌘W", enabled: filesWindow, action: keys(["ctrl"], "w") },
            { separator: true },
            { text: I18n.tr("Get Info"), shortcut: "⌘I", enabled: filesWindow, action: keys(["alt"], "Return") },
            { text: I18n.tr("Rename"), enabled: filesWindow, action: keys([], "F2") },
            { separator: true },
            { text: I18n.tr("Move to Trash"), shortcut: "⌘⌫", enabled: filesWindow, action: keys([], "Delete") },
            { separator: true },
            { text: I18n.tr("Find"), shortcut: "⌘F", enabled: filesWindow, action: keys(["ctrl"], "f") }
        ],
        null,   // Edit (shared)
        // View
        [
            { text: I18n.tr("as Icons"), shortcut: "⌘1", enabled: filesWindow, action: keys(["ctrl"], "1") },
            { text: I18n.tr("as List"), shortcut: "⌘2", enabled: filesWindow, action: keys(["ctrl"], "2") },
            { separator: true },
            { text: I18n.tr("Show Hidden Files"), shortcut: "⇧⌘.", enabled: filesWindow, action: keys(["ctrl"], "h") },
            { separator: true },
            { text: I18n.tr("Zoom In"), shortcut: "⌘+", enabled: filesWindow, action: keys(["ctrl"], "plus") },
            { text: I18n.tr("Zoom Out"), shortcut: "⌘−", enabled: filesWindow, action: keys(["ctrl"], "minus") }
        ],
        // Go
        [
            { text: I18n.tr("Back"), shortcut: "⌘[", enabled: filesWindow, action: keys(["alt"], "Left") },
            { text: I18n.tr("Forward"), shortcut: "⌘]", enabled: filesWindow, action: keys(["alt"], "Right") },
            { text: I18n.tr("Enclosing Folder"), shortcut: "⌘↑", enabled: filesWindow, action: keys(["alt"], "Up") },
            { separator: true },
            { text: I18n.tr("Recents"), icon: "clock", action: goTo("recent:///") },
            { text: I18n.tr("Documents"), icon: "folder", shortcut: "⇧⌘O", action: goTo("xdg:DOCUMENTS") },
            { text: I18n.tr("Desktop"), icon: "display", shortcut: "⇧⌘D", action: goTo("xdg:DESKTOP") },
            { text: I18n.tr("Downloads"), icon: "arrow-right-circle", shortcut: "⌥⌘L", action: goTo("xdg:DOWNLOAD") },
            { text: I18n.tr("Home"), icon: "person", shortcut: "⇧⌘H", action: goTo(Quickshell.env("HOME")) },
            { text: I18n.tr("Network"), icon: "globe", action: goTo("network:///") },
            { text: I18n.tr("Trash"), icon: "trash", action: goTo("trash:///") },
            { separator: true },
            { text: I18n.tr("Go to Folder…"), shortcut: "⇧⌘G", action: filesWindow ? keys(["ctrl"], "l") : goTo(Quickshell.env("HOME")) }
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
        { text: I18n.tr("About This Foxtail"), icon: "info", action: () => Panels.about = true },
        { separator: true },
        { text: I18n.tr("System Settings…"), icon: "gear", action: () => Panels.openSettings() },
        { text: Updates.count ? I18n.tr("Software Update… (%1)").arg(Updates.count) : I18n.tr("Software Update…"), icon: "restart",
          action: () => { Panels.openSettings("updates"); Updates.check(); } },
        { text: I18n.tr("App Store…"), icon: "grid", action: run("gnome-software") },
        { separator: true },
        { text: I18n.tr("Recent Items"), icon: "clock", submenu: recentItems },
        { separator: true },
        { text: I18n.tr("Force Quit…"), icon: "xmark", shortcut: "⌥⌘⎋", action: () => Panels.forceQuit = true },
        { separator: true },
        { text: I18n.tr("Sleep"), icon: "moon", action: run("systemctl suspend") },
        { text: I18n.tr("Restart…"), icon: "restart", action: () => Panels.confirm = "restart" },
        { text: I18n.tr("Shut Down…"), icon: "power", action: () => Panels.confirm = "shutdown" },
        { separator: true },
        { text: I18n.tr("Lock Screen"), icon: "lock", shortcut: "⌃⌘Q", action: () => Lock.lock() },
        { text: I18n.tr("Log Out %1…").arg(SystemInfo.fullName || SystemInfo.user), icon: "logout", shortcut: "⌥⇧⌘Q", action: () => Panels.confirm = "logout" }
    ]

    // Apple menu ▸ Recent Items: the apps used most recently this session.
    readonly property var recentItems: {
        const apps = Apps.mruApps.filter(id => Apps.entry(id)).slice(0, 10);
        if (!apps.length) return [{ text: I18n.tr("No Recent Items"), enabled: false }];
        return [{ header: true, text: I18n.tr("Applications") }].concat(apps.map(id => ({
            text: Apps.nameFor(id), action: () => Apps.focus(id)
        })));
    }

    readonly property var appNameMenu: [
        { text: I18n.tr("Settings…"), shortcut: "⌘,", action: keys(["ctrl"], "comma") },
        { separator: true },
        { text: I18n.tr("Hide %1").arg(appName), shortcut: "⌘H", enabled: !!Hypr.activeClass,
          action: () => Hypr.hideActiveApp() },
        { text: I18n.tr("Hide Others"), shortcut: "⌥⌘H", enabled: !!Hypr.activeClass,
          action: () => Hypr.hideOthers() },
        { text: I18n.tr("Show All"), enabled: Hypr.hidden.length > 0, action: () => Hypr.showAll() },
        { separator: true },
        { text: I18n.tr("Quit %1").arg(appName), shortcut: "⌘Q", enabled: !!Hypr.activeClass, action: () => Hypr.quitActiveApp() }
    ]

    readonly property var appMenus: [
        // File
        [
            { text: I18n.tr("New Window"), shortcut: "⌘N", action: keys(["ctrl"], "n") },
            { text: I18n.tr("New Tab"), shortcut: "⌘T", action: keys(["ctrl"], "t") },
            { text: I18n.tr("Open…"), shortcut: "⌘O", action: keys(["ctrl"], "o") },
            { separator: true },
            { text: I18n.tr("Close Window"), shortcut: "⌘W", action: keys(["ctrl"], "w") },
            { text: I18n.tr("Save"), shortcut: "⌘S", action: keys(["ctrl"], "s") },
            { text: I18n.tr("Save As…"), shortcut: "⇧⌘S", action: keys(["ctrl", "shift"], "s") },
            { separator: true },
            { text: I18n.tr("Print…"), shortcut: "⌘P", action: keys(["ctrl"], "p") }
        ],
        // Edit
        [
            { text: I18n.tr("Undo"), shortcut: "⌘Z", action: keys(["ctrl"], "z") },
            { text: I18n.tr("Redo"), shortcut: "⇧⌘Z", action: keys(["ctrl", "shift"], "z") },
            { separator: true },
            { text: I18n.tr("Cut"), shortcut: "⌘X", action: keys(["ctrl"], "x") },
            { text: I18n.tr("Copy"), shortcut: "⌘C", action: keys(["ctrl"], "c") },
            { text: I18n.tr("Paste"), shortcut: "⌘V", action: keys(["ctrl"], "v") },
            { text: I18n.tr("Select All"), shortcut: "⌘A", action: keys(["ctrl"], "a") },
            { separator: true },
            { text: I18n.tr("Find…"), shortcut: "⌘F", action: keys(["ctrl"], "f") },
            { separator: true },
            { text: I18n.tr("Emoji & Symbols"), shortcut: "⌃⌘Space", action: () => Panels.toggle("emoji", Panels.screen) }
        ],
        // View
        [
            { text: I18n.tr("Enter Full Screen"), shortcut: "⌃⌘F", action: () => Hypr.toggleFullscreen() },
            { separator: true },
            { text: I18n.tr("Zoom In"), shortcut: "⌘+", action: keys(["ctrl"], "plus") },
            { text: I18n.tr("Zoom Out"), shortcut: "⌘−", action: keys(["ctrl"], "minus") },
            { text: I18n.tr("Actual Size"), shortcut: "⌘0", action: keys(["ctrl"], "0") }
        ],
        // Window
        windowMenu,
        // Help
        [
            { header: true, text: I18n.tr("Foxtail Help") },
            { text: I18n.tr("Keyboard Shortcuts"), action: () => Panels.openSettings("keyboard") },
            { text: I18n.tr("Foxtail Guide"), action: run("xdg-open https://github.com/suhl2DOTxyz/foxtail/tree/main/docs") },
            { separator: true },
            { text: I18n.tr("Report a Problem…"), action: run("foxtail-report") },
            { text: I18n.tr("Foxtail Tips"), action: () => Panels.about = true }
        ]
    ]

    readonly property var stdEdit: [
        { text: I18n.tr("Undo"), shortcut: "⌘Z", action: keys(["ctrl"], "z") },
        { text: I18n.tr("Redo"), shortcut: "⇧⌘Z", action: keys(["ctrl", "shift"], "z") },
        { separator: true },
        { text: I18n.tr("Cut"), shortcut: "⌘X", action: keys(["ctrl"], "x") },
        { text: I18n.tr("Copy"), shortcut: "⌘C", action: keys(["ctrl"], "c") },
        { text: I18n.tr("Paste"), shortcut: "⌘V", action: keys(["ctrl"], "v") },
        { text: I18n.tr("Select All"), shortcut: "⌘A", action: keys(["ctrl"], "a") }
    ]
    readonly property var emojiItem: { "text": I18n.tr("Emoji & Symbols"), "shortcut": "⌃⌘Space", "action": () => Panels.toggle("emoji", Panels.screen) }
    readonly property var zoomItems: [
        { text: I18n.tr("Zoom In"), shortcut: "⌘+", action: keys(["ctrl"], "plus") },
        { text: I18n.tr("Zoom Out"), shortcut: "⌘−", action: keys(["ctrl"], "minus") },
        { text: I18n.tr("Actual Size"), shortcut: "⌘0", action: keys(["ctrl"], "0") }
    ]
    readonly property var fullScreenItem: { "text": I18n.tr("Enter Full Screen"), "shortcut": "⌃⌘F", "action": () => Hypr.toggleFullscreen() }

    readonly property var appMenuSets: ({
        "org.gnome.TextEditor": {
            titles: ["File", "Edit", "View"],
            menus: [
                [
                    { text: I18n.tr("New Tab"), shortcut: "⌘T", action: keys(["ctrl"], "t") },
                    { text: I18n.tr("New Window"), shortcut: "⌘N", action: keys(["ctrl"], "n") },
                    { text: I18n.tr("Open…"), shortcut: "⌘O", action: keys(["ctrl"], "o") },
                    { separator: true },
                    { text: I18n.tr("Close Tab"), shortcut: "⌘W", action: keys(["ctrl"], "w") },
                    { text: I18n.tr("Save"), shortcut: "⌘S", action: keys(["ctrl"], "s") },
                    { text: I18n.tr("Save As…"), shortcut: "⇧⌘S", action: keys(["ctrl", "shift"], "s") },
                    { separator: true },
                    { text: I18n.tr("Print…"), shortcut: "⌘P", action: keys(["ctrl"], "p") }
                ],
                stdEdit.concat([
                    { separator: true },
                    { text: I18n.tr("Find…"), shortcut: "⌘F", action: keys(["ctrl"], "f") },
                    { text: I18n.tr("Find and Replace…"), action: keys(["ctrl"], "h") },
                    { text: I18n.tr("Go to Line…"), shortcut: "⌘I", action: keys(["ctrl"], "i") },
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
                    { text: I18n.tr("New Tab"), shortcut: "⌘T", action: keys(["ctrl"], "t") },
                    { text: I18n.tr("New Window"), shortcut: "⌘N", action: keys(["ctrl"], "n") },
                    { text: I18n.tr("New Private Window"), shortcut: "⇧⌘P", action: keys(["ctrl", "shift"], "p") },
                    { separator: true },
                    { text: I18n.tr("Open Location…"), shortcut: "⌘L", action: keys(["ctrl"], "l") },
                    { text: I18n.tr("Open File…"), shortcut: "⌘O", action: keys(["ctrl"], "o") },
                    { separator: true },
                    { text: I18n.tr("Close Tab"), shortcut: "⌘W", action: keys(["ctrl"], "w") },
                    { text: I18n.tr("Save Page As…"), shortcut: "⌘S", action: keys(["ctrl"], "s") },
                    { separator: true },
                    { text: I18n.tr("Print…"), shortcut: "⌘P", action: keys(["ctrl"], "p") }
                ],
                stdEdit.concat([
                    { separator: true },
                    { text: I18n.tr("Find in Page…"), shortcut: "⌘F", action: keys(["ctrl"], "f") },
                    { separator: true },
                    emojiItem
                ]),
                [
                    { text: I18n.tr("Reload Page"), shortcut: "⌘R", action: keys(["ctrl"], "r") },
                    { separator: true }
                ].concat(zoomItems, [{ separator: true }, fullScreenItem]),
                [
                    { text: I18n.tr("Back"), shortcut: "⌘[", action: keys(["alt"], "Left") },
                    { text: I18n.tr("Forward"), shortcut: "⌘]", action: keys(["alt"], "Right") },
                    { text: I18n.tr("Home"), action: keys(["alt"], "Home") },
                    { separator: true },
                    { text: I18n.tr("Reopen Closed Tab"), shortcut: "⇧⌘T", action: keys(["ctrl", "shift"], "t") },
                    { text: I18n.tr("Show All History"), shortcut: "⇧⌘H", action: keys(["ctrl", "shift"], "h") }
                ],
                [
                    { text: I18n.tr("Bookmark This Page"), shortcut: "⌘D", action: keys(["ctrl"], "d") },
                    { text: I18n.tr("Show All Bookmarks"), shortcut: "⇧⌘O", action: keys(["ctrl", "shift"], "o") }
                ]
            ]
        },
        // Foxtail's Terminal (bin/foxtail-terminal), laid out like macOS's.
        "org.foxtail.Terminal": {
            titles: ["Shell", "Edit", "View"],
            menus: [
                [
                    { text: I18n.tr("New Window"), shortcut: "⌘N", action: keys(["ctrl"], "n") },
                    { text: I18n.tr("New Tab"), shortcut: "⌘T", action: keys(["ctrl"], "t") },
                    { separator: true },
                    { text: I18n.tr("Close Tab"), shortcut: "⌘W", action: keys(["ctrl"], "w") }
                ],
                [
                    { text: I18n.tr("Copy"), shortcut: "⌘C", action: keys(["ctrl"], "c") },
                    { text: I18n.tr("Paste"), shortcut: "⌘V", action: keys(["ctrl"], "v") },
                    { text: I18n.tr("Select All"), shortcut: "⌘A", action: keys(["ctrl"], "a") },
                    { separator: true },
                    { text: I18n.tr("Find…"), shortcut: "⌘F", action: keys(["ctrl"], "f") },
                    { text: I18n.tr("Clear to Start"), shortcut: "⌘K", action: keys(["ctrl"], "k") }
                ],
                zoomItems.concat([
                    { separator: true },
                    { text: I18n.tr("Profile"), submenu: ["Basic", "Clear Dark", "Clear Light", "Grass", "Homebrew", "Man Page",
                                                         "Novel", "Ocean", "Pro", "Red Sands", "Silver Aerogel"].map(n => ({
                        text: n,
                        action: () => Quickshell.execDetached(["gapplication", "action", "org.foxtail.Terminal", "profile", `'${n}'`])
                    })) },
                    { separator: true },
                    fullScreenItem
                ])
            ]
        },
        "org.gnome.Ptyxis": {
            titles: ["Shell", "Edit", "View"],
            menus: [
                [
                    { text: I18n.tr("New Tab"), shortcut: "⌘T", action: keys(["ctrl"], "t") },
                    { text: I18n.tr("New Window"), shortcut: "⌘N", action: keys(["ctrl"], "n") },
                    { separator: true },
                    { text: I18n.tr("Close Tab"), shortcut: "⌘W", action: keys(["ctrl"], "w") }
                ],
                [
                    { text: I18n.tr("Copy"), shortcut: "⌘C", action: keys(["ctrl"], "c") },
                    { text: I18n.tr("Paste"), shortcut: "⌘V", action: keys(["ctrl"], "v") },
                    { text: I18n.tr("Select All"), shortcut: "⌘A", action: keys(["ctrl"], "a") },
                    { separator: true },
                    { text: I18n.tr("Find…"), shortcut: "⌘F", action: keys(["ctrl"], "f") }
                ],
                zoomItems.concat([{ separator: true }, fullScreenItem])
            ]
        },
        "org.gnome.Calculator": {
            titles: ["Edit", "View"],
            menus: [
                [
                    { text: I18n.tr("Undo"), shortcut: "⌘Z", action: keys(["ctrl"], "z") },
                    { separator: true },
                    { text: I18n.tr("Copy"), shortcut: "⌘C", action: keys(["ctrl"], "c") },
                    { text: I18n.tr("Paste"), shortcut: "⌘V", action: keys(["ctrl"], "v") }
                ],
                [
                    { text: I18n.tr("Basic"), shortcut: "⌘B", action: keys(["ctrl"], "b") },
                    { text: I18n.tr("Advanced"), shortcut: "⌘A", action: keys(["ctrl"], "a") },
                    { text: I18n.tr("Financial"), shortcut: "⌘F", action: keys(["ctrl"], "f") },
                    { text: I18n.tr("Programming"), shortcut: "⌘P", action: keys(["ctrl"], "p") },
                    { separator: true },
                    { text: I18n.tr("Keyboard Mode"), shortcut: "⌘K", action: keys(["ctrl"], "k") }
                ]
            ]
        }
    })

    // Window menu, macOS Sequoia style: tiling, then the app's windows.
    readonly property var windowMenu: {
        const has = !!Hypr.activeClass;
        const tile = where => () => Hypr.tile(where);
        const items = [
            { text: I18n.tr("Minimize"), shortcut: "⌘M", enabled: has, action: () => Hypr.minimizeActive() },
            { text: I18n.tr("Zoom"), enabled: has, action: () => Hypr.zoom() },
            { text: I18n.tr("Fill"), shortcut: "⌃⌥F", enabled: has, action: tile("fill") },
            { text: I18n.tr("Center"), shortcut: "⌃⌥C", enabled: has, action: tile("center") },
            { separator: true },
            { text: I18n.tr("Move & Resize"), enabled: has, submenu: [
                { header: true, text: I18n.tr("Halves") },
                { text: I18n.tr("Left"), shortcut: "⌃⌥←", action: tile("left") },
                { text: I18n.tr("Right"), shortcut: "⌃⌥→", action: tile("right") },
                { text: I18n.tr("Top"), shortcut: "⌃⌥↑", action: tile("top") },
                { text: I18n.tr("Bottom"), shortcut: "⌃⌥↓", action: tile("bottom") },
                { separator: true },
                { header: true, text: I18n.tr("Quarters") },
                { text: I18n.tr("Top Left"), action: tile("top_left") },
                { text: I18n.tr("Top Right"), action: tile("top_right") },
                { text: I18n.tr("Bottom Left"), action: tile("bottom_left") },
                { text: I18n.tr("Bottom Right"), action: tile("bottom_right") },
                { separator: true },
                { text: I18n.tr("Return to Previous Size"), shortcut: "⌃⌥R", action: tile("restore") }
            ] },
            { text: I18n.tr("Float / Tile Window"), shortcut: "⌥⌘T", enabled: has, action: () => Hypr.toggleFloat() },
            { separator: true },
            { text: I18n.tr("Bring All to Front"), enabled: has, action: () => {
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
