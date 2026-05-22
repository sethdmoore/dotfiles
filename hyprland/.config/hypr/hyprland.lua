-- https://wiki.hypr.land/Configuring/

require("appearance/style")
require("appearance/animations")

require("environment")
require("defaults")
require("monitors")
require("autostart")
require("bindings")

-- See https://wiki.hypr.land/Configuring/Dwindle-Layout/ for more
hl.config({ dwindle = {
    -- pseudotile = true,  -- Master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
    preserve_split = true,  -- You probably want this
} })

-- https://wiki.hypr.land/Configuring/Variables/#misc
hl.config({ misc = {
    force_default_wallpaper = -1,  -- Set to 0 or 1 to disable the anime mascot wallpapers
    disable_hyprland_logo = false,  -- If true disables the random hyprland logo / anime girl background. :(
} })

hl.config({ input = {
    kb_layout = "us",
    kb_variant = "",
    kb_model = "",
    kb_options = "",
    kb_rules = "",
    follow_mouse = 1,
    sensitivity = 0,  -- -1.0 - 1.0, 0 means no modification.
    touchpad = {
        natural_scroll = false,
    },
} })

-- See https://wiki.hypr.land/Configuring/Gestures
hl.gesture({
    fingers = 3,
    direction = "horizontal",
    action = "workspace",
})

require("workspaces")

require("window_rules/launchers")
require("window_rules/quirks")
require("window_rules/rules")

-- For Noctalia Color templates
require("noctalia")
