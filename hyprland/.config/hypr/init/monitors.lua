-- Choose exactly ONE output to drive and switch every other output off.
-- Of the connected outputs we have a `displays` entry for
-- (init/constants.lua), the one with the lowest `priority` number wins and
-- gets its tuned mode/depth/scale; an output with no entry is driven at
-- the native mode Hyprland reports, SDR.
--
-- Returns one of:
--   { primary = { name, resolution, depth, scale }, off = { name, ... } }
--   { reenable_all = true }   -- nothing is on; turn every known output
--                                back on and let monitor.added re-select
function detect_display()
    local connected = hl.get_monitors() or {}

    -- rank: lowest `priority` number first, unknown outputs after every
    -- known one, ties on Hyprland's own ordering
    local ranked = {}
    for i, mon in ipairs(connected) do ranked[i] = { mon = mon, seq = i } end
    table.sort(ranked, function(a, b)
        local pa = (displays[a.mon.name] or {}).priority or math.huge
        local pb = (displays[b.mon.name] or {}).priority or math.huge
        if pa ~= pb then return pa < pb end
        return a.seq < b.seq
    end)

    if not ranked[1] then
        -- Hyprland reports no active output: fresh startup, or we just
        -- disabled the last one while undocking. Ask every configured
        -- output back on; whichever physically exists lights up and
        -- re-triggers selection via monitor.added.
        return { reenable_all = true }
    end

    local top = ranked[1].mon
    local known = displays[top.name]
    local primary
    if known then
        primary = { name = top.name, resolution = known.resolution,
                    depth = known.depth, scale = known.scale or 1 }
    else
        primary = { name = top.name, depth = "sdr", scale = 1,
                    resolution = string.format("%dx%d@%g",
                        top.width, top.height, top.refresh_rate) }
    end

    local off = {}
    for i = 2, #ranked do off[#off + 1] = ranked[i].mon.name end

    return { primary = primary, off = off }
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

    -- turn one output on (with its tuned mode/depth/scale) or, with
    -- on == false, off. Everything lands at 0x0 -- only one output is ever
    -- enabled, so there is nothing to lay out.
    local function apply(name, resolution, depth, scale, on)
        if on == false then
            hl.monitor({ output = name, disabled = true })
            return
        end

        local m = {
            output = name,
            mode = resolution,
            position = "0x0",
            scale = scale or 1,
            disabled = false,
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

    local layout = detect_display()

    if layout.reenable_all then
        -- nothing is on. Light every configured output back up; the one
        -- that physically exists fires monitor.added and re-runs selection.
        assert(next(displays) or not t.initial,
            "monitors.lua: no connected monitor detected and `displays` is empty")
        for name, cfg in pairs(displays) do
            apply(name, cfg.resolution, cfg.depth, cfg.scale, true)
        end
        return
    end

    local primary = layout.primary

    -- restore the saved manual pick only if it was made for this same
    -- primary; after a monitor change, use the detected tuned mode
    if saved.name == primary.name then
        t.resolution = t.resolution or saved.resolution
        t.depth = t.depth or saved.depth
    end
    setmetatable(t, {__index = {resolution = primary.resolution, depth = primary.depth}})

    -- chosen output on, every other connected output off
    apply(primary.name, t.resolution, t.depth, primary.scale, true)
    for _, name in ipairs(layout.off) do
        apply(name, nil, nil, nil, false)
    end

    -- persist for this session, tagged with the primary it applies to
    local f = io.open(path, "w")
    if f then
        f:write((t.resolution or ""), "\n", (t.depth or ""), "\n", primary.name)
        f:close()
    end
end

set_resolution({ initial = true })

-- re-run selection whenever the set of connected outputs changes (docking,
-- undocking, and the individual monitor.added events during login) without
-- a manual reload.
--
-- Loop guard: selection settles on "one output enabled, the rest
-- disabled". Our own disable calls fire more monitor events, but each
-- re-run then sees a signature it has already acted on and stops. It is
-- deliberately NOT seeded, so the first events after config parse -- when
-- Hyprland brings the real monitors up -- always run once.
local function connected_sig()
    local mons = hl.get_monitors() or {}
    local names = {}
    for _, mon in ipairs(mons) do names[#names + 1] = mon.name end
    table.sort(names)
    return table.concat(names, ",")
end

local last_sig = nil
local function reselect_on_change()
    local sig = connected_sig()
    if sig == last_sig then return end
    last_sig = sig
    set_resolution()
end

hl.on("monitor.added", reselect_on_change)
hl.on("monitor.removed", reselect_on_change)

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
