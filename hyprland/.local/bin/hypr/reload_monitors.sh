#!/bin/sh

# Also drops any resolution override from set_2k* or Sunshine.
hyprctl reload
hyprctl eval 'monitor_revert()'
