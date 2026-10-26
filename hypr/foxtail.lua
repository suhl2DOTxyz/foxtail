-- Foxtail OS: Hyprland configuration (Hyprland >= 0.55, Lua config).
--
-- Installed to /usr/share/foxtail/hypr/foxtail.lua and loaded from the
-- user's ~/.config/hypr/hyprland.lua, which can override anything after it.
--
-- The goal is macOS behaviour: floating windows that open centered, no
-- colored borders, big soft shadows, spring animations, and blur behind the
-- Foxtail shell surfaces.

local HOME = os.getenv("HOME") or ""

local function read_file(path)
    local ok, f = pcall(io.open, path, "r")
    if not ok or not f then return nil end
    local s = f:read("l")
    f:close()
    return s
end

-- "float" (macOS-like, default) or "tile"; set from System Settings.
local window_mode = read_file(HOME .. "/.config/foxtail/window-mode") or "float"

-- Keyboard layout chosen in the installer (also used by the login screen).
local function system_kb_layout()
    local f = io.open("/etc/X11/xorg.conf.d/00-keyboard.conf", "r")
    if not f then return "us" end
    local text = f:read("a")
    f:close()
    return text:match('XkbLayout"%s+"([^"]+)"') or "us"
end

---------------------------------------------------------------- monitors
-- Scale 1 by default: "auto" guesses 2x whenever a display reports no
-- physical size (VMs, many TVs). HiDPI users set e.g. scale = 2 in hyprland.lua.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

---------------------------------------------------------------- environment
hl.env("XCURSOR_THEME", "macOS")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "macOS")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("MOZ_ENABLE_WAYLAND", "1")

---------------------------------------------------------------- autostart
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("foxtail-shell")
    hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("foxtail-firstboot")
end)

---------------------------------------------------------------- look & feel
hl.config({
    general = {
        gaps_in = 6,
        gaps_out = 12,
        border_size = 0,
        resize_on_border = true,
        extend_border_grab_area = 12,
        layout = "dwindle",
    },

    decoration = {
        rounding = 16,
        rounding_power = 3,   -- squircle-ish corners, like macOS
        active_opacity = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled = true,
            range = 42,
            render_power = 3,
            offset = { 0, 14 },
            color = "rgba(00000050)",
            color_inactive = "rgba(00000028)",
        },

        blur = {
            enabled = true,
            size = 9,
            passes = 3,
            noise = 0.015,
            contrast = 1.0,
            brightness = 1.0,
            vibrancy = 0.25,
            vibrancy_darkness = 0.2,
            popups = true,
            new_optimizations = true,
            xray = false,
        },
    },

    animations = { enabled = true },

    input = {
        kb_layout = system_kb_layout(),
        follow_mouse = 2,         -- focus follows click, like macOS
        float_switch_override_focus = 0,
        sensitivity = 0,
        accel_profile = "adaptive",
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            clickfinger_behavior = true,
            scroll_factor = 0.6,
        },
    },

    dwindle = { preserve_split = true },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        focus_on_activate = true,
        animate_manual_resizes = false,
        animate_mouse_windowdragging = false,
        layers_hog_keyboard_focus = true,
        -- If the shell crashes while locked, foxtail-shell restarts it and it
        -- locks again; give it time before Hyprland shows its fallback screen.
        allow_session_lock_restore = true,
        lockdead_screen_delay = 6000,
    },

    cursor = { inactive_timeout = 0 },
    binds = { workspace_back_and_forth = false },
    ecosystem = { no_update_news = true, no_donation_nag = true },
})

-- Displays and keyboard as set in System Settings (written by the shell).
pcall(dofile, HOME .. "/.config/foxtail/hypr/generated.lua")

