onstart_commands = {
  -- graphical session
  "systemctl --user start hyprland-session.target",
  -- TODO: systemd unit?
  "push-to-talk -k KEY_F13 -n F13 /dev/input/by-id/usb-Logitech_USB_Receiver-if01-event-kbd &",
  -- "awww-daemon &", --noctalia replaces
  "systemctl --user start sunshine &",
  "noctalia &",
  "sleep 2; dex -a &" -- autostart stuff in ~/.config/autostart
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
