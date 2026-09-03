high_quality = true

active_opacity = 1.0
inactive_opacity = 0.75

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

-- known displays, keyed by hyprctl output name (`hyprctl monitors -j`).
-- monitors.lua drives exactly ONE at a time: of the outputs actually
-- connected, the lowest `priority` number wins and the rest are disabled.
-- Output names don't collide across machines, so one table covers every host:
--   seth.home      -> HDMI-A-1 (sole display)
--   framework.home -> DP-1 when docked (outranks the built-in panel),
--                     otherwise eDP-2 (laptop mode)
-- `scale` is optional (default 1); `depth` is "hdr" or "sdr".
displays = {
    ["DP-1"]     = { priority = 1, resolution = '3840x2160@144', depth = "hdr" },
    ["HDMI-A-1"] = { priority = 2, resolution = '3840x2160@165', depth = "hdr" },
    ["eDP-2"]    = { priority = 3, resolution = '2560x1600@165', depth = "sdr", scale = 1.6 },
}
