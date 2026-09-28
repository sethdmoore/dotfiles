#!/bin/sh

monitor='HDMI-A-1'

colormode=$(
  hyprctl monitors -j \
  | jq -r --arg monitor "$monitor" '.[] 
           | select(.name == $monitor)
           | .colorManagementPreset
          '
)

sdr_bitdepth="keyword monitorv2[${monitor}]:bitdepth 8"
sdr_colormode="keyword monitorv2[${monitor}]:cm auto"
# hdr_bitdepth='keyword monitorv2[HDMI-A-1]:bitdepth 10'
# hdr_colormode='keyword monitorv2[HDMI-A-1]:cm hdr'
batch_cmd="$sdr_bitdepth; $sdr_colormode"

if [ "$colormode" = "hdr" ] || [ "$colormode" = "hdredid" ]; then
# if [ "$colormode" = "hdr" ]; then # || [ "$colormode" = "hdredid" ]; then
  hyprctl --batch "$batch_cmd"
  notify-send "HDR disabled"
elif [ "$colormode" = "srgb" ]; then
  # colormode should be srgb; force a real re-apply (plain `hyprctl reload`
  # is a no-op here since monitors.lua's `applied` cache skips re-issuing
  # hl.monitor() when nothing has changed)
  hyprctl eval 'monitor_reapply()'
  notify-send "HDR" "Enabled"
else
  notify-send "HDR" "${colormode} colormode is unsupported\nForcing re-apply to reset"
  hyprctl eval 'monitor_reapply()'
fi
