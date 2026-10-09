-- push to talk: discord's native module listens for keys via XWayland, so
-- inject X key events (replaces wayland-push-to-talk-fix).
--  * Inject XF86Tools (keycode 179), NOT F13/XF86Launch5. Xwayland's keymap is
--    a snapshot taken when xwayland starts, and what it contains for keycodes
--    191+ flips between sessions: sometimes F13/F14.. (kb_options
--    fkeys:basic_13-24 reached it), sometimes XF86Tools/XF86Launch5.. (it did
--    not). A keysym missing from the keymap makes xdotool remap a spare keycode
--    (8) on the fly, which discord reads as backspace. XF86Tools sits at 179 in
--    both layouts, so it always resolves to the same real keycode.
--    Check with `xmodmap -pke` if this ever breaks again.
--  * Press/release is driven from the raw key event, not bindr. A release bind
--    is skipped if any other key was pressed+released while F13 was held
--    (holding push to talk while hitting wasd), which left the key stuck down.
--  * Never hl.exec_cmd per key event: forking the compositor costs ~60ms of
--    its main thread (multi-GB RSS), which stutters the cursor on every
--    press. Instead one long-lived `xdotool -` reads commands from a fifo, and
--    we just write a line to it (a cheap, non-blocking write).
--  * The binds below only exist to consume F13 so apps never see it.
local PTT_KEYCODE = 191 -- XKB keycode: evdev KEY_F13 (183) + 8
local PTT_XKEY = "XF86Tools"
local FIFO = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hypr-ptt.fifo"
local ptt_down = false

-- ptt-helper.sh owns the fifo + the long-lived `xdotool -` reading it
local HELPER = "~/.local/bin/hypr/ptt-helper.sh"
local function helper(action)
    return string.format("%s %s '%s'", HELPER, action, FIFO)
end

local function xdo(cmd)
    -- "r+" opens O_RDWR, which never blocks even if the helper has died
    local f = io.open(FIFO, "r+")
    if not f then return end
    f:write(cmd, "\n")
    f:close()
end

local function release()
    if ptt_down then
        ptt_down = false
        xdo("keyup " .. PTT_XKEY)
    end
end

-- start is idempotent (reuses a healthy helper, replaces a dead/orphaned one)
local function start_helper() hl.exec_cmd(helper("start")) end
hl.on("hyprland.start", start_helper)

-- a reload tears down this lua state (ptt_down resets), so a key held across it
-- would stay down in X. The helper survives reloads, so just let go of it.
-- (there's no config.unload event in this hyprland version)
hl.on("config.reloaded", function()
    xdo("keyup " .. PTT_XKEY)
    start_helper()
end)

-- on exit also stop the helper; synchronous so it finishes before we're gone
hl.on("hyprland.shutdown", function()
    release()
    os.execute(helper("stop"))
end)

hl.on("input.keyboard.key", function(code, _, state)
    if code ~= PTT_KEYCODE then return end

    if state == 1 and not ptt_down then
        ptt_down = true
        xdo("keydown " .. PTT_XKEY)
    elseif state == 0 then
        release()
    end
end)

local ptt_consume_flags = {
    ignore_mods = true,
    dont_inhibit = true,
    allow_input_capture = true,
    transparent = true,
}
hl.bind("f13", function() end, ptt_consume_flags)
hl.bind("f13", function() end, {
    release = true,
    ignore_mods = true,
    dont_inhibit = true,
    allow_input_capture = true,
    transparent = true,
})
