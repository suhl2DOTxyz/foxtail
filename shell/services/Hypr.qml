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
    function sendKeys(mods, key) {
        const args = ["wtype"];
        for (const m of mods) args.push("-M", m);
        args.push("-k", key);
        for (const m of mods) args.push("-m", m);
        // Give the compositor a beat to hand focus back to the app after the menu closes.
        Quickshell.execDetached(["sh", "-c", "sleep 0.08; exec \"$@\"", "wtype"].concat(args));
    }
}
