local no_opacity = "1.0 override 1.0 override 1.0 override"

-- class = initial_title
local no_opacity_windows = {
    firefox = "^(?i)Picture-in-Picture$",
    zoom = "^(?i)meeting$",
}

for class, title in pairs(no_opacity_windows) do
    hl.dsp.exec_cmd("notify-send " .. class .. " " .. title)
    hl.window_rule({
        name = "no-opacity-" .. class,
        match = {
            class = class,
            initial_title = title,
        },
        opacity = no_opacity,
    })
end

-- hl.window_rule({
--     name = "nte-vrr-flicker",
--     match = {
--         title = "^NTE.*$",
--     },
--     tag = "+novrr",
-- })
