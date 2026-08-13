local no_opacity = "1.0 override 1.0 override 1.0 override"

-- class = initial_title
local opacity_window_rules = {
    firefox = {
        class = "app.zen_browser.zen",
        initial_title = "^(?i)Picture-in-Picture$",
        opacity = no_opacity,
    },
    zen = {
        class = "firefox",
        initial_title = "^(?i)Picture-in-Picture$",
        opacity = no_opacity,
    },
    zoom = {
        class = "zoom",
        initial_title = "^(?i)meeting$",
        opacity = no_opacity,
    },
    krita = {
        class = "org.kde.krita",
        initial_title = "Krita",
        opacity = no_opacity,
    },
    chrome = {
        class = "google-chrome",
        initial_title = ".*",
        opacity = no_opacity,
    },
}

for name, s in pairs(opacity_window_rules) do
    hl.window_rule({
        name = "no-opacity-" .. name,
        match = {
            class = s.class,
            initial_title = s.initial_title,
        },
        opacity = s.opacity,
        tag = "+no_opacity"
    })
end

hl.window_rule({
    name = "no-opacity-tags",
    match = {
        tag = "no_opacity",
    },
    opacity = no_opacity,
})

-- Picture-in-Picture aspect ratio.
--
-- Wayland has no aspect ratio request. xdg_toplevel carries set_min_size and
-- set_max_size only. So a rule must give the ratio to Hyprland.
--
-- Two options below. Only one can stay enabled, because the pseudo rule reads
-- `size` on the tiled map path, and the float rule moves the window off it.

local pip_match = {
    class = "^(firefox|app\\.zen_browser\\.zen)$",
    initial_title = "^(?i)Picture-in-Picture$",
}

-- Option A: pseudotile at a fixed 16:9.
-- Hyprland scales the pseudo size down with one factor on both axes, so the
-- ratio holds at any column width and on any monitor. The tile keeps its
-- full space, so the rest of the column stays empty.
local pipPseudoRule = hl.window_rule({
    name  = "pip-pseudo-16-9",
    match = pip_match,

    pseudo = true,
    size   = { 3840, 2160 },
})

-- Option B: float, pin, and lock the ratio the video opens with.
-- This option tracks 16:10 and vertical video, because Firefox sizes the
-- Picture-in-Picture window from the video itself.
-- Resize it with SUPER + right mouse drag.
local pipFloatRule = hl.window_rule({
    name  = "pip-float-keep-ratio",
    match = pip_match,

    float             = true,
    pin               = true,
    keep_aspect_ratio = true,
    min_size          = { 480, 270 },
    move              = { "100%-w-20", "100%-h-20" },  -- bottom right corner
})

-- Swap these two lines to test the other option.
pipPseudoRule:set_enabled(true)
pipFloatRule:set_enabled(false)
