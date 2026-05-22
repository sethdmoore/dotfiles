-- See https://wiki.hypr.land/Configuring/Window-Rules/ for more
-- See https://wiki.hypr.land/Configuring/Workspace-Rules/ for workspace rules
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
    -- workspace = "5 silent",
    workspace = "5",
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

hl.window_rule({
    name = "move-discord-windows-to-overlay",
    match = {
        tag = "discord",
    },
    no_initial_focus = true,
    workspace = "special:discord silent",
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
    name = "discord-stream-popout",
    match = {
        initial_title = "^(?i)Discord Popout$",
        class = "^(?i)discord$",
    },
    float = true,
    pin = true,
})

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

