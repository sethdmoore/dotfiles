hl.on("hyprland.start", function ()
  hl.exec_cmd("swaync &")
  -- TODO: systemd unit?
  hl.exec_cmd("push-to-talk -k KEY_F13 -n F13 /dev/input/by-id/usb-Logitech_USB_Receiver-if01-event-kbd &")
  hl.exec_cmd("awww-daemon &")
  hl.exec_cmd("systemctl --user start sunshine &")
  -- TODO: replace ashell
  hl.exec_cmd("ashell &")
  -- dex -a executes all items in ~/.config/autostart/*.desktop
  hl.exec_cmd("dex -a")
end)
