-- https://wiki.hypr.land/Configuring/

require("appearance/style")
require("appearance/animations")

require("init/defaults")
require("init/environment")
require("init/monitors")
require("init/autostart")

require("input/keyboard")
require("input/bindings")
require("input/gestures")

-- See https://wiki.hypr.land/Configuring/Dwindle-Layout/ for more
hl.config({ dwindle = {
    -- pseudotile = true,  -- Master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
    preserve_split = true,  -- You probably want this
}})

-- https://wiki.hypr.land/Configuring/Variables/#misc
hl.config({ misc = {
    force_default_wallpaper = -1,  -- Set to 0 or 1 to disable the anime mascot wallpapers
    disable_hyprland_logo = false,  -- If true disables the random hyprland logo / anime girl background. :(
}})

require("workspaces")

require("window_rules/add_tags")
require("window_rules/launchers")
require("window_rules/rules")
require("window_rules/quirks")

-- For Noctalia Color templates
require("noctalia")
