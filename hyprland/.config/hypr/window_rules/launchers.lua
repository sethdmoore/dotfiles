-- netmarble / mongil launcher
hl.window_rule({
    name = "mongil-launcher",
    match = {
        title = "^Netmarble\\ Launcher$",
    },
    size = {1280, 810},
    float = true,
    center = true,
})

hl.window_rule({
    name = "launcher",
    match = {
        initial_title = "^NTE$",
        initial_class = "steam_app_-1",
    },
    size = {1280, 720},
    float = true,
    center = true,
})
