-- Foxtail OS: Hyprland configuration (Hyprland >= 0.55, Lua config).
--
-- Installed to /usr/share/foxtail/hypr/foxtail.lua and loaded from the
-- user's ~/.config/hypr/hyprland.lua, which can override anything after it.
--
-- The goal is macOS behaviour: floating windows that open centered, no
-- colored borders, big soft shadows, spring animations, and blur behind the
-- Foxtail shell surfaces.

local HOME = os.getenv("HOME") or ""

-- Window positions and sizes come as { x, y } or { [1], [2] }.
local function xy(v) return v.x or v[1], v.y or v[2] end

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
    hl.exec_cmd("foxtail-autostart")     -- Login Items
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
        -- Dragged windows snap to screen edges and to each other.
        snap = { enabled = true, window_gap = 10, monitor_gap = 10 },
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
        -- Off: clicking a window must take keyboard focus back from the desktop
        -- (an on-demand layer). Spotlight and dialogs grab focus exclusively.
        layers_hog_keyboard_focus = false,
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
-- Off in System Settings ▸ Trackpad sets foxtail_gestures = false (generated.lua).
if foxtail_gestures ~= false then
    hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
    hl.gesture({ fingers = 3, direction = "up", action = function() hl.dispatch(hl.dsp.global("foxtail:missionControl")) end })
end

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
hl.layer_rule({ name = "foxtail-wallpaper-noanim", match = { namespace = "^foxtail-(wallpaper|desktop)$" }, no_anim = true })
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

-- Maximize requests (the green button, double-clicking a title bar) zoom
-- the window to fill the screen between the menu bar and the Dock, like
-- macOS's Zoom; doing it again puts it back.

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
-- Files behaves like Finder: a few ⌘ shortcuts mean something else there.
local FILES = "org.gnome.Nautilus"
local function in_files()
    local w = hl.get_active_window()
    return w ~= nil and w.class == FILES
end
local function shortcut_now(mods, key) hl.dispatch(hl.dsp.send_shortcut({ mods = mods, key = key })) end
-- Finder's Go menu: type a folder into Files' location bar.
local function go_to(dir_cmd)
    shortcut_now("CTRL", "L")
    hl.exec_cmd('sleep 0.25; wtype -- "$(' .. dir_cmd .. ')"; wtype -k Return')
end
local FILES_KEYS = {
    I = function() shortcut_now("ALT", "Return") end,               -- ⌘I  Get Info
    ["SHIFT+G"] = function() shortcut_now("CTRL", "L") end,         -- ⇧⌘G Go to Folder
    ["SHIFT+H"] = function() shortcut_now("ALT", "Home") end,       -- ⇧⌘H Home
    ["SHIFT+D"] = function() go_to("xdg-user-dir DESKTOP") end,     -- ⇧⌘D Desktop
    ["SHIFT+O"] = function() go_to("xdg-user-dir DOCUMENTS") end,   -- ⇧⌘O Documents
}

-- The desktop has keyboard focus (set by the shell): ⌘ keys act on desktop
-- items, and must not reach the window that was in front before.
foxtail_desktop = false
local DESKTOP_KEYS = { A = true, I = true, O = true, C = true, ["SHIFT+N"] = true }

-- While the desktop has the keyboard, a click on a window hands it back.
-- (A global shortcut can't be used here: they aren't sent for mouse binds.)
-- The topmost window under the pointer: of the windows there, the one
-- focused most recently (floating windows are raised when focused).
local function window_under_cursor()
    local c = hl.get_cursor_pos()
    if not c then return nil end
    local best
    for _, w in ipairs(hl.get_windows()) do
        local ws = w.workspace
        if w.mapped and not w.hidden and ws and not ws.special and ws.visible then
            local x, y = xy(w.at)
            local sw, sh = xy(w.size)
            if c.x >= x and c.x < x + sw and c.y >= y and c.y < y + sh
               and (not best or w.focus_history_id < best.focus_history_id) then
                best = w
            end
        end
    end
    return best
