high_quality = true

active_opacity = 1.0
inactive_opacity = 0.75

enable_touchpad = true
touchpad_device = "pixa3854:00-093a:0274-touchpad"

-- terminal = 'alacritty'
terminal = 'ghostty'
fileManager = 'thunar'

-- browser = 'firefox'
browser_env_var = '/var/lib/flatpak/exports/share/applications/app.zen_browser.zen.desktop'
browser_binding = 'flatpak run app.zen_browser.zen'
menu = 'hyprlauncher'
notify = 'swaync'
bar = 'waybar'

taskManager = 'resources'

-- Known displays, matched by EDID description PREFIX (see init/monitors.lua),
-- NOT by output port -- port names shift between GPUs, docks and boots.
-- Read descriptions with:  hyprctl monitors all -j | jq -r '.[].description'
--
--   match.description  prefix of the description string (Hyprland `desc:` rule)
--   resolution         tuned mode
--   depth              "hdr" or "sdr"
--   scale              optional, default 1
--   single_monitor     optional. When this display is primary it is the ONLY
--                      output (every other configured output off). Without it,
--                      the display shares the layout with other
--                      non-single_monitor displays, laid out left-to-right in
--                      display_order.
displays = {
    livingroom_tv = {
        match          = { description = "Hisense Electric Co. Ltd. HISENSE" },
        resolution     = "3840x2160@144",
        depth          = "hdr",
        scale          = 2.0,
        single_monitor = true,
    },
    desktop = {
        match          = { description = "Hisense Electric Co. Ltd. HISENSE 0x616D0000" },
        depth          = "hdr",
        resolution     = "3840x2160@165",
        depth          = "hdr",
        scale          = 1.0,
        single_monitor = true,
    },
    laptop = {
        match      = { description = "BOE NE160QDM-NZ6" },
        resolution = "2560x1600@165",
        depth      = "sdr",
        -- scale      = 1.6,
    },
}

-- priority: the first one connected becomes primary
--   livingroom_tv -> Hisense TV, docked over the dGPU (external only)
--   desktop       -> seth.home     (sole display)
--   laptop        -> Framework built-in panel
display_order = { "livingroom_tv", "desktop", "laptop" }
