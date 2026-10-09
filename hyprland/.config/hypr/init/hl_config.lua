-- See 1. https://wiki.hypr.land/Configuring/Dwindle-Layout/ for more
--     2. https://wiki.hypr.land/Configuring/Variables/#misc
hl.config({
  general = {
    allow_tearing = true,
  },
  dwindle = {
    -- pseudotile = true,  -- Master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
    preserve_split = true,  -- You probably want this
  },
  misc = {
    force_default_wallpaper = -1,  -- Set to 0 or 1 to disable the anime mascot wallpapers
    disable_hyprland_logo = false,  -- If true disables the random hyprland logo / anime girl background. :(
    vrr = 1,
  },

  cursor = {
    -- 0: always use the hardware cursor. 2 (auto) falls back to a software
    -- cursor while a game has `immediate` set, which blocks direct scanout.
    no_hardware_cursors = 0,
    no_break_fs_vrr = 2,
    min_refresh_rate = 72,
  }
})
