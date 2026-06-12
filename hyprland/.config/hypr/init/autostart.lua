onstart_commands = {
  --"swaync &", --noctalia replaces
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
