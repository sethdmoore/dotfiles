#!/bin/sh
PANEL_WM_NAME=lemonybar

wid=$(xdo id -a "$PANEL_WM_NAME")
tries_left=20
while [ -z "$wid" -a "$tries_left" -gt 0 ] ; do
  sleep 0.05
  wid=$(xdo id -a "$PANEL_WM_NAME")
  tries_left=$((tries_left - 1))
done

for w in $wid; do
    xdo id -N Bspwm -n root | xargs -I% xdo above -t "%" "$w"
done
