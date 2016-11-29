#!/bin/sh

export QEMU_AUDIO_DRV=pa

multihead() {
  xrandr --output DVI-I-3 \
    --auto \
    --left-of DVI-I-2 \
    --output DVI-I-2 \
    --auto \
    --primary
}

singlehead() {
  xrandr --output DVI-I-3 \
    --off
}

# main() {
#   local mode
#   mode=$1
#   if [ "$mode" = "multi" ]; then
#     multihead
#   elif [ "$mode" = "single" ]; then
#     singlehead
#   fi
# 
# }

singlehead
virsh start win10
