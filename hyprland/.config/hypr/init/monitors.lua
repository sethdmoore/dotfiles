-- Priority-ranked monitor selection, matched by EDID description (not output
-- port -- port names shift between GPUs, docks and boots).
--
-- `displays` / `display_order` live in init/constants.lua. Each time the set
-- of outputs changes we pick a PRIMARY: the first entry of `display_order`
-- whose `match.description` is a prefix of a connected output's description.
-- Then:
--
--   * primary has single_monitor    -> it is the ONLY output; every other
--                                      configured output is switched off.
--   * primary has no single_monitor -> primary at 0x0, plus every other
--                                      connected non-single_monitor display
--                                      laid out left-to-right in display_order;
--                                      configured single_monitor displays that
--                                      are not primary stay off.
--
-- Matching is DESCRIPTION PREFIX, the same rule Hyprland's `desc:` selector
-- uses. Read descriptions with:
--     hyprctl monitors all -j | jq -r '.[].description'
--
-- Note: hl.get_monitors() and the Lua monitor objects only expose .name,
-- .description and .serial (no split .make / .model), and the config Lua
-- state CANNOT shell out to `hyprctl` (it runs on the main thread and would
-- deadlock its own IPC). So everything here works off live monitor objects
-- plus the object handed to the monitor.added event.

-- ---------------------------------------------------------------------------
-- manual override (helper scripts / Sunshine prep-cmd)
-- ---------------------------------------------------------------------------
-- set_2k* / set_4k and Sunshine stash a resolution/depth override for the
-- PRIMARY here so it survives `hyprctl reload` and noctalia wallpaper swaps.
-- Instance-scoped: a full Hyprland restart starts clean, and a genuine
-- primary change (dock/undock) clears it.
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

-- ---------------------------------------------------------------------------
-- matching
-- ---------------------------------------------------------------------------

