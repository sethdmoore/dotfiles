#!/bin/sh

colormode=$(hyprctl monitors -j \
       | jq -r '.[].colorManagementPreset')

sdr_bitdepth='keyword monitorv2[HDMI-A-1]:bitdepth 8'
sdr_colormode='keyword monitorv2[HDMI-A-1]:cm auto'
# hdr_bitdepth='keyword monitorv2[HDMI-A-1]:bitdepth 10'
# hdr_colormode='keyword monitorv2[HDMI-A-1]:cm hdr'
batch_cmd="$sdr_bitdepth; $sdr_colormode"

if [ "$colormode" = "hdr" ]; then
  hyprctl --batch "$batch_cmd"
  notify-send "HDR disabled"
elif [ "$colormode" = "srgb" ]; then
  # colormode should be srgb, reload
  hyprctl reload
  notify-send "HDR enabled"
else
  echo "warning: unknown color mode"
  echo "warning: reloading..."
  hyprctl reload
fi
