#!/bin/sh

# Revert to the current screen's tuned default (Sunshine's stream-teardown
# "undo" command). Clears any manual resolution override.
hyprctl eval 'monitor_revert()'
