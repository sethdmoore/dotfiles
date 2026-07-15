-- config for workspaces
hl.config({
    master = { 
        orientation = "bottom" ,
        new_status = "slave" ,
    },

    scrolling = {
        direction = "right",
        column_width = 0.333,
    }
})

-- research / multitasking
hl.workspace_rule({
    workspace = 1,
    layout_opts = { direction = "right" },
    layout = "scrolling",
})

-- standard
hl.workspace_rule({
    workspace = 2,
    layout = "dwindle",
})

-- focus
hl.workspace_rule({
    workspace = 3,
    layout = "master",
})

-- floating
hl.window_rule({
    match = { workspace = 4 },
    float = true,
    size = "1200 800",
    move = "cursor -600 -400",   -- centers on cursor
})

