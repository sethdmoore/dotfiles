-- See https://wiki.hypr.land/Configuring/Keywords/
-- see https://github.com/xkbcommon/libxkbcommon/blob/master/include/xkbcommon/xkbcommon-keysyms.h
mainMod = "SUPER"

hl.config({
    input = {
        kb_layout  = "us",
        kb_variant = "",
        kb_model   = "",
        kb_options = "",
        kb_rules   = "",

        follow_mouse = 1,
        -- -1.0 - 1.0, 0 means no modification.
        sensitivity = 0,

        touchpad = {
            natural_scroll = false,
        },
    },
})

local function layout_bind(bind_table)
    return function ()
        local workspace = hl.get_active_special_workspace() or
                          hl.get_active_workspace()

        if not workspace then
            return
        end

        local layout = workspace.tiled_layout
                
        if bind_table[layout] then
            hl.dispatch(bind_table[layout])
        end
    end
end

hl.bind(mainMod .. " + f10", function() 
    high_quality = not high_quality
    hl.exec_cmd('notify-send ' .. tostring(high_quality) )
    hl.exec_cmd('notify-send ' .. tostring(hl.config) )
end)

-- close app
-- hl.bind(mainMod .. " + q", hl.dsp.window.close(), { release = true })
hl.bind(mainMod .. " + q", hl.dsp.window.close())
-- kill -9 app, hold win+q
hl.bind(mainMod .. " + q", hl.dsp.window.kill(), { long_press = true, transparent = true })

hl.config({ binds = {
    -- swapping workspaces hides special / overlay / scratch workspaces
    -- nice, cause I don't always want to press the same bind
    hide_special_on_workspace_change = true,
    -- if your mouse is hidpi scroll or smooth scrolling,
    -- you may want to comment this out (defaults to 300)
    scroll_event_delay = 0,
} })

-- launcher shortcuts
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + t", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + f", hl.dsp.exec_cmd(browser_binding))
hl.bind(mainMod .. " + z", hl.dsp.exec_cmd(browser_binding))
hl.bind(mainMod .. " + SHIFT + f", hl.dsp.exec_cmd(browser_binding .." --private-window"))
hl.bind(mainMod .. " + e", hl.dsp.exec_cmd(fileManager))

hl.bind("SHIFT + CTRL + escape", hl.dsp.exec_cmd(taskManager))

-- hl.bind("f13", pass, class:^(electron)$  --  Pass MOUSE5 to TeamSpeak3.
hl.bind("f13", hl.dsp.send_shortcut({ mods = "", key = "F13", window = "class:vesktop" }))  -- Send SUPER + F4 to OBS when SUPER + F10 is pressed.
-- bind = , j, sendshortcut, ,F13, class:^(electron)$  # Pass MOUSE5 to TeamSpeak3.

-- toggle unfocused opacity
hl.bind(mainMod .. " + period", hl.dsp.window.tag({tag = "no_opacity"}))

-- lock / logout
hl.bind(mainMod .. " + SHIFT + q", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"), { long_press = true })
hl.bind(mainMod .. " + SHIFT + l", hl.dsp.exec_cmd("hyprlock -c /home/seth/.config/hypr/hyprlock.conf || notify-send 'not working'"), { long_press = true })

hl.bind(mainMod .. " + y", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + v", hl.dsp.layout("togglesplit"))
hl.bind(mainMod .. " + return", hl.dsp.window.fullscreen())

local dirs = { h = "left", j = "down", k = "up", l = "right"}
for key, dir in pairs(dirs) do
    -- vim focus
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ direction = dir }))

    -- vim swap window
    hl.bind(mainMod .. " + CTRL + " .. key, hl.dsp.window.swap({direction = dir}))

    -- arrow focus
    hl.bind(mainMod .. " + " .. dir,  hl.dsp.focus({ direction = dir }))

    -- arrow swap window
    hl.bind(mainMod .. " + CTRL + " .. dir, hl.dsp.window.swap({direction = dir}))

end

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace with mainMod + SHIFT + [0-9]
for i = 1, 6 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i}))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Example special workspace (scratchpad)
-- bind = $mainMod, S, togglespecialworkspace, magic

-- super-shift-s, like windows snipping tool

hl.bind("Print", hl.dsp.exec_cmd('grim -g "$(slurp)" - | swappy -f -'))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd('grim -g "$(slurp -d)" - | wl-copy'))

-- windows like binding for toggling hdr on / off
hl.bind(mainMod .. " + ALT + b", hl.dsp.exec_cmd("~/.local/bin/hypr/toggle_hdr.sh"))

-- discord "overlay"
-- bind = $mainMod SHIFT, grave, togglespecialworkspace, discord
hl.bind(mainMod .. " + grave", hl.dsp.workspace.toggle_special("overlay"))
hl.bind(mainMod .. " + 0", hl.dsp.workspace.toggle_special("overlay"))
hl.bind(mainMod .. " + SHIFT + grave",
        hl.dsp.window.move({ workspace = "special:overlay", follow = false }))

hl.bind(mainMod .. " + a", hl.dsp.workspace.toggle_special("scratch"))

hl.bind(mainMod .. " + SHIFT + a",
        hl.dsp.window.move({ workspace = "special:scratch", follow = false }))

-- Scroll through existing workspaces with mainMod SHIFT + scroll
hl.bind(mainMod .. " + SHIFT + mouse_down", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + SHIFT + mouse_up", hl.dsp.focus({ workspace = "e+1" }))

-- layout #2 / scrolling
hl.bind(mainMod .. "+ mouse_down", layout_bind({
    scrolling = hl.dsp.layout("move +col"),
}), { bypass_inhibit = true })

hl.bind(mainMod .. "+ mouse_up", layout_bind({
    scrolling = hl.dsp.layout("move -col"),
}), { bypass_inhibit = true })

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(mainMod .. " + minus", hl.dsp.window.resize({x = -250, y = -250, relative = true }))
hl.bind(mainMod .. " + equal", hl.dsp.window.resize({x = 250, y = 250, relative = true }))

-- Laptop multimedia keys for volume and LCD brightness
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { repeating = true, locked = true })
-- bindel = ,VolumeUp, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
-- bindel = ,114, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { repeating = true, locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { repeating = true, locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { repeating = true, locked = true })
-- bindel = ,XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+
-- bindel = ,XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-

-- Requires playerctl
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