end
-- The yellow traffic light in GTK 4 apps: GTK draws it disabled (see
-- theme/gtk-4.0/gtk.css), so its clicks never reach the app. GTK 4 header
-- bars put it 44px in and 23px down; foxtail-minimize-click checks the pixel
-- there really is the yellow button before minimizing.
local MIN_X, MIN_Y, MIN_R = 44, 23, 8

hl.bind("mouse:272", function()
    local w = window_under_cursor()
    if w then
        -- A shell surface (the desktop, a menu) may still hold the keyboard;
        -- Hyprland doesn't take it back when the clicked window was already
        -- the active one, so hand it over explicitly.
        local active = hl.get_active_window()
        if active and active.address == w.address then
            hl.dispatch(hl.dsp.focus({ window = "address:" .. w.address }))
        end
        if foxtail_desktop then
            foxtail_desktop = false
            hl.exec_cmd("foxtail-ipc desktopBlur")
        end
    end
    if w and w.floating and w.fullscreen == 0 and not w.xwayland then
        local c = hl.get_cursor_pos()
        local x, y = xy(w.at)
        local dx, dy = c.x - x - MIN_X, c.y - y - MIN_Y
        if dx * dx + dy * dy <= MIN_R * MIN_R then
            hl.exec_cmd(string.format("foxtail-minimize-click %s %d %d", w.address,
                math.floor(x + MIN_X), math.floor(y + MIN_Y)))
        end
    end
end, { non_consuming = true })

-- Spotlight is open (set by the shell): ⌘1–⌘4 pick what it browses.
foxtail_spotlight = false

local function app_shortcut(key, shift)
    return function()
        if foxtail_spotlight and not shift and key:match("^[1-4]$") then
            hl.exec_cmd("foxtail-ipc spotlightMode " .. key)
            return
        end
        if foxtail_desktop then
            local k = (shift and "SHIFT+" or "") .. key
            if DESKTOP_KEYS[k] then hl.exec_cmd("foxtail-ipc desktopKey " .. k) end
            return
        end
        if in_files() then
            local f = FILES_KEYS[(shift and "SHIFT+" or "") .. key]
            if f then f(); return end
        end
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
    if not active or foxtail_desktop then return end   -- Files (the desktop) can't quit
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
-- In Files, ⌘↑ goes to the enclosing folder and ⌘↓ opens, as in Finder.
local function files_or(files_mods, files_key, fallback, desktop_key)
    return function()
        if foxtail_desktop then
            if desktop_key then hl.exec_cmd("foxtail-ipc desktopKey " .. desktop_key) end
        elseif in_files() then shortcut_now(files_mods, files_key) else fallback() end
    end
end
for _, sh in ipairs({ "", "SHIFT + " }) do
    local s = sh ~= "" and "SHIFT " or ""
    hl.bind(CMD .. " + " .. sh .. "left", send(s, "Home"))
    hl.bind(CMD .. " + " .. sh .. "right", send(s, "End"))
    if sh == "" then
        hl.bind(CMD .. " + up", files_or("ALT", "Up", send("CTRL", "Home")))
        hl.bind(CMD .. " + down", files_or("", "Return", send("CTRL", "End"), "down"))
    else
        hl.bind(CMD .. " + " .. sh .. "up", send("CTRL " .. s, "Home"))
        hl.bind(CMD .. " + " .. sh .. "down", send("CTRL " .. s, "End"))
    end
    hl.bind("ALT + " .. sh .. "left", send("CTRL " .. s, "left"))
    hl.bind("ALT + " .. sh .. "right", send("CTRL " .. s, "right"))
end
hl.bind(CMD .. " + backspace", function()                 -- delete to line start
    if foxtail_desktop then hl.exec_cmd("foxtail-ipc desktopKey backspace"); return end
    if in_files() then shortcut_now("", "Delete"); return end   -- Files: Move to Trash
    hl.dispatch(hl.dsp.send_shortcut({ mods = "SHIFT", key = "Home" }))
    hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = "BackSpace" }))
end)
hl.bind("ALT + backspace", send("CTRL", "backspace"))
hl.bind(CMD .. " + bracketleft", send("ALT", "left"))
hl.bind(CMD .. " + bracketright", send("ALT", "right"))

