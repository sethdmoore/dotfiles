-- Pick exactly one output to drive, from whatever is connected right now.
--
-- `hl.get_monitors()` is the built-in query (no subprocess). Among the
-- connected outputs we have a `displays` entry for (init/constants.lua),
-- the one with the lowest `priority` number wins and gets its tuned
-- mode / depth / scale. Every other connected output is returned in
-- `.disable` so set_resolution() can switch it off -- this is what lets
-- the laptop dock/undock without hand-editing a "main monitor" constant.
-- An output with no `displays` entry still works: it's driven at the
-- native mode Hyprland reports, with no depth preference.
function detect_display()
    local mons = hl.get_monitors()
    if not mons or #mons == 0 then return nil end

    -- lowest priority number wins; unknown outputs sort last; ties break
    -- on the order Hyprland lists them
    local best
    for _, mon in ipairs(mons) do
        local prio = (displays[mon.name] or {}).priority or math.huge
        if not best or prio < best.prio then
            best = { mon = mon, prio = prio }
        end
    end

    local name = best.mon.name
    local known = displays[name]
    local chosen
    if known then
        chosen = { name = name, resolution = known.resolution,
                   depth = known.depth, scale = known.scale or 1 }
    else
        chosen = {
            name = name,
            resolution = string.format("%dx%d@%g",
                best.mon.width, best.mon.height, best.mon.refresh_rate),
            depth = "sdr",
            scale = 1,
        }
    end

    -- anything else that's connected gets turned off
    chosen.disable = {}
    for _, mon in ipairs(mons) do
        if mon.name ~= name then
            chosen.disable[#chosen.disable + 1] = mon.name
        end
    end
    return chosen
end

-- Highest-priority configured display; a startup-only fallback for when
-- hl.get_monitors() comes back empty (queried too early during launch).
local function preferred_configured_display()
    local best_name, best
    for dname, cfg in pairs(displays) do
        if not best or (cfg.priority or math.huge) < (best.priority or math.huge) then
            best_name, best = dname, cfg
        end
    end
    if not best_name then return nil end
    return {
        name = best_name, resolution = best.resolution,
        depth = best.depth, scale = best.scale or 1, disable = {},
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

    -- live-detect the connected monitor; only fall back to a configured
    -- display on the very first call (Hyprland may report none that early)
    local active = detect_display()
    if not active and t.initial then
        active = preferred_configured_display()
    end
    if not active then
        assert(not t.initial,
            "monitors.lua: no connected monitor detected and `displays` is empty")
        return  -- nothing connected; a later monitor.added event will retry
    end

    -- restore the saved manual pick only if it was made for this same
    -- output; after a monitor change, use the detected display's tuned mode
    if saved.name == active.name then
        t.resolution = t.resolution or saved.resolution
        t.depth = t.depth or saved.depth
    end

    -- function default arguments
    setmetatable(t, {__index={resolution=active.resolution, depth=active.depth}})
    local resolution, depth =
        t.resolution, t.depth

    local m = {
        output = active.name,
        mode = resolution,
        position = "0x0",
        scale = active.scale or 1,
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

    -- persist for this session, tagged with the output it applies to
    local f = io.open(path, "w")
    if f then
        f:write(resolution or "", "\n", depth or "", "\n", active.name)
        f:close()
    end

    hl.monitor(m)

    -- switch off every other connected output (e.g. the laptop panel while
    -- docked to the TV)
    for _, name in ipairs(active.disable or {}) do
        hl.monitor({ output = name, disabled = true })
    end
end

set_resolution({ initial = true })

-- re-pick when an output is plugged in or unplugged, so docking /
-- undocking the laptop switches monitors without a manual reload
hl.on("monitor.added", function() set_resolution() end)
hl.on("monitor.removed", function()
    -- undocking removes the TV; make sure the built-in panel (and any
    -- other known output) is back on before re-picking
    for name in pairs(displays) do
        hl.monitor({ output = name, disabled = false })
    end
    set_resolution()
end)

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