-- macOS-flavoured motion: windows "genie-pop" in on a spring, spaces slide.
hl.curve("macSpring", { type = "spring", mass = 1, stiffness = 260, dampening = 26 })
hl.curve("macEase", { type = "bezier", points = { { 0.25, 1 }, { 0.5, 1 } } })
hl.curve("macOut", { type = "bezier", points = { { 0.4, 0 }, { 1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 6, bezier = "macEase" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, spring = "macSpring", style = "popin 85%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "macOut", style = "popin 85%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, spring = "macSpring" })
hl.animation({ leaf = "fade", enabled = true, speed = 3, bezier = "macEase" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 3, bezier = "macEase", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 2, bezier = "macOut", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "macEase", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "macEase", style = "slidevert" })
hl.animation({ leaf = "border", enabled = false })

---------------------------------------------------------------- gestures
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "up", action = function() hl.dispatch(hl.dsp.global("foxtail:missionControl")) end })

---------------------------------------------------------------- layer rules
-- Blur behind Foxtail's glass. ignore_alpha keeps fully clear pixels (and
-- soft drop shadows) unblurred, so only the panels themselves frost.
for _, ns in ipairs({ "menubar", "dock", "popover", "banner", "osd", "launchpad" }) do
    hl.layer_rule({
        name = "foxtail-blur-" .. ns,
        match = { namespace = "^foxtail-" .. ns .. "$" },
        blur = true,
        blur_popups = true,
        ignore_alpha = 0.15,
    })
end
hl.layer_rule({ name = "foxtail-wallpaper-noanim", match = { namespace = "^foxtail-wallpaper$" }, no_anim = true })
hl.layer_rule({ name = "foxtail-popover-noanim", match = { namespace = "^foxtail-popover$" }, no_anim = true })
hl.layer_rule({ name = "foxtail-launchpad-anim", match = { namespace = "^foxtail-launchpad$" }, animation = "fade" })

---------------------------------------------------------------- window rules
if window_mode ~= "tile" then
    hl.window_rule({
        name = "foxtail-float-all",
        match = { class = ".*" },
        float = true,
        center = true,
    })
end

hl.window_rule({ name = "foxtail-no-maximize-requests", match = { class = ".*" }, suppress_event = "maximize" })

-- Keep floating windows inside the usable area: apps (and portal dialogs) that
-- ask for a huge default size would otherwise be centered under the menu bar.
hl.window_rule({
    name = "foxtail-fit-floating",
    match = { float = true },
    max_size = "monitor_w*0.92 monitor_h*0.84",
})

