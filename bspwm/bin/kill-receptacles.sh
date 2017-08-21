#!/bin/sh
for i in $(bspc query -N -n .leaf.!window.local); do
  bspc node $i -k;
done
