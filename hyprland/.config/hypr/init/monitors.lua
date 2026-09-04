-- Drive exactly ONE output at a time, chosen by a fixed order:
-- the first entry of `display_order` (init/constants.lua) that is actually
-- connected wins and gets its tuned mode/depth/scale from `displays`; every
-- other configured output is switched off.
--
--   DP-1      -> framework docked  (external only, outranks the panel)
--   HDMI-A-1  -> seth.home desktop (sole display)
--   eDP-2     -> framework laptop  (built-in only)
--
-- No ranking, no per-output priority numbers. To add a monitor, add it to
-- `displays` and slot its name into `display_order`.

-- A manual resolution/depth override (the set_2k* / set_4k helper scripts,
-- or Sunshine's stream prep-cmd) is stashed here so it survives `hyprctl
-- reload` and noctalia wallpaper swaps. Instance-scoped: a full Hyprland
-- restart starts clean, and any real dock/undock clears it too.
local override_path = os.getenv("XDG_RUNTIME_DIR") .. "/hypr/"
    .. os.getenv("HYPRLAND_INSTANCE_SIGNATURE") .. "/monitor-override"

local function read_override()
    local f = io.open(override_path, "r")
    if not f then return nil end
    local mode, depth = f:read("*l"), f:read("*l")
    f:close()
    if not mode or mode == "" then return nil end
    return { resolution = mode, depth = (depth and depth ~= "" and depth) or nil }
end

-- turn one output on (with its tuned mode/depth/scale) or, with on == false,
-- off. Everything lands at 0x0 -- only one output is ever enabled, so there
-- is nothing to lay out.
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

local function pick(connected)
    for _, name in ipairs(display_order) do
        if connected[name] then return name end
    end
end

local function current_primary()
    local connected = {}
    for _, mon in ipairs(hl.get_monitors() or {}) do
        connected[mon.name] = mon
    end
    return pick(connected)
end

-- chosen output on (override mode if one is stashed, otherwise the tuned
-- default), every other configured output off
local function apply_primary(primary)
    local cfg = displays[primary]
    local o = read_override()
    apply(primary,
        o and o.resolution or cfg.resolution,
        o and o.depth or cfg.depth,
        cfg.scale, true)
    for name in pairs(displays) do
        if name ~= primary then apply(name, nil, nil, nil, false) end
    end
end

-- re-run selection whenever the set of connected outputs changes (docking,
-- undocking, the individual monitor.added events during login) without a
-- manual reload.
--
-- Guard: `last_primary` is the output we last enabled. Our own disable
-- calls fire more monitor events, but those re-runs see the same primary
-- and stop. It is deliberately NOT seeded, so the first run after config
-- parse always applies.
local last_primary = nil

local function select()
    local primary = current_primary()

    if not primary then
        -- Nothing we know about is on: fresh startup, or we just undocked
        -- while the built-in panel was still disabled. Turn every configured
        -- output back on; whichever physically exists lights up and
        -- re-triggers selection via monitor.added.
        for name in pairs(displays) do
            hl.monitor({ output = name, disabled = false })
        end
        return
    end

    if primary == last_primary then return end
    if last_primary ~= nil then
        -- a genuine dock/undock -- the stashed override was for the old
        -- screen, drop it so the new one comes up at its tuned default
        os.remove(override_path)
    end
    last_primary = primary
    apply_primary(primary)
end

-- Entry points for the helper scripts and Sunshine's prep-cmd, via
-- `hyprctl eval 'monitor_override("2560x1440@120", "hdr")'` /
-- `hyprctl eval 'monitor_revert()'`. Global on purpose: eval runs in this
-- same Lua state and resolves them by name.
function monitor_override(mode, depth)
    local f = io.open(override_path, "w")
    if f then
        f:write(mode or "", "\n", depth or "", "\n")
        f:close()
    end
    local primary = current_primary()
    if primary then apply_primary(primary) end
end

function monitor_revert()
    os.remove(override_path)
    local primary = current_primary()
    if primary then apply_primary(primary) end
end

select()
hl.on("monitor.added", select)
hl.on("monitor.removed", select)

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
