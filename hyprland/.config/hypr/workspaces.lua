hl.config({
    master = { 
        orientation = "bottom" ,
        new_status = "slave" ,
    },
})

hl.workspace_rule({
    workspace = 1,
    layout = "master",
})

hl.workspace_rule({
    workspace = 2,
    layout_opts = { direction = "right" },
    layout = "scrolling",
})

-- workspace 3 is dwindle
hl.workspace_rule({
    workspace = 3,
    layout = "dwindle",
})

-- workspace 4 is floating
-- hl.window_rule({
--     match = {
--         workspace = 4
--     },
--     float = true
-- })

hl.window_rule({
    match = { workspace = 4 },
    float = true,
    size = "1200 800",
    move = "cursor -600 -400",   -- centers on cursor
})

hl.config({
    scrolling = {
        direction = "right",
        column_width = 0.333,
    }
})
