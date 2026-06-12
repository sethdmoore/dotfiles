local no_opacity = "1.0 override 1.0 override 1.0 override"

-- class = initial_title
local opacity_window_rules = {
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

for name, s in pairs(opacity_window_rules) do
    hl.window_rule({
        name = "no-opacity-" .. name,
        match = {
            class = s.class,
            initial_title = s.initial_title,
        },
        opacity = s.opacity,
        tag = "+no_opacity"
    })
end

hl.window_rule({
    name = "no-opacity-tags",
    match = {
        tag = "no_opacity",
    },
    opacity = no_opacity,
})
