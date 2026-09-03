-- Lay out every connected output, sorted by `priority` (init/constants.lua).
-- The lowest `priority` number is the primary: it sits at 0x0 and every
-- other output stacks straight down beneath it, so the monitors can never
-- overlap (docked, DP-1 the TV ends up directly above eDP-2). Each output
-- runs at its tuned mode/depth/scale from `displays`; an output with no
-- entry runs at whatever native mode Hyprland reports, SDR. Returns
-- { primary = <display>, others = { <display>, ... } } where each
-- <display> is { name, resolution, depth, scale, position }.
function detect_display()
    local mons = hl.get_monitors()
    if not mons or #mons == 0 then return nil end

    -- sort by priority (unknown outputs last), stable on Hyprland's order
    local order = {}
    for i, mon in ipairs(mons) do order[i] = { mon = mon, seq = i } end
    table.sort(order, function(a, b)
        local pa = (displays[a.mon.name] or {}).priority or math.huge
        local pb = (displays[b.mon.name] or {}).priority or math.huge
        if pa ~= pb then return pa < pb end
        return a.seq < b.seq
    end)

    local function tune(mon)
        local known = displays[mon.name]
        if known then
            return { name = mon.name, resolution = known.resolution,
                     depth = known.depth, scale = known.scale or 1 }
        end
        return { name = mon.name, depth = "sdr", scale = 1,
                 resolution = string.format("%dx%d@%g",
                     mon.width, mon.height, mon.refresh_rate) }
    end

    -- logical (post-scale) height of a "WIDTHxHEIGHT@RATE" mode string
    local function logical_height(d)
        local h = tonumber(tostring(d.resolution):match("x(%d+)")) or 0
        return math.floor(h / (d.scale or 1) + 0.5)
    end

    local primary = tune(order[1].mon)
    primary.position = "0x0"

    local others, y = {}, logical_height(primary)
    for i = 2, #order do
        local d = tune(order[i].mon)
        d.position = "0x" .. y
        y = y + logical_height(d)
        others[#others + 1] = d
    end

    return { primary = primary, others = others }
end

-- Startup-only fallback for when hl.get_monitors() comes back empty
-- (queried too early during launch): the highest-priority configured display.
local function preferred_configured_display()
    local best_name, best
    for dname, cfg in pairs(displays) do
        if not best or (cfg.priority or math.huge) < (best.priority or math.huge) then
            best_name, best = dname, cfg
        end
    end
    if not best_name then return nil end
    return {
        primary = { name = best_name, resolution = best.resolution,
                    depth = best.depth, scale = best.scale or 1, position = "0x0" },
        others = {},
    }
end

function set_resolution(t)
    local t = t or {}

    -- state file: persists a manual resolution/depth pick (the set_2k* /
    -- set_4k helper scripts) across `hyprctl reload` and wallpaper swaps,
    -- so we don't snap back to defaults on every reload. Line 3 records
    -- which output the pick was made for.
    local path = os.getenv("XDG_RUNTIME_DIR") .. "/hypr/"
        .. os.getenv("HYPRLAND_INSTANCE_SIGNATURE") .. "/resolution_state"

    local saved = {}
    if not t.resolution and not t.depth then
        local f = io.open(path, "r")
        if f then
            saved.resolution, saved.depth, saved.name =
                f:read("*l"), f:read("*l"), f:read("*l")
            f:close()
        end
    end

    -- live-detect the connected outputs; only fall back to a configured
    -- display on the very first call (Hyprland may report none that early)
    local layout = detect_display()
    if not layout and t.initial then
        layout = preferred_configured_display()
    end
    if not layout then
        assert(not t.initial,
            "monitors.lua: no connected monitor detected and `displays` is empty")
        return  -- nothing connected; a later monitor.added event will retry
    end

    local primary = layout.primary

    -- restore the saved manual pick only if it was made for this same
    -- primary; after a monitor change, use the detected tuned mode
    if saved.name == primary.name then
        t.resolution = t.resolution or saved.resolution
        t.depth = t.depth or saved.depth
    end
    setmetatable(t, {__index = {resolution = primary.resolution, depth = primary.depth}})

    -- push one monitor's config; `depth` is "hdr" or "sdr"
    local function apply(name, resolution, depth, scale, position)
        local m = {
            output = name,
            mode = resolution,
            position = position or "0x0",
            scale = scale or 1,
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

        hl.monitor(m)
    end

    -- primary at 0x0 (honouring any manual override), the rest stacked below
    apply(primary.name, t.resolution, t.depth, primary.scale, primary.position)
    for _, d in ipairs(layout.others) do
        apply(d.name, d.resolution, d.depth, d.scale, d.position)
    end

    -- persist for this session, tagged with the primary it applies to
    local f = io.open(path, "w")
    if f then
        f:write((t.resolution or ""), "\n", (t.depth or ""), "\n", primary.name)
        f:close()
    end
end

set_resolution({ initial = true })

-- re-lay-out when the set of connected outputs changes (docking /
-- undocking) without a manual reload. The signature check swallows any
-- events Hyprland re-emits while we're applying the new layout, so this
-- can't spin in a loop.
local function connected_sig()
    local mons = hl.get_monitors() or {}
    local names = {}
    for _, mon in ipairs(mons) do names[#names + 1] = mon.name end
    table.sort(names)
    return table.concat(names, ",")
end

local last_sig = connected_sig()
local function relayout_on_change()
    local sig = connected_sig()
    if sig == last_sig then return end
    last_sig = sig
    set_resolution()
end

hl.on("monitor.added", relayout_on_change)
hl.on("monitor.removed", relayout_on_change)

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
