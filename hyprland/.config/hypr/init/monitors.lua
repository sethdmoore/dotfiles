-- Ask Hyprland (via the built-in hl.get_monitors() query, no subprocess)
-- which monitor is actually connected right now, and look it up in the
-- `displays` table (init/constants.lua) for its tuned mode/depth. A
-- monitor we don't have an entry for still works: we fall back to
-- whatever native mode Hyprland reports for it, just without a specific
-- depth preference.
function detect_display()
    local mons = hl.get_monitors()
    if not mons or #mons == 0 then return nil end

    local mon = mons[1]
    local known = displays[mon.name]
    if known then
        return { name = mon.name, resolution = known.resolution, depth = known.depth }
    end
    return {
        name = mon.name,
        resolution = string.format("%dx%d@%g", mon.width, mon.height, mon.refresh_rate),
        depth = "sdr",
    }
end

function set_resolution(t)
    local t = t or {}

    -- state file for persisting session resolution changes
    -- essentially don't change our resolution every time our bg changes / hyprctl reload
    local path = os.getenv("XDG_RUNTIME_DIR") .. "/hypr/"
        .. os.getenv("HYPRLAND_INSTANCE_SIGNATURE") .. "/resolution_state"

    -- read state if there are no arguments
    if not t.resolution and not t.depth then
        local f = io.open(path, "r")
        if f then
            t.resolution, t.depth = f:read("*l"), f:read("*l")
            f:close()
        end
    end

    -- live-detect the connected monitor; if Hyprland reports none yet (e.g.
    -- too early in startup), fall back to the first configured display
    local active = detect_display()
    if not active then
        local name, cfg = next(displays)
        active = name and { name = name, resolution = cfg.resolution, depth = cfg.depth }
    end
    assert(active, "monitors.lua: no connected monitor detected and `displays` is empty")

    -- function default arguments
    setmetatable(t, {__index={resolution=active.resolution, depth=active.depth}})
    local resolution, depth =
        t.resolution, t.depth

    local m = {
        output = active.name,
        mode = resolution,
        position = "0x0",
        scale = 1,
    }

    if depth == "hdr" then
        m.bitdepth = 10
        m.cm = "hdredid"

        -- 0: off, 1: on, 2: fullscreen only, 3: video/game content fullscreen
        m.vrr = 0
        m.supports_hdr = 0
        m.supports_wide_color = 0
        m.min_luminance = 0
        m.max_luminance = 3000
        m.sdr_min_luminance = 0
        m.sdr_max_luminance = 300
        m.sdrsaturation = 1.0
        m.sdrbrightness = 1.2
        -- m.sdr_max_luminance = 3000
        -- m.sdrbrightness = 1.0
        -- m.sdrsaturation = 0.85
    else
        m.bitdepth = 8
        m.cm = "auto"
        m.vrr = 0
    end

    -- write our state file for this session
    local f = io.open(path, "w")
    if f then
        f:write(resolution, "\n", depth)
        f:close()
    end

    hl.monitor(m)
end

set_resolution()
-- set_resolution({resolution = '2560x1440@120', depth = "hdr"})
-- set_resolution({resolution = displays["HDMI-A-1"].resolution, depth = "hdr"})
-- set_resolution({resolution = displays["HDMI-A-1"].resolution, depth = "sdr"})

hl.config({ render = {
    -- 0 - disabled
    -- 1 - on
    -- 2 - auto (enabled in HDR with SDR modifiers). Set to 1 if screenshots are transparent. (default)
    keep_unmodified_copy = 0,
    -- on 595.43, there's graphical corruption with direct_scanout = 2
    -- combination of factors: gamescope, reverse tonemapping (fine),
    --   but issuing super+enter, fullscreen / no fullscreen causes graphical glitches
    --   rubinite: black screen on fullscreen (alt+enter / super enter / settings)
    --   wayfinder: black screen on fullscreen (alt+enter / super enter / settings)
    --  0 disabled / 1 on / 2 auto (content type game)
    direct_scanout = 0,

    -- 2 - low latency with content type 'game'
    -- 1 - on if fullscreen
    send_content_type = true,

    -- Default transfer function for displaying SDR apps
    -- "default" - Use default value (sRGB)
    -- "gamma22" - Treat unspecified as Gamma 2.2
    -- "gamma22force" - Treat unspecified and sRGB as Gamma 2.2
    -- "srgb" - Treat unspecified as sRGB
    cm_sdr_eotf = "srgb",

    -- Enable CM without shader
    -- 0 - disable
    -- 1 whenever possible,
    -- 2 - DS and passthrough only
    -- 3 - disable and ignore CM issues (default)
    non_shader_cm = 3,

    -- Auto-switch to HDR in fullscreen when needed.
    -- 0 - off
    -- 1 - switch to cm hdr (default)
    -- 2 - switch to cm, hdredid
    -- Currently borked, causes games to flip the monitor to SDR
    --   fullscreen becomes a black screen momentarily
    --   really annoying, leave off
     cm_auto_hdr = 0
}})
