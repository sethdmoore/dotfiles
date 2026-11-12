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

-- tag steam
hl.window_rule({
    name = "steam-tag",
    match = {
        initial_class = "^steam$",
        title = "negative:^notificationtoasts_.*$",
    },
    tag = "+overlay",
})

-- tag apps that fake a notification with their own window
hl.window_rule({
    name = "steam-toast-tag",
    match = {
        initial_class = "^steam$",
        title = "^notificationtoasts_.*$",
    },
    tag = "+fake_notification",
})

hl.window_rule({
    name = "battle-net-toast-tag",
    match = {
        initial_class = "^steam_app_.*$",
        initial_title = "^Battle\\.net$",
        float = true,
    },
    tag = "+fake_notification",
})

-- tag steam updater
hl.window_rule({
    name = "steam-updater-tag",
    match = {
        initial_title = "^Steam$",
        title = "^Steam$",
        initial_class = "",
    },
    tag = "+overlay",
})

hl.window_rule({
    name = "discord-tagged",
    match = {
        class = "^discord$",
        initial_title = "^Discord$",
    },
    tag = "+overlay",
})

hl.window_rule({
    name = "discord-updater-tagged",
    match = {
        class = "^discord$",
        initial_title = "^Discord Updater$",
    },
    tag = "+overlay",
})
