#!/bin/sh
# ShareX in a few lines of shell script!

OPTIONS="+nomouse"
CAP_MOUSE="0"
FILE="vid.mp4"
QUANT="26"
# 480p
WIDTH_MAX="854"
HEIGHT_MAX="480"

function region_cap() {
  # x,y coords for capture
  # w,h dimensions of capture
  # nw is the modified new width, usually copied from width
  local x y w h dim input nw
  read -r x y w h <<< "$1 $2 $3 $4"
  echo $x

  if [ "$w" -gt "$WIDTH_MAX" ]; then
    w="854"
  else
    nw=w
  fi

  echo "$nw"

  dim="$x,$y"
  input=":0.0+$dim"
  # -vf scale="854:-2" \
  ffmpeg \
    -vsync passthrough -frame_drop_threshold 4 \
    -f x11grab \
    -video_size "$nw"x"$h" \
    -framerate 60 \
    -i "$input" \
    -vcodec libx264 \
    -vf scale="$w:-2" \
    -preset ultrafast -crf:v "$QUANT" \
    -draw_mouse "$CAP_MOUSE" \
    -fs 10M \
    -y \
    "$FILE"
}

# function upload() {
# 
# }

function main() {
  local x y w h g id
  # echo curl -sS -F "files[]=@${FILE}" https://pomf.space/upload.php | jq '.files[0].url' | xsel --clipboard
  read -r x y w h g id <<< $(slop -f "%x %y %w %h %g %i")
  region_cap "$x $y $w $h"
}

main