---------------------------------------------------------------- hide, minimize, tile
-- These are globals so the shell's menus can run them (hyprctl eval).

local function move_where(workspace, pred)
    for _, w in ipairs(hl.get_windows()) do
        if pred(w) and w.workspace and not w.workspace.special then
            hl.dispatch(hl.dsp.window.move({ workspace = workspace, follow = false, window = "address:" .. w.address }))
        end
    end
end

-- ⌘H hides the app - every window of it - and ⌥⌘H hides all other apps.
-- Hidden windows wait on "special:hidden"; the shell brings them back when the
-- app is clicked in the Dock, picked with ⌘Tab, or via Show All.
function foxtail_hide(others)
    local a = hl.get_active_window()
    if not a or foxtail_desktop then return end
    move_where("special:hidden", function(w)
        if others then return w.class ~= a.class end
        return w.class == a.class
    end)
end

-- Hide a given app (the Dock menu's Hide).
function foxtail_hide_class(cls)
    move_where("special:hidden", function(w) return w.class == cls end)
end

-- Show Desktop: move the windows on the current desktop out of the way, or
-- bring them back. (Clicking an app in the Dock brings its windows back too.)
function foxtail_show_desktop()
    local shown = {}
    for _, w in ipairs(hl.get_windows()) do
        if w.workspace and w.workspace.name == "special:desktop" then table.insert(shown, w) end
    end
    if #shown > 0 then
        for _, w in ipairs(shown) do
            hl.dispatch(hl.dsp.window.move({ workspace = "e+0", window = "address:" .. w.address }))
        end
        return
    end
    local ws = hl.get_active_workspace()
    move_where("special:desktop", function(w) return ws and w.workspace and w.workspace.id == ws.id end)
end

-- ⌥⌘M minimizes every window of the app into the Dock.
function foxtail_minimize_app()
    local a = hl.get_active_window()
    if not a then return end
    move_where("special:minimized", function(w) return w.class == a.class end)
end

-- macOS Sequoia window tiling (Window ▸ Move & Resize). macOS puts these on
-- Fn⌃ (Globe); PC keyboards don't pass Fn through, so Foxtail uses ⌃⌥:
--   ⌃⌥ ←/→/↑/↓  left/right/top/bottom half    ⌃⌥F or ⌃⌥↩  Fill
--   ⌃⌥C         Center                         ⌃⌥R         Return to Previous Size
local TILE_GAP = 8          -- "Tiled windows have margins"
local before_tile = {}      -- window address -> geometry before it was first tiled


local function usable_area(w)
    local m = (w and w.monitor) or hl.get_active_monitor()
    local r = m.reserved or {}
    local width, height = m.width / m.scale, m.height / m.scale
    if (m.transform or 0) % 2 == 1 then width, height = height, width end
    local left, top, right, bottom = r.left or 0, r.top or 0, r.right or 0, r.bottom or 0
    return { x = m.x + left + TILE_GAP, y = m.y + top + TILE_GAP,
             w = width - left - right - 2 * TILE_GAP, h = height - top - bottom - 2 * TILE_GAP }
end

local TILES = {
    fill = function(a) return a.x, a.y, a.w, a.h end,
    left = function(a) return a.x, a.y, (a.w - TILE_GAP) / 2, a.h end,
    right = function(a) local w = (a.w - TILE_GAP) / 2; return a.x + w + TILE_GAP, a.y, w, a.h end,
    top = function(a) return a.x, a.y, a.w, (a.h - TILE_GAP) / 2 end,
    bottom = function(a) local h = (a.h - TILE_GAP) / 2; return a.x, a.y + h + TILE_GAP, a.w, h end,
    top_left = function(a) return a.x, a.y, (a.w - TILE_GAP) / 2, (a.h - TILE_GAP) / 2 end,
    top_right = function(a) local w, h = (a.w - TILE_GAP) / 2, (a.h - TILE_GAP) / 2; return a.x + w + TILE_GAP, a.y, w, h end,
    bottom_left = function(a) local w, h = (a.w - TILE_GAP) / 2, (a.h - TILE_GAP) / 2; return a.x, a.y + h + TILE_GAP, w, h end,
    bottom_right = function(a) local w, h = (a.w - TILE_GAP) / 2, (a.h - TILE_GAP) / 2; return a.x + w + TILE_GAP, a.y + h + TILE_GAP, w, h end,
}

local function place(x, y, w, h)
    -- resize keeps the window's center, so size first, then position.
    hl.dispatch(hl.dsp.window.resize({ x = math.floor(w), y = math.floor(h) }))
    hl.dispatch(hl.dsp.window.move({ x = math.floor(x), y = math.floor(y) }))
end

function foxtail_tile(where)
    local w = hl.get_active_window()
    if not w or not w.floating then return end
    if where == "center" then
        hl.dispatch(hl.dsp.window.center())
        return
    end
    if where == "restore" then
        local g = before_tile[w.address]
        if g then
            before_tile[w.address] = nil
            place(g.x, g.y, g.w, g.h)
        end
        return
    end
    local tile = TILES[where]
    if not tile then return end
    if w.fullscreen == 1 then hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized" })) end
    if not before_tile[w.address] then
        local x, y = xy(w.at)
        local sw, sh = xy(w.size)
        before_tile[w.address] = { x = x, y = y, w = sw, h = sh }
    end
    place(tile(usable_area(w)))
end

-- Foxtail actions (macOS defaults where macOS has one).
hl.bind(CMD .. " + Q", quit_app, { desc = "Quit app" })
hl.bind(CMD .. " + H", function() foxtail_hide(false) end, { desc = "Hide" })
hl.bind(CMD .. " + ALT + H", function() foxtail_hide(true) end, { desc = "Hide Others" })
hl.bind(CMD .. " + M", hl.dsp.window.move({ workspace = "special:minimized", follow = false }), { desc = "Minimize" })
hl.bind(CMD .. " + ALT + M", foxtail_minimize_app, { desc = "Minimize All" })
for key, where in pairs({ left = "left", right = "right", up = "top", down = "bottom",
                          F = "fill", ["return"] = "fill", C = "center", R = "restore" }) do
    hl.bind("CTRL + ALT + " .. key, function() foxtail_tile(where) end)
end
hl.bind(CMD .. " + space", ipc("spotlight"), { desc = "Spotlight" })
hl.bind(CMD .. " + ALT + space", hl.dsp.exec_cmd("nautilus --new-window"), { desc = "Files" })
hl.bind("F4", ipc("launchpad"), { desc = "Launchpad" })
hl.bind("F11", function() foxtail_show_desktop() end, { desc = "Show Desktop" })
hl.bind(CMD .. " + F3", function() foxtail_show_desktop() end)
hl.bind(CMD .. " + ALT + L", function()                    -- Files: Downloads (Finder's ⌥⌘L)
    if in_files() then go_to("xdg-user-dir DOWNLOAD") else hl.dispatch(ipc("launchpad")) end
end)
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
hl.bind("CTRL + " .. CMD .. " + space", ipc("emoji"), { desc = "Emoji & Symbols" })

-- Input sources: ⌃Space switches keyboard layout when there is more than one.
if foxtail_layout_shortcut ~= false and (foxtail_layouts or ""):find(",") then
    hl.bind("CTRL + space", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"), { desc = "Next input source" })
end
hl.bind(CMD .. " + ALT + return", hl.dsp.exec_cmd("ptyxis --new-window"), { desc = "Terminal" })

-- Screenshots go to the Desktop (Options in ⇧⌘5); add ⌃ to copy to the clipboard instead.
hl.bind(CMD .. " + SHIFT + 3", ipc("screenshot screen"), { desc = "Screenshot" })
hl.bind(CMD .. " + SHIFT + 4", ipc("screenshot area"), { desc = "Screenshot area" })
hl.bind("CTRL + " .. CMD .. " + SHIFT + 3", ipc("screenshotToClipboard screen"))
hl.bind("CTRL + " .. CMD .. " + SHIFT + 4", ipc("screenshotToClipboard area"))
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
