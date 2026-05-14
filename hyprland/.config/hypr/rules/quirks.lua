-- AUTO-GENERATED from a hyprlang .conf by hypr2lua.py
-- Review carefully. Unverified dispatchers were converted to
-- hl.dsp.exec_raw("...") fallbacks; lines flagged with TODO
-- need a manual check against https://wiki.hypr.land/Configuring/Basics/

hl.window_rule({
    name = "nte-floating-diags",
    match = {
        title = "^(?i)application\\ hang\\ detected*$",
    },
    tag = "+floating",
})

hl.window_rule({
    match = {
        title = "^(?i)NTEGlobalGame.*$",
    },
    no_initial_focus = true,
    tag = "+floating",
})

hl.window_rule({
    name = "nte-vrr-flicker",
    match = {
        title = "^NTE.*$",
    },
    tag = "+novrr",
})
