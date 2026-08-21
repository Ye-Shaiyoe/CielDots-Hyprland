-- ============================================================
-- CielDots — Hyprland Lua Configuration (v0.55+)
-- Theme: Rimuru Tempest (Abyss Navy · Slime Cyan · Magic Purple)
-- ============================================================

-- Global Hyprland API reference: 'hl' is injected automatically by Hyprland

-- ── 1. Monitors ──────────────────────────────────────────────
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1,
})

-- ── 2. Programs & Variables ──────────────────────────────────
local terminal    = "kitty"
local fileManager = "thunar"
local browser     = "firefox"
local scriptsDir  = os.getenv("HOME") .. "/.config/hypr/scripts"

-- ── 3. Environment Variables ─────────────────────────────────
local envs = {
    XCURSOR_SIZE         = "24",
    XCURSOR_THEME        = "Bibata-Modern-Ice",
    HYPRCURSOR_SIZE      = "24",
    QT_QPA_PLATFORMTHEME = "qt6ct",
    QT_QPA_PLATFORM      = "wayland;xcb",
    GDK_BACKEND          = "wayland,x11",
    SDL_VIDEODRIVER      = "wayland",
    CLUTTER_BACKEND      = "wayland",
    XDG_CURRENT_DESKTOP  = "Hyprland",
    XDG_SESSION_TYPE     = "wayland",
    XDG_SESSION_DESKTOP  = "Hyprland",
}

for k, v in pairs(envs) do
    hl.env(k, v)
end

-- ── 4. Core Configuration ────────────────────────────────────
hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 10,
        border_size = 2,

        -- Cyan slime glow -> magic purple aura
        col_active_border   = "rgba(00e5ffcc) rgba(7c4dffcc) 45deg",
        col_inactive_border = "rgba(1a254088)",

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding = 12,

        active_opacity   = 0.92,
        inactive_opacity = 0.82,

        shadow = {
            enabled      = true,
            range        = 20,
            render_power = 4,
            color        = "rgba(00e5ff22)",
            color_inactive = "rgba(00000044)",
        },

        blur = {
            enabled           = true,
            size              = 8,
            passes            = 3,
            noise             = 0.015,
            contrast          = 0.9,
            brightness        = 0.8,
            vibrancy          = 0.20,
            vibrancy_darkness = 0.4,
            new_optimizations = true,
            xray              = false,
            ignore_opacity    = false,
            popups            = true,
        },
    },

    animations = {
        enabled = true,

        -- Slime physics: stretchy, bouncy, fluid
        bezier = {
            slime     = { 0.0, 0.9, 0.1, 1.08 },
            slimeIn   = { 0.1, 1.2, 0.1, 1.0 },
            slimeOut  = { 0.4, -0.2, 0.6, 1.0 },
            slimeMove = { 0.05, 0.9, 0.1, 1.05 },
            linear    = { 0.0, 0.0, 1.0, 1.0 },
            ripple    = { 0.68, -0.6, 0.32, 1.6 },
        },

        animation = {
            { "windows",          1, 4,   "slime",     "slide" },
            { "windowsIn",        1, 4,   "slimeIn",   "slide" },
            { "windowsOut",       1, 3,   "slimeOut",  "slide" },
            { "windowsMove",      1, 4,   "slimeMove" },
            { "border",           1, 10,  "linear" },
            { "borderangle",      1, 240, "linear",    "loop" },
            { "fade",             1, 4,   "slime" },
            { "workspaces",       1, 4,   "ripple",    "slidevert" },
            { "specialWorkspace", 1, 4,   "slimeIn",   "slide" },
        },
    },

    dwindle = {
        pseudotile     = true,
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        animate_manual_resizes  = true,
        animate_mouse_windowdragging = true,
    },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,

        touchpad = {
            natural_scroll       = true,
            disable_while_typing = true,
            tap_to_click         = true,
        },
    },

    gestures = {
        workspace_swipe         = true,
        workspace_swipe_fingers = 3,
    },
})

-- ── 5. Autostart ─────────────────────────────────────────────
hl.on("hyprland.start", function()
    hl.exec("bash " .. scriptsDir .. "/startup.sh")
end)

-- ── 6. Keybindings ───────────────────────────────────────────
local mod = "SUPER"

-- Application Launchers
hl.bind(mod, "Return", function() hl.exec(terminal) end)
hl.bind(mod, "E",      function() hl.exec(fileManager) end)
hl.bind(mod, "B",      function() hl.exec(browser) end)
hl.bind(mod, "Space",  function() hl.exec("bash " .. scriptsDir .. "/launcher.sh apps") end)

-- Custom Launcher Modes
hl.bind(mod .. " SHIFT", "P",      function() hl.exec("bash " .. scriptsDir .. "/launcher.sh power") end)
hl.bind(mod .. " SHIFT", "C",      function() hl.exec("bash " .. scriptsDir .. "/launcher.sh clipboard") end)
hl.bind(mod,             "Period", function() hl.exec("bash " .. scriptsDir .. "/launcher.sh emoji") end)

-- Notification Controls
hl.bind(mod,             "N", function() hl.exec("bash " .. scriptsDir .. "/notif.sh history") end)
hl.bind(mod .. " SHIFT", "N", function() hl.exec("bash " .. scriptsDir .. "/notif.sh dnd") end)

