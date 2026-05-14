hl.monitor({
    output = mainMonitor,
    mode = fourk,
    position = "0x0",
    scale = 1,
    bitdepth = 10,
    cm = "hdredid",
    supports_hdr = 0,
    vrr = 3,
        -- flag | mode 
        -- 0    | off
        -- 1    | on
        -- 2    | fullscreen
        -- 3    | tag +video/+game
        -- vrr = 3
    supports_wide_color = 0,
    min_luminance = 0.002,
    max_luminance = 1000,
    sdr_max_luminance = 200,
    sdr_min_luminance = 0.05,
    sdrbrightness = 1.0,
    sdrsaturation = 1.0,
})

hl.config({ render = {
    keep_unmodified_copy = 1,
    direct_scanout = 2,
      -- 2 - low latency with content type 'game'
      -- 1 - on if fullscreen
    send_content_type = true,
    cm_sdr_eotf = "srgb",
    non_shader_cm = 0,
}})
