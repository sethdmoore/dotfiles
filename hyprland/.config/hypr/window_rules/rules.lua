-- See https://wiki.hypr.land/Configuring/Window-Rules/ for more
-- See https://wiki.hypr.land/Configuring/Workspace-Rules/ for workspace rules

-- disable VRR on apps that get flickery
hl.window_rule({
    name = "no-vrr",
    match = {
        tag = "novrr",
    },
    no_vrr = true,
})

-- tag steam games
-- apparently we can't tag and move
hl.window_rule({
    name = "tag-and-move-steam-games",
    match = {
        -- aniimo runs as class "aniimo.exe", not steam_app_<id>
        initial_class = "^(steam_app_.*|aniimo\\.exe)$",
        -- title = "negative:|^(?i)(.*(Launcher|NetEase Game Security).*)$",
        -- tag = "negative:|novrr",
    },
    tag = "+game",
    content = "game",
    workspace = "5 silent",
    -- for tearing
    immediate = true,
})

-- steam's own "Aniimo" popup (welcome overlay): keep it off the active workspace
hl.window_rule({
    name = "aniimo-steam-popup",
    match = {
        class = "^steam$",
        initial_title = "^Aniimo$",
    },
    no_initial_focus = true,
    workspace = "special:overlay silent",
})

-- move gamescope to 5
hl.window_rule({
    name = "tag-and-move-gamescope-games",
    match = {
        initial_class = "^gamescope$",
        -- tag = "negative:|novrr",
    },
    tag = "+game",
    content = "game",
    workspace = "5 silent",
})

hl.window_rule({
    name = "floating-tag-floats",
    match = {
        tag = "floating",
    },
    float = true,
})

-- steam/discord goes to SUPER + SHIFT ~
hl.window_rule({
    name = "move-tagged-windows-to-overlay",
    match = {
        tag = "overlay",
    },
    no_initial_focus = true,
    workspace = "special:overlay silent",
})

-- hack for steam popups / context menus
-- appearing in the workspace underneath
hl.window_rule({
    name = "steam-context-menus",
    match = {
        class = "^steam$",
        title = "^$",
    },
    -- no_initial_focus = true,
    pin = true,
    -- float = true,
    workspace = "special:overlay",
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
    match = {
	    class = "blender",
	    title = "Preferences",
    },
    float = true,
    size  = { 950, 600 },
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


hl.window_rule({
    name = "move-swappy",
    match = {
        initial_class = "swappy",
        initial_title = "swappy",
    },
    workspace = "special:scratch silent",
})

hl.window_rule({
    name = "move-moonlight",
    match = {
        class = "com.moonlight_stream.Moonlight",
        title = "Moonlight",
    },
    workspace = "special:scratch silent",
})

local suppressMaximizeRule = hl.window_rule({
    -- Ignore maximize requests from all apps. You'll probably like this.
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    name = "confine-pointer",
    match = {
        content = "game",
        fullscreen = true,
    },

    workspace = "5 silent",
    confine_pointer = true,
})

suppressMaximizeRule:set_enabled(false)

-- Waydroid: keep the full-UI window floating at a fixed 1080p. Tiling reflows resize the
-- window, which makes the composer reconnect the Android display; that once crashed the
-- composer mid-game (buffer import abort in vulkan.virtio). Applies to newly opened windows.
hl.window_rule({
    name = "waydroid-fixed-1080p",
    match = {
        class = "^Waydroid$",
    },
    float = true,
    size = { 1920, 1080 },
    center = true,
})
