-- AUTO-GENERATED from a hyprlang .conf by hypr2lua.py
-- Review carefully. Unverified dispatchers were converted to
-- hl.dsp.exec_raw("...") fallbacks; lines flagged with TODO
-- need a manual check against https://wiki.hypr.land/Configuring/Basics/

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



hl.window_rule({
    name = "untag-installer",
    match = {
        initial_class = "^(?i).*(steam_app_0|install).*$",
    },
    suppress_event = "fullscreen maximize fullscreenoutput",
    keep_aspect_ratio = true,
    size = {1920, 1080},
    float = true,
})

