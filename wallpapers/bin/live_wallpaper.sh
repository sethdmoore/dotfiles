#!/bin/sh


MPV_COMMAND="mpv --loop-playlist=inf --hwdec=auto -wid WID "
WALLPAPER="$HOME/.live_wallpapers/jelly.mp4"
WALLPAPER="$HOME/.live_wallpapers/perfect_jelly.mp4"

count_monitors() {
  local monitors
  monitors=$(xrandr -q | grep '*' | wc -l)
  return $monitors
}

main() {
  local num_monitors monitor geom res w h extra_opt
  count_monitors
  num_monitors=$?
  echo num_monitors

  w="1920"
  h="1080"
  res="${w}x${h}"
  echo $res

  for monitor in $(seq 1 $num_monitors); do
    geom=$((1920 * $((monitor - 1))))

    if [ "$monitor" -eq "$num_monitors" ]; then
      # monitor 3 is a square beast
      res="1280x1024"
      extra_opt="--panscan 1.0"
    fi

    xwinwrap -ov -g "${res}+${geom}+0" -- \
      $MPV_COMMAND $extra_opt $WALLPAPER &
  done


  # xwinwrap -ov -g 1280x1024+1920+0 -- \
  #   $MPV_COMMAND --panscan=1.0 $WALLPAPER &
}

main $@
