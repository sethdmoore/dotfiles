local no_opacity = "1.0 override 1.0 override 1.0 override"

-- class = initial_title
local no_opacity_windows = {
    ["app.zen_browser.zen"] = "^(?i)Picture-in-Picture$",
    ["firefox"] = "^(?i)Picture-in-Picture$",
    ["zoom"] = "^(?i)meeting$",
    ["org.kde.krita"] = "Krita",
    ["google-chrome"] = ".*",
}

-- class = initial_title
local window_rules = {
    firefox = {
        class = "app.zen_browser.zen",
        initial_title = "^(?i)Picture-in-Picture$",
        opacity = no_opacity,
    },
    zen = {
        class = "firefox",
        initial_title = "^(?i)Picture-in-Picture$",
        opacity = no_opacity,
    },
    zoom = {
        class = "zoom",
        initial_title = "^(?i)meeting$",
        opacity = no_opacity,
    },
    krita = {
        class = "org.kde.krita",
        initial_title = "Krita",
        opacity = no_opacity,
    },
    chrome = {
        class = "google-chrome",
        initial_title = ".*",
        opacity = no_opacity,
    },
}

for name, s in pairs(window_rules) do
    hl.window_rule({
        name = "no-opacity-" .. name,
        match = {
            class = s.class,
            initial_title = s.initial_title,
        },
        opacity = s.opacity,
    })
end

-- hl.window_rule({
--     name = "no-opacity-krita",
--     match = {
--         class = "org.kde.krita",
--         initial_title = "Krita",
--     },
--     opacity = no_opacity,
-- })

