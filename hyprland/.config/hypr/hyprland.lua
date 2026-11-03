-- https://wiki.hypr.land/Configuring/
require("init/constants")
require("init/environment")
require("init/monitors")
require("init/hl_config")
require("init/autostart")

require("appearance/style")
require("appearance/animations")

require("input/keyboard")
require("input/bindings")
require("input/pushtotalk")
require("input/gestures")

require("layouts/workspaces")

require("window_rules/add_tags")
require("window_rules/rules")
require("window_rules/quirks")
-- require("window_rules/k724")

-- For Noctalia Color templates
local noctalia = require("noctalia")
noctalia.apply_theme()

-- Active border as an animated gradient (rotated by the "borderangle" animation).
-- Built from Noctalia's own palette so it stays in-theme.
hl.config({
    general = {
        col = {
            active_border = {
                colors = { noctalia.colors.primary, noctalia.colors.secondary },
                angle = 45,
            },
        },
    },
})