-- Foxtail's own windows (System Settings, About, Force Quit) are Quickshell
-- toplevels: always float, centered.
hl.window_rule({
    name = "foxtail-shell-windows",
    match = { class = "^(org.quickshell|quickshell)$" },
    float = true,
    center = true,
    rounding = 20,   -- matches Theme.windowRadius in the shell (Hyprland max is 20)
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

hl.window_rule({ name = "pip", match = { title = "^(Picture-in-Picture)$" }, float = true, pin = true })

---------------------------------------------------------------- keybinds
-- Super plays the role of ⌘, Ctrl the role of ⌃, Alt the role of ⌥.
--
-- Linux apps expect Ctrl shortcuts, so ⌘+key is translated into the
-- app's own shortcut (Ctrl+key). Terminals are special: Ctrl+C/Z/X reach
-- the running program as signals, and Ptyxis even passes Ctrl+Shift+C
-- through as ^C when nothing is selected. So in terminals ⌘C/⌘V use the
-- VTE copy/paste keys (Ctrl+Insert / Shift+Insert), a few ⌘ keys map to
-- the terminal's own Ctrl+Shift actions, and the rest do nothing.
local CMD = "SUPER"
local ipc = function(fn) return hl.dsp.exec_cmd("foxtail-ipc " .. fn) end

local TERMINALS = {
    ["org.gnome.Ptyxis"] = true, ["org.gnome.Console"] = true, ["kitty"] = true,
    ["com.mitchellh.ghostty"] = true, ["Alacritty"] = true, ["foot"] = true,
    ["org.wezfurlong.wezterm"] = true, ["org.kde.konsole"] = true,
}

local function in_terminal()
    local w = hl.get_active_window()
    return w ~= nil and TERMINALS[w.class] == true
end

-- Send a fixed key chord to the focused app.
local function send(mods, key)
    return function() hl.dispatch(hl.dsp.send_shortcut({ mods = mods, key = key })) end
end

local TERMINAL_KEYS = {
    C = { "CTRL", "Insert" }, X = { "CTRL", "Insert" }, V = { "SHIFT", "Insert" },
    A = { "CTRL SHIFT", "A" }, F = { "CTRL SHIFT", "F" }, N = { "CTRL SHIFT", "N" },
    T = { "CTRL SHIFT", "T" }, W = { "CTRL SHIFT", "W" },
    plus = { "CTRL", "plus" }, equal = { "CTRL", "plus" }, minus = { "CTRL", "minus" }, ["0"] = { "CTRL", "0" },
}

-- ⌘(+⇧)+key  ->  Ctrl(+Shift)+key in the focused app.
local function app_shortcut(key, shift)
    return function()
        if in_terminal() then
            local t = not shift and TERMINAL_KEYS[key]
            if t then hl.dispatch(hl.dsp.send_shortcut({ mods = t[1], key = t[2] })) end
            return
        end
        hl.dispatch(hl.dsp.send_shortcut({ mods = shift and "CTRL SHIFT" or "CTRL", key = key }))
    end
end

-- ⌘Q: quit the whole app - close every window of that app (same class,
-- whichever process opened it), like macOS. Apps
-- still get to ask about unsaved work; Force Quit (⌥⌘⎋) is the hard kill.
local function quit_app()
    local active = hl.get_active_window()
    if not active then return end
    for _, w in ipairs(hl.get_windows()) do
        if w.class == active.class then
            hl.dispatch(hl.dsp.window.close({ window = "address:" .. w.address }))
        end
    end
end

-- Edit, file and navigation shortcuts go to the app.
for _, key in ipairs({ "A", "B", "C", "D", "F", "G", "I", "K", "L", "N", "O", "P", "R",
                       "S", "T", "U", "V", "W", "X", "Y", "Z" }) do
    hl.bind(CMD .. " + " .. key, app_shortcut(key))
    hl.bind(CMD .. " + SHIFT + " .. key, app_shortcut(key, true))
end
for _, key in ipairs({ "comma", "period", "plus", "equal", "minus", "0", "slash", "return" }) do
    hl.bind(CMD .. " + " .. key, app_shortcut(key))
end
for i = 1, 9 do
    hl.bind(CMD .. " + " .. i, app_shortcut(tostring(i)))        -- tabs, like ⌘1-⌘9
end

-- macOS text navigation: ⌘←/→ line start/end, ⌘↑/↓ document start/end,
-- ⌥←/→ by word (⇧ variants select). ⌘[ / ⌘] go back/forward.
for _, sh in ipairs({ "", "SHIFT + " }) do
    local s = sh ~= "" and "SHIFT " or ""
    hl.bind(CMD .. " + " .. sh .. "left", send(s, "Home"))
    hl.bind(CMD .. " + " .. sh .. "right", send(s, "End"))
    hl.bind(CMD .. " + " .. sh .. "up", send("CTRL " .. s, "Home"))
    hl.bind(CMD .. " + " .. sh .. "down", send("CTRL " .. s, "End"))
    hl.bind("ALT + " .. sh .. "left", send("CTRL " .. s, "left"))
    hl.bind("ALT + " .. sh .. "right", send("CTRL " .. s, "right"))
end
hl.bind(CMD .. " + backspace", function()                 -- delete to line start
    hl.dispatch(hl.dsp.send_shortcut({ mods = "SHIFT", key = "Home" }))
    hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = "BackSpace" }))
end)
hl.bind("ALT + backspace", send("CTRL", "backspace"))
hl.bind(CMD .. " + bracketleft", send("ALT", "left"))
hl.bind(CMD .. " + bracketright", send("ALT", "right"))

