hl.window_rule({
    name = "gpg-popup",
    match = {
        class = "^gcr-prompter$",
    },
    tag = "+popup",
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
    -- workspace = "5",
})

-- tag gamescope
hl.window_rule({
    name = "tag-gamescope",
    match = {
        initial_class = "^gamescope$",
        tag = "negative:|novrr",
    },
    tag = "+game",
    content = "game",
    -- workspace = "5 silent",
    -- workspace = "5",
})

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
