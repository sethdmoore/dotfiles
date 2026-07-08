-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
-- https://wiki.hypr.land/Configuring/Variables/#decoration
function get_gaps_out()
    return 20
end

function get_gaps_in()
    return 15
end

hl.config({
    general = {
        gaps_in  = get_gaps_in(),
        gaps_out = get_gaps_out(),

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
    -- render = {
    --     use_shader_blur_blend = true,
    -- },

    decoration = {
        rounding       = 18,
        rounding_power = 2,

        -- Change transparency of focused and unfocused windows
        active_opacity   = active_opacity,
        inactive_opacity = inactive_opacity,

        shadow = {
            enabled      = false,
            range        = 32,
            render_power = 3,
            color        = 0xff1a1a1a,
        },

        glow = {
            enabled = false,
            range = 30,
            render_power = 5,
            color = 0xcccc3322,
            color_inactive = 0xffffffff
        },

        blur = {
            enabled   = high_quality,
            size      = 5,
            passes    = 3,
            -- vibrancy  = 0.1696,
            special = false,
            --popups = true,
        },
    },
})

hl.layer_rule({
    blur = high_quality,
    match = { namespace = '(?i)^noctalia-(notification|dock|bar|panel).*' },
    ignore_alpha = 0.5,
})