-- Foxtail actions (macOS defaults where macOS has one).
hl.bind(CMD .. " + Q", quit_app, { desc = "Quit app" })
hl.bind(CMD .. " + H", hl.dsp.window.move({ workspace = "special:minimized", follow = false }), { desc = "Hide" })
hl.bind(CMD .. " + M", hl.dsp.window.move({ workspace = "special:minimized", follow = false }), { desc = "Minimize" })
hl.bind(CMD .. " + ALT + M", ipc("restoreAll"), { desc = "Restore minimized windows" })
hl.bind(CMD .. " + space", ipc("spotlight"), { desc = "Spotlight" })
hl.bind(CMD .. " + ALT + space", hl.dsp.exec_cmd("nautilus --new-window"), { desc = "Files" })
hl.bind("F4", ipc("launchpad"), { desc = "Launchpad" })
hl.bind(CMD .. " + ALT + L", ipc("launchpad"))
hl.bind(CMD .. " + ALT + C", ipc("controlCenter"), { desc = "Control Center" })
hl.bind(CMD .. " + ALT + N", ipc("notificationCenter"), { desc = "Notification Center" })
hl.bind("CTRL + " .. CMD .. " + Q", ipc("lock"), { desc = "Lock Screen" })
hl.bind("ALT + " .. CMD .. " + escape", ipc("forceQuit"), { desc = "Force Quit" })
hl.bind(CMD .. " + SHIFT + ALT + Q", ipc("power logout"), { desc = "Log Out" })
hl.bind("CTRL + " .. CMD .. " + F", hl.dsp.window.fullscreen(), { desc = "Full Screen" })
hl.bind(CMD .. " + ALT + T", hl.dsp.window.float({ action = "toggle" }), { desc = "Float / Tile" })
-- ⌘Tab app switcher: Tab steps through apps while ⌘ is held; letting go of
-- ⌘ switches. ⌘` cycles the windows of the current app. These go to the shell
-- as global shortcuts (one ordered socket, no process per key press).
local shell = function(name) return hl.dsp.global("foxtail:" .. name) end
hl.bind(CMD .. " + tab", shell("switcherNext"), { desc = "Switch apps" })
hl.bind(CMD .. " + SHIFT + tab", shell("switcherPrev"))
hl.bind(CMD .. " + Super_L", shell("switcherCommit"), { release = true, non_consuming = true })
hl.bind(CMD .. " + Super_R", shell("switcherCommit"), { release = true, non_consuming = true })
hl.bind(CMD .. " + grave", hl.dsp.window.cycle_next(), { desc = "Next window of app" })

-- Mission Control: F3, ⌃↑ or a three-finger swipe up.
hl.bind("F3", shell("missionControl"), { desc = "Mission Control" })
hl.bind("CTRL + up", shell("missionControl"))
hl.bind(CMD .. " + ALT + V", ipc("clipboard"), { desc = "Clipboard history" })

-- Input sources: ⌃Space switches keyboard layout when there is more than one.
if foxtail_layout_shortcut ~= false and (foxtail_layouts or ""):find(",") then
    hl.bind("CTRL + space", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"), { desc = "Next input source" })
end
hl.bind(CMD .. " + ALT + return", hl.dsp.exec_cmd("ptyxis --new-window"), { desc = "Terminal" })

hl.bind(CMD .. " + SHIFT + 3", hl.dsp.exec_cmd("foxtail-screenshot screen"), { desc = "Screenshot" })
hl.bind(CMD .. " + SHIFT + 4", hl.dsp.exec_cmd("foxtail-screenshot area"), { desc = "Screenshot area" })
hl.bind(CMD .. " + SHIFT + 5", ipc("screenshotToolbar"), { desc = "Screenshot and recording" })

-- Desktops: ⌃1-9 as on macOS, ⌃⌘←/→ for next/previous (plain ⌃←/→ stays
-- word-jump in apps). ⌃⇧1-9 moves the window there.
for i = 1, 9 do
    hl.bind("CTRL + " .. i, hl.dsp.focus({ workspace = i }))
    hl.bind("CTRL + SHIFT + " .. i, hl.dsp.window.move({ workspace = i }))
end
hl.bind("CTRL + " .. CMD .. " + left", hl.dsp.focus({ workspace = "e-1" }))
hl.bind("CTRL + " .. CMD .. " + right", hl.dsp.focus({ workspace = "e+1" }))

hl.bind(CMD .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(CMD .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", ipc("volumeUp"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", ipc("volumeDown"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", ipc("volumeMute"), { locked = true })
hl.bind("XF86MonBrightnessUp", ipc("brightnessUp"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", ipc("brightnessDown"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
