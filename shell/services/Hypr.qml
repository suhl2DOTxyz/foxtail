pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Thin wrapper over Hyprland IPC. Hyprland >= 0.55 takes Lua dispatcher
// expressions (hl.dsp.*), so every call here is a Lua snippet.
Singleton {
    id: root

    // The Wayland toplevel is always current; Hyprland's IPC object can lag.
    readonly property var activeToplevel: ToplevelManager.activeToplevel
    readonly property string activeClass: activeToplevel?.appId ?? ""
    readonly property string activeTitle: activeToplevel?.title ?? ""

    function dispatch(lua) {
        Hyprland.dispatch(lua);
    }

    function closeActive() { dispatch("hl.dsp.window.close()"); }

    // ---- minimize (windows live on the hidden "special:minimized" workspace) ----
    readonly property var minimized: Hyprland.toplevels.values
        .filter(t => t.workspace?.name === "special:minimized")

    // The yellow button in apps asks the compositor to minimize; Hyprland
    // only reports the request, so the shell does the minimizing.
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "minimized") return;
            const [addr, on] = event.data.split(",");
            if (on === "1")
                root.dispatch(`hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = "address:0x${addr.replace(/^0x/, "")}" })`);
        }
    }

    function minimizeActive() {
        dispatch("hl.dsp.window.move({ workspace = \"special:minimized\", follow = false })");
    }
    function restore(t) {
        const a = "address:" + (t.address.startsWith("0x") ? "" : "0x") + t.address;
        dispatch(`hl.dsp.window.move({ workspace = "e+0", window = "${a}" })`);
        dispatch(`hl.dsp.focus({ window = "${a}" })`);
    }
    function restoreAll() {
        for (const t of minimized.slice()) restore(t);
    }
    function isMinimized(wayland) {
        return minimized.some(t => t.wayland === wayland);
    }
    function hyprFor(wayland) {
        return Hyprland.toplevels.values.find(t => t.wayland === wayland) ?? null;
    }
    function toggleFullscreen() { dispatch("hl.dsp.window.fullscreen()"); }
    function toggleFloat() { dispatch("hl.dsp.window.float({ action = \"toggle\" })"); }
    function workspace(n) { dispatch(`hl.dsp.focus({ workspace = ${n} })`); }
    function exit() { dispatch("hl.dsp.exit()"); }

    // Send a key chord to the focused app (used by the global menu bar items).
    // Terminals take Ctrl+Shift for copy/paste/tabs; plain Ctrl+C would
    // interrupt the running program. Mirrors TERMINALS in hypr/foxtail.lua.
    readonly property var terminals: ["org.gnome.Ptyxis", "org.gnome.Console", "kitty",
                                      "com.mitchellh.ghostty", "Alacritty", "foot",
                                      "org.wezfurlong.wezterm", "org.kde.konsole"]

    // ⌘Q: close every window of the focused app, like macOS's Quit.
    function quitActiveApp() {
        const cls = Hyprland.activeToplevel?.lastIpcObject?.class;
        if (!cls) { closeActive(); return; }
        for (const t of Hyprland.toplevels.values)
            if (t.lastIpcObject?.class === cls)
                dispatch(`hl.dsp.window.close({ window = "address:${t.address.startsWith("0x") ? "" : "0x"}${t.address}" })`);
    }

    // Same terminal mapping as TERMINAL_KEYS in hypr/foxtail.lua.
    readonly property var terminalKeys: ({
        c: [["ctrl"], "Insert"], x: [["ctrl"], "Insert"], v: [["shift"], "Insert"],
        a: [["ctrl", "shift"], "a"], f: [["ctrl", "shift"], "f"], n: [["ctrl", "shift"], "n"],
        t: [["ctrl", "shift"], "t"], w: [["ctrl", "shift"], "w"],
        plus: [["ctrl"], "plus"], minus: [["ctrl"], "minus"], "0": [["ctrl"], "0"]
    })

    function sendKeys(mods, key) {
        if (terminals.indexOf(activeClass) >= 0) {
            const t = mods.length === 1 && mods[0] === "ctrl" ? terminalKeys[key] : null;
            if (!t) return;          // e.g. Undo would send ^Z (suspend) to the shell
            mods = t[0];
            key = t[1];
        }
        const args = ["wtype"];
        for (const m of mods) args.push("-M", m);
        args.push("-k", key);
        for (const m of mods) args.push("-m", m);
        // Give the compositor a beat to hand focus back to the app after the menu closes.
        Quickshell.execDetached(["sh", "-c", "sleep 0.08; exec \"$@\"", "wtype"].concat(args));
    }
}