-- Weather & Dynamic Colorscheme
hl.bind(mod .. " ALT",   "W", function() hl.exec("python3 " .. scriptsDir .. "/weather.py --widget") end)
hl.bind(mod .. " SHIFT", "X", function() hl.exec("python3 " .. scriptsDir .. "/colorscheme.py --reload") end)
hl.bind(mod .. " CTRL",  "X", function() hl.exec("python3 " .. scriptsDir .. "/colorscheme.py --show") end)

-- Window Management
hl.bind(mod,             "Q", function() hl.dispatch("killactive") end)
hl.bind(mod .. " SHIFT", "Q", function() hl.dispatch("exit") end)
hl.bind(mod,             "V", function() hl.dispatch("togglefloating") end)
hl.bind(mod,             "P", function() hl.dispatch("pseudo") end)
hl.bind(mod,             "F", function() hl.dispatch("fullscreen") end)

-- Screenshot Utilities
hl.bind("",            "Print", function() hl.exec("bash " .. scriptsDir .. "/screenshot.sh area") end)
hl.bind(mod,           "Print", function() hl.exec("bash " .. scriptsDir .. "/screenshot.sh full") end)
hl.bind("SHIFT",       "Print", function() hl.exec("bash " .. scriptsDir .. "/screenshot.sh window") end)
hl.bind("CTRL",        "Print", function() hl.exec("bash " .. scriptsDir .. "/screenshot.sh area --edit") end)

-- Lock Screen
hl.bind(mod .. " ALT", "L", function() hl.exec("hyprlock") end)

-- Wallpaper Switcher
hl.bind(mod,             "W", function() hl.exec("waypaper --backend swww") end)
hl.bind(mod .. " SHIFT", "W", function() hl.exec("bash " .. scriptsDir .. "/wallpaper.sh") end)
hl.bind(mod .. " CTRL",  "W", function() hl.exec("bash " .. scriptsDir .. "/wallpaper.sh --prev") end)

-- Gaming Mode Toggle
hl.bind(mod .. " SHIFT", "G", function() hl.exec("bash " .. scriptsDir .. "/gaming-mode.sh") end)

-- Volume & Brightness Controls (Repeating & Locked)
hl.bindel("", "XF86AudioRaiseVolume",  function() hl.exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+") end)
hl.bindel("", "XF86AudioLowerVolume",  function() hl.exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") end)
hl.bindel("", "XF86AudioMute",         function() hl.exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") end)
hl.bindel("", "XF86MonBrightnessUp",   function() hl.exec("brightnessctl s 10%+") end)
hl.bindel("", "XF86MonBrightnessDown", function() hl.exec("brightnessctl s 10%-") end)

-- Focus Navigation (Vim Keys & Arrows)
local directions = {
    H = "l", L = "r", K = "u", J = "d",
    left = "l", right = "r", up = "u", down = "d"
}
for key, dir in pairs(directions) do
    hl.bind(mod, key, function() hl.dispatch("movefocus", dir) end)
end

-- Workspaces Switching & Moving Windows
for i = 1, 10 do
    local ws = (i == 10) and 0 or i
    local target = tostring(i)

    -- Switch to workspace
    hl.bind(mod, tostring(ws), function()
        hl.dispatch("workspace", target)
    end)

    -- Move window to workspace
    hl.bind(mod .. " SHIFT", tostring(ws), function()
        hl.dispatch("movetoworkspace", target)
    end)
end

-- Scroll through workspaces
hl.bind(mod, "mouse_down", function() hl.dispatch("workspace", "e+1") end)
hl.bind(mod, "mouse_up",   function() hl.dispatch("workspace", "e-1") end)

-- Move / Resize windows with mouse dragging
hl.bindm(mod, "mouse:272", "movewindow")
hl.bindm(mod, "mouse:273", "resizewindow")

-- Resize Submap
hl.submap("resize", function()
    hl.binde("", "right",  function() hl.dispatch("resizeactive", "10 0") end)
    hl.binde("", "left",   function() hl.dispatch("resizeactive", "-10 0") end)
    hl.binde("", "up",     function() hl.dispatch("resizeactive", "0 -10") end)
    hl.binde("", "down",   function() hl.dispatch("resizeactive", "0 10") end)
    hl.bind("",  "escape", function() hl.submap("reset") end)
end)

-- ── 7. Window Rules & Workspaces ─────────────────────────────
hl.windowrulev2("suppressevent maximize", "class:.*")

-- Floating Windows
hl.windowrulev2("float", "class:^(thunar)$,title:^(File Operation Progress)$")
hl.windowrulev2("float", "class:^(pavucontrol)$")
hl.windowrulev2("float", "class:^(nm-connection-editor)$")
hl.windowrulev2("float", "title:^(Picture-in-Picture)$")
hl.windowrulev2("pin",   "title:^(Picture-in-Picture)$")

-- Opacity & Blur Overrides
hl.windowrulev2("opacity 1.0 override 1.0 override", "class:^(kitty)$")
hl.windowrulev2("opacity 0.95 0.88",                  "class:^(firefox)$")
hl.windowrulev2("opacity 0.92 0.82",                  "class:^(thunar)$")
hl.windowrulev2("opacity 1.00 0.95",                  "class:^(code-oss|codium|Code)$")
hl.windowrulev2("bordersize 2",                      "class:^(kitty)$")

-- Named Workspaces (Rimuru's Skills)
local workspaceNames = {
    [1] = "「Predator」",
    [2] = "「Great Sage」",
    [3] = "「Storm」",
    [4] = "「Gluttony」",
    [5] = "「Raphael」",
}

for wsNum, wsName in pairs(workspaceNames) do
    hl.workspace(wsNum, { name = wsName })
end
