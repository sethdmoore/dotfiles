#!/bin/sh

bitdepth='keyword monitorv2[HDMI-A-1]:bitdepth 8'
colormode='keyword monitorv2[HDMI-A-1]:cm auto'
stream_resolution='2560x1440@120'

batch_cmd="$bitdepth; $colormode"

# can't batch monitov2 mode with the other ones

hyprctl --batch "$batch_cmd"; \
  hyprctl keyword 'monitorv2[HDMI-A-1]:mode' "${stream_resolution}"
