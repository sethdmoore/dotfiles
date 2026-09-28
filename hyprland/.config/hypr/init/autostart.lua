onstart_commands = {
  -- graphical session
  "systemctl --user start hyprland-session.target",
  -- TODO: systemd unit?
  -- 7.2+ kernel
  -- "push-to-talk -k KEY_F13 -n F13 /dev/input/by-id/usb-Logitech_USB_Receiver-if02-event-mouse &",
  -- 6.18+ kernel
  "sleep 3; push-to-talk -k KEY_F13 -n F13 /dev/input/by-id/usb-Logitech_USB_Receiver-if01-event-kbd &",
  -- "awww-daemon &", --noctalia replaces
  "sleep 2; systemctl --user start sunshine &",
  "noctalia &",
  "sleep 2; dex -a &", -- autostart stuff in ~/.config/autostart
  -- HDR doesn't always stick on the very first monitor commit at boot
  -- (the livingroom_tv connector isn't settled yet); force a real
  -- re-apply a few seconds in. See monitor_reapply() in init/monitors.lua.
  "sleep 5; hyprctl eval 'monitor_reapply()' &"
  -- hl.exec_cmd("ashell &") --noctalia replaces
}

hl.on("hyprland.start", function ()
  for i, cmd in ipairs(onstart_commands) do
    hl.exec_cmd(cmd)
  end
end)

hl.on("hyprland.shutdown", function()
    os.execute("systemctl --user stop hyprland-session.target && sleep 0.1")
    -- uses a blocking exec function and sleeps a bit to give things time to close
    -- you might also want to kill troublesome/crashing non-systemd background services here:
    -- os.execute("pkill wallpaperthing; systemctl --user stop hyprland-session.target && sleep 0.1")
end)
