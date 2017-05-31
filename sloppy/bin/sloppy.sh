#!/bin/sh
# ShareX in a few lines of shell script!
# requires slop(1), ffmpeg(1)

OPTIONS="+nomouse"
CAP_MOUSE="0"
FILE="/tmp/region_cap.mp4"
# value between 1 and 31
QUANT="26"
# telegram limits 10 megabytes
FS_LIMIT="10M"
# telegram limits 480p
WIDTH_MAX="854"
HEIGHT_MAX="480"

function region_cap() {
  # $x,$y are coords for capture | $w,$h dimensions of capture
  # $nw is the modified new width, usually copied from width
  local x y w h nw dim input
  read -r x y w h <<< "$1 $2 $3 $4"
  echo $x

  # scales the maximum width to WIDTH_MAX and then rounds the height down
  if [ "$w" -gt "$WIDTH_MAX" ]; then
    nw="854"
  else
    nw="$w"
  fi

  dim="$x,$y"
  input=":0.0+$dim"
  # -vf scale="854:-2" \
  ffmpeg \
    -vsync passthrough -frame_drop_threshold 4 \
    -f x11grab \
    -draw_mouse "$CAP_MOUSE" \
    -video_size "$w"x"$h" \
    -framerate 60 \
    -i "$input" \
    -vcodec libx264 \
    -vf scale="$nw:-2" \
    -preset ultrafast -crf:v "$QUANT" \
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