-- description prefix test -- mirrors Hyprland's `desc:` selector
local function desc_matches(description, prefix)
    if not description or not prefix then return false end
    return description:sub(1, #prefix) == prefix
end

-- friendly-name key of the `displays` entry this monitor object matches, or nil.
-- When several prefixes match (e.g. a generic "... HISENSE" and a specific
-- "... HISENSE 0x616D0000"), the LONGEST prefix wins, so specific entries
-- are never shadowed by generic ones regardless of pairs() order.
local function key_for(mon)
    local best, best_len = nil, -1
    for name, cfg in pairs(displays) do
        local prefix = cfg.match and cfg.match.description
        if prefix and desc_matches(mon.description, prefix) and #prefix > best_len then
            best, best_len = name, #prefix
        end
    end
    return best
end

-- ---------------------------------------------------------------------------
-- applying
-- ---------------------------------------------------------------------------

-- leading pixel count of a "3840x2160@144" mode string, as a number
local function mode_width(resolution)
    return tonumber((resolution or ""):match("^(%d+)")) or 0
end

-- logical (scaled) width this display occupies in the layout
local function logical_width(cfg)
    return math.floor(mode_width(cfg.resolution) / (cfg.scale or 1) + 0.5)
end

-- What we last told Hyprland for each output name: a signature string, or
-- "off". Our own hl.monitor() calls fire fresh monitor.added / monitor.removed
-- events; those re-runs recompute the SAME signatures and short-circuit here,
-- so the cascade terminates. NOT seeded -- the first pass always applies.
local applied = {}

local function apply(name, cfg, x)
    local depth = cfg.depth or "sdr"
    local scale = cfg.scale or 1
    local sig   = table.concat({ cfg.resolution, x, scale, depth }, "|")
    if applied[name] == sig then return end
    applied[name] = sig

    local m = {
        output   = name,
        mode     = cfg.resolution,
        position = x .. "x0",
        scale    = scale,
        disabled = false,
        vrr      = 0,
    }

    if depth == "hdr" then
        m.bitdepth = 10
        m.cm = "hdredid"

        -- 0: off, 1: on, 2: fullscreen only, 3: video/game content fullscreen
        m.vrr = 3
        m.supports_hdr = 0
        m.supports_wide_color = 0
        m.min_luminance = 0
        m.max_luminance = 3000
        -- m.max_luminance = 3000
        m.sdr_min_luminance = 0
        m.sdr_max_luminance = 300
        m.sdrsaturation = 1.0
        m.sdrbrightness = 1.2
        -- m.sdr_max_luminance = 3000
        -- m.sdrbrightness = 1.0
        -- m.sdrsaturation = 0.85
    else
        m.bitdepth = 8
        m.cm       = "auto"
    end

    hl.monitor(m)
end

local function disable(name)
    if applied[name] == "off" then return end
    applied[name] = "off"
    hl.monitor({ output = name, disabled = true })
end

-- ---------------------------------------------------------------------------
-- selection
-- ---------------------------------------------------------------------------

-- Every connected output we can name right now: the enabled set, plus the one
-- that just announced itself (hl.get_monitors() only reports ENABLED outputs,
-- so a monitor we are about to judge on monitor.added is not in it yet).
local function candidates(added)
    local list, seen = {}, {}
    for _, mon in ipairs(hl.get_monitors() or {}) do
        seen[mon.name] = true
        list[#list + 1] = mon
    end
    if added and added.name and not seen[added.name] then
        list[#list + 1] = added
    end
    return list
end

-- highest-priority display_order key that some candidate matches
local function primary_key(cands)
    local present = {}
    for _, mon in ipairs(cands) do
        local k = key_for(mon)
        if k then present[k] = true end
    end
    for _, name in ipairs(display_order) do
        if present[name] then return name end
    end
end

-- output name of the candidate matching `key`, or nil
local function name_of(cands, key)
    for _, mon in ipairs(cands) do
        if key_for(mon) == key then return mon.name end
    end
end

local last_primary = nil

local function select(added)
    local cands = candidates(added)
    local pkey  = primary_key(cands)

    if not pkey then
        -- Nothing we recognise is on. If some output is still lit, leave it
        -- alone; if the screen is truly dark (just undocked a single_monitor
        -- primary), poke every configured output back on and let whichever
        -- physically exists re-drive selection via monitor.added.
        if #cands == 0 then
            for _, cfg in pairs(displays) do
                if cfg.match and cfg.match.description then
                    hl.monitor({ output = "desc:" .. cfg.match.description, disabled = false })
                end
            end
        end
        return
    end

    local pname = name_of(cands, pkey)
    if not pname then return end

    -- a genuine primary change invalidates the stashed override
    if last_primary and last_primary ~= pkey then os.remove(override_path) end
    last_primary = pkey

    -- primary's effective config (override mode/depth folded in)
    local pcfg = displays[pkey]
    local o    = read_override()
    local peff = {
        resolution     = o and o.resolution or pcfg.resolution,
        depth          = o and (o.depth or pcfg.depth) or pcfg.depth,
        scale          = pcfg.scale,
        single_monitor = pcfg.single_monitor,
    }

    -- desired layout: output name -> { cfg, x }
    local want = { [pname] = { cfg = peff, x = 0 } }

    if not pcfg.single_monitor then
        local x = logical_width(peff)
        for _, name in ipairs(display_order) do
            local cfg = displays[name]
            if name ~= pkey and cfg and not cfg.single_monitor then
                local mname = name_of(cands, name)
                if mname then
                    want[mname] = { cfg = cfg, x = x }
                    x = x + logical_width(cfg)
                end
            end
        end
    end

    -- enable everything wanted, disable every other candidate
    for name, w in pairs(want) do
        apply(name, w.cfg, w.x)
    end
    for _, mon in ipairs(cands) do
        if not want[mon.name] then disable(mon.name) end
    end
end

-- ---------------------------------------------------------------------------
-- helper-script entry points, via
--   hyprctl eval 'monitor_override("2560x1440@120", "hdr")'
--   hyprctl eval 'monitor_revert()'
-- Global on purpose: eval runs in this same Lua state and resolves them by name.
-- ---------------------------------------------------------------------------
function monitor_override(mode, depth)
    local f = io.open(override_path, "w")
    if f then
        f:write(mode or "", "\n", depth or "", "\n")
        f:close()
    end
    applied = {}   -- force re-apply with the new override mode
    select(nil)
end

function monitor_revert()
    os.remove(override_path)
    applied = {}
    select(nil)
end

-- Force a genuine re-application of the current config (bypassing the
-- `applied` signature cache that makes plain `hyprctl reload` a no-op when
-- nothing has changed). Works around HDR not sticking on the first commit
-- at boot -- see autostart.lua.
function monitor_reapply()
    applied = {}
    select(nil)
end

select(nil)
hl.on("monitor.added", function(m) select(m) end)
hl.on("monitor.removed", function(m)
    if m and m.name then applied[m.name] = nil end
    select(nil)
end)

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
    -- direct_scanout = 2,

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
