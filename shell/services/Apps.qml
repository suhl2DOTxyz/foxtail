pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Wayland

// Applications: desktop entries, what is pinned in the Dock, what is running.
Singleton {
    id: root

    // Developer/terminal tools that clutter Launchpad and Spotlight.
    readonly property var hidden: ["qvidcap", "qv4l2", "lstopo", "htop", "vim", "gvim",
                                   "gnome-system-monitor-kde", "avahi-discover", "bssh", "bvnc",
                                   "cmake-gui", "nm-connection-editor", "xgps", "xgpsspeed"]

    readonly property var all: DesktopEntries.applications.values
        .filter(e => !e.noDisplay && hidden.indexOf(e.id) < 0)
        .sort((a, b) => a.name.localeCompare(b.name))

    // App windows only: dialogs (windows with a parent) and portal helpers
    // such as the GTK file chooser never get their own Dock icon, as on macOS.
    readonly property var helperIds: ["xdg-desktop-portal-gtk", "xdg-desktop-portal-gnome",
                                      "xdg-desktop-portal-hyprland", "hyprpolkitagent",
                                      "org.freedesktop.impl.portal.desktop.gtk"]
    readonly property var toplevels: ToplevelManager.toplevels.values
        .filter(t => !t.parent && helperIds.indexOf(t.appId) < 0)

    // id (lowercased) -> DesktopEntry. Bindings that go through entry() depend
    // on this property, so names and icons update once Quickshell finishes
    // scanning .desktop files (the scan completes after the shell starts).
    readonly property var byId: {
        const m = {};
        for (const e of DesktopEntries.applications.values) m[e.id.toLowerCase()] = e;
        return m;
    }

    function entry(id) {
        if (!id) return null;
        // Exact id match first; heuristicLookup is fuzzy and can pick a sibling
        // (e.g. foxtail-settings for foxtail-installer).
        return byId[id.toLowerCase()] ?? DesktopEntries.heuristicLookup(id);
    }

    function entryForToplevel(t) {
        if (!t) return null;
        if (isShellWindow(t)) {
            if (t.title === "System Settings") return entry("foxtail-settings");
            if (t.title === "Install Foxtail") return entry("foxtail-installer");
            return null;
        }
        return entry(t.appId);
    }

    // Foxtail's own windows (Settings, About, ...) are Quickshell toplevels.
    function isShellWindow(t) {
        return t?.appId === "org.quickshell" || t?.appId === "quickshell";
    }

    function idForToplevel(t) {
        const e = entryForToplevel(t);
        if (e) return e.id;
        // Shell windows without a desktop entry (About, Force Quit) stay out of the Dock.
        return isShellWindow(t) ? "" : (t?.appId ?? "");
    }

    function windowsFor(id) {
        return toplevels.filter(t => idForToplevel(t) === id);
    }

    function isRunning(id) {
        return windowsFor(id).length > 0;
    }

    // Running apps that are not pinned, for the right side of the Dock.
    readonly property var unpinnedRunning: {
        const seen = {};
        const out = [];
        for (const t of toplevels) {
            const id = idForToplevel(t);
            if (!id || seen[id] || Settings.pinnedApps.indexOf(id) >= 0) continue;
            seen[id] = true;
            out.push(id);
        }
        return out;
    }

    function iconFor(id) {
        const e = entry(id);
        const icon = e?.icon ?? id;
        if (icon.startsWith("/")) return "file://" + icon;
        return Quickshell.iconPath(icon, "application-x-executable");
    }

    function nameFor(id) {
        const e = entry(id);
        return e?.name ?? id;
    }

    // Click on a Dock icon: focus (cycle) running windows, or launch.
    function activate(id) {
        const wins = windowsFor(id);
        if (wins.length === 0) {
            launch(id);
            return false;
        }
        const active = wins.findIndex(w => w.activated);
        const next = wins[(active + 1) % wins.length];
        next.activate();
        return true;
    }

    function launch(id) {
        if (id === "foxtail-settings") {
            Panels.openSettings();
            return;
        }
        const e = entry(id);
        if (e) e.execute();
    }

    function quit(id) {
        for (const w of windowsFor(id)) w.close();
    }

    function pin(id) {
        if (Settings.pinnedApps.indexOf(id) < 0)
            Settings.pinnedApps = Settings.pinnedApps.concat([id]);
    }

    function unpin(id) {
        Settings.pinnedApps = Settings.pinnedApps.filter(p => p !== id);
    }

    // Spotlight-style fuzzy-ish matching: prefix > word prefix > substring > keywords.
    function search(query) {
        const q = query.trim().toLowerCase();
        if (!q) return [];
        const scored = [];
        for (const e of all) {
            const name = e.name.toLowerCase();
            let s = 0;
            if (name.startsWith(q)) s = 100;
            else if (name.split(/[\s\-_.]/).some(w => w.startsWith(q))) s = 80;
            else if (name.indexOf(q) >= 0) s = 60;
            else if ((e.genericName ?? "").toLowerCase().indexOf(q) >= 0) s = 40;
            else if (String(e.keywords ?? "").toLowerCase().indexOf(q) >= 0) s = 30;
            else if ((e.comment ?? "").toLowerCase().indexOf(q) >= 0) s = 15;
            if (s > 0) scored.push({ entry: e, score: s - name.length * 0.1 });
        }
        return scored.sort((a, b) => b.score - a.score).map(x => x.entry);
    }
}
