-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
-- https://wiki.hypr.land/Configuring/Variables/#decoration

hl.config({
    general = {
        gaps_in  = 15,
        gaps_out = 20,

        border_size = 2,

        col = {
            active_border = {
                colors = {
                    "rgba(33ccffee)", "rgba(00ff99ee)"
            }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        -- Set to true to enable resizing windows by clicking and dragging on borders and gaps
        resize_on_border = false,

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,

        layout = "dwindle",
    },

    -- enabled due to 0.55+ not working with blur
    render = {
        use_shader_blur_blend = true,
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        -- Change transparency of focused and unfocused windows
        active_opacity   = 1.0,
        inactive_opacity = 0.85,

        shadow = {
            enabled      = true,
            range        = 32,
            render_power = 3,
            color        = 0xee1a1a1a,
        },

        blur = {
            enabled   = true,
            size      = 4,
            passes    = 3,
            vibrancy  = 0.1696,
            special = false,
            --popups = true,
        },
    },

    animations = {
        enabled = true,
    },
})

hl.layer_rule({
    blur = true,
    match = { namespace = '(?i)^noctalia-(notification|dock|bar|panel).*' },
    ignore_alpha = 0.5,
})
