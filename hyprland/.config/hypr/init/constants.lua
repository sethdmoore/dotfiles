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

-- known displays, keyed by hyprctl output name (see `hyprctl monitors -j`).
-- monitors.lua auto-detects whichever one is actually connected and looks
-- up its tuned mode/depth here, so this stays correct across machines
-- without hand-editing a single "main monitor" constant.
displays = {
    ["HDMI-A-1"] = { resolution = '3840x2160@165', depth = "hdr" },
}
