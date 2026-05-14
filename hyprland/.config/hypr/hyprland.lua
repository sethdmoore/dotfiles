-- https://wiki.hypr.land/Configuring/

require("appearance/animations")

require("environment")

require("defaults")

require("monitors")

require("autostart")



--##################
--## PERMISSIONS ###
--##################

-- See https://wiki.hypr.land/Configuring/Permissions/
-- Please note permission changes here require a Hyprland restart and are not applied on-the-fly
-- for security reasons

-- ecosystem {
--   enforce_permissions = 1
-- }

-- permission = /usr/(bin|local/bin)/grim, screencopy, allow
-- permission = /usr/(lib|libexec|lib64)/xdg-desktop-portal-hyprland, screencopy, allow
-- permission = /usr/(bin|local/bin)/hyprpm, plugin, allow


--####################
--## LOOK AND FEEL ###
--####################

-- Change transparency of focused and unfocused windows



-- https://wiki.hypr.land/Configuring/Variables/#animations

-- Default curves, see https://wiki.hypr.land/Configuring/Animations/#curves
--        NAME,           X0,   Y0,   X1,   Y1

-- Default animations, see https://wiki.hypr.land/Configuring/Animations/
--           NAME,          ONOFF, SPEED, CURVE,        [STYLE]
-- animation = workspacesIn,  1,     1.21,  almostLinear, fade
hl.config({ animations = {
    enabled = true,
} })

-- Ref https://wiki.hypr.land/Configuring/Workspace-Rules/
-- "Smart gaps" / "No gaps when only"
-- uncomment all if you wish to use that.
-- workspace = w[tv1], gapsout:0, gapsin:0
-- workspace = f[1], gapsout:0, gapsin:0
-- windowrule {
--     name = no-gaps-wtv1
--     match:float = false
--     match:workspace = w[tv1]
--
--     border_size = 0
--     rounding = 0
-- }
--
-- windowrule {
--     name = no-gaps-f1
--     match:float = false
--     match:workspace = f[1]
--
--     border_size = 0
--     rounding = 0
-- }

-- See https://wiki.hypr.land/Configuring/Dwindle-Layout/ for more
hl.config({ dwindle = {
    -- pseudotile = true,  -- Master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
    preserve_split = true,  -- You probably want this
} })

-- See https://wiki.hypr.land/Configuring/Master-Layout/ for more
hl.config({ master = {
    new_status = "master",
} })

-- https://wiki.hypr.land/Configuring/Variables/#misc
hl.config({ misc = {
    force_default_wallpaper = -1,  -- Set to 0 or 1 to disable the anime mascot wallpapers
    disable_hyprland_logo = false,  -- If true disables the random hyprland logo / anime girl background. :(
} })


--############
--## INPUT ###
--############

-- https://wiki.hypr.land/Configuring/Variables/#input



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

-- Example per-device config
-- See https://wiki.hypr.land/Configuring/Keywords/#per-device-input-configs for more
hl.device({
    name = "epic-mouse-v1",
    sensitivity = -0.5,
})


--##################
--## KEYBINDINGS ###
--##################

require("bindings")

--#############################
--## WINDOWS AND WORKSPACES ###
--#############################

-- See https://wiki.hypr.land/Configuring/Window-Rules/ for more
-- See https://wiki.hypr.land/Configuring/Workspace-Rules/ for workspace rules

hl.workspace_rule({
    workspace = 2,
    layout_opts = { direction = "right" },
    layout = "scrolling",
})
hl.config({ scrolling = {
    direction = "right",
    column_width = 0.333,
} })

hl.window_rule({
    name = "fullscreen-game-tags",
    match = {
        tag = "game",
    },
    fullscreen = true,
    workspace = 5,
})

-- tag system tools
-- match:title = negative:|^(?i)(.*(Launcher|NetEase Game Security).*)$
hl.window_rule({
    name = "tag-system-tools",
    match = {
        initial_class = "^com.nokyan.Resources$",
    },
    tag = "+system",
})

require("rules/launchers")


-- tag steam games

hl.window_rule({
    name = "tag-steam-games",
    match = {
        initial_class = "^(steam_app_\\d+)|(cyberpunk2077.exe)$",
        title = "negative:|^(?i)(.*(Launcher|NetEase Game Security).*)$",
        tag = "negative:|novrr",
    },
    tag = "+game",
    content = "game",
    workspace = "5 silent",
})

-- disable VRR on apps that get flickery

hl.window_rule({
    name = "no-vrr",
    match = {
        tag = "novrr",
    },
    no_vrr = true,
})


hl.window_rule({
    name = "floating-tag-floats",
    match = {
        tag = "floating",
    },
    float = true,
})


hl.window_rule({
    name = "discord-stream-popout",
    match = {
        initial_title = "^(?i)Discord Popout$",
        class = "^(?i)discord$",
    },
    float = true,
    pin = true,
})


-- no_focus = true
hl.window_rule({
    name = "discord-overlayed",
    match = {
        initial_title = "^(?i)Overlayed - Main$",
        class = "^(?i)overlayed$",
    },
    float = true,
    pin = true,
})


hl.window_rule({
    name = "move-discord-windows-to-overlay",
    match = {
        tag = "discord",
    },
    no_initial_focus = true,
    workspace = "special:discord silent",
})

-- discord goes to SUPER + SHIFT ~

hl.window_rule({
    name = "discord-tagged",
    match = {
        class = "^discord$",
        initial_title = "^Discord$",
    },
    tag = "+discord",
})


hl.window_rule({
    name = "discord-updater-tagged",
    match = {
        class = "^discord$",
        initial_title = "^Discord Updater$",
    },
    tag = "+discord",
})

-- windowrule {
--     # Ignore maximize requests from all apps. You'll probably like this.
--     name = suppress-maximize-events
--     match:class = .*
-- 
--     suppress_event = maximize
-- }

-- Fix some dragging issues with XWayland

hl.window_rule({
    name = "fix-xwayland-drags",
    match = {
        class = "^$",
        title = "^$",
        xwayland = true,
        float = true,
        fullscreen = false,
        pin = false,
    },
    no_focus = true,
})

-- Hyprland-run windowrule


hl.window_rule({
    name = "move-hyprland-run",
    match = {
        class = "hyprland-run",
    },
    move = {"20", "monitor_h-120"},
    float = true,
})
