#!/bin/sh
# waydroid session stop && weston --fullscreen --shell=kiosk-shell.so --socket=wayland-0 &>/dev/null & sleep 5 && WAYLAND_DISPLAY=wayland-0 XDG_SESSION_TYPE=wayland waydroid show-full-ui

export DEFAULT_HEIGHT=1008
export DEFAULT_WIDTH=567
export WAYDROID_HAS_SESSION
export DEFAULT_POLL=0.1


is_session_started() {
  if ! status=$(waydroid status \
    | grep 'Session:' \
    | awk '{print $2}'
  ); then
    false
    return
  fi

  if [ -z "$status" ] || [ "$status" = "STOPPED" ]; then
    false
    return
  fi
  
  if [ "$status" = "RUNNING" ]; then
    true
    return
  fi

  false
}

# log_msg() {}

get_prop() {
  prop="$1"
  ask_waydroid="$2"
  
  # convert prop to uppercase
  prop_upper=$(
    echo "$prop" \
    | tr '[:lower:]' '[:upper:]' \
  )

  if [ "$ask_waydroid" = "y" ]; then
    prop_value=$(
      waydroid \
        prop get \
        "persist.waydroid.${prop}" \
        2>/dev/null \
        | tr -d '\n'
    )
  fi

  if [ -z "$prop_value" ]; then
    printenv -- "DEFAULT_${prop_upper}"
    return
  fi

  echo "$prop_value"
}

get_wid() {
  if ! output=$(wmctrl -l | grep -i waydroid); then
    false
    return
  fi

  echo "$output" | cut -d ' ' -f1
}

poll_wid() {
  wid="$1"
  cage_pid="$2"
  while true; do
    if ! wmctrl -l | grep -q "$wid"; then
      echo "WID lost, cage closed"
      break
    fi
    sleep "$DEFAULT_POLL"
  done
}

resize_wid() {
  wid="$1"
  width="$2"
  height="$3"

  echo "hello? ${wid}" 2>&1

  echo wmctrl -i \
    -r "$wid" \
    -e \
    "0,0,0,${height},${width}"

  wmctrl -i \
    -r "$wid" \
    -e \
    "0,0,0,${height},${width}"
}

main() {
  if is_session_started; then
    ask_waydroid="y"
  else
    ask_waydroid="n"
  fi

  app="$1"
  if [ -z "$app" ]; then
    echo "Run with an app name"
    echo "EG: waydroid app list"
    echo "EG: ./waydroid_kiosk.sh com.iskslowtest.mislen"
    exit 1
  fi
  
  height=$(get_prop "height" "$ask_waydroid")
  width=$(get_prop "width" "$ask_waydroid")

  cage -- waydroid show-full-ui &
  cage_pid="$!"

  wid=""
  echo "looking for WID"
  sleep "$DEFAULT_POLL"
  max_attempts=500
  while [ -z "$wid" ]; do
    max_attempts=$((max_attempts - 1))
    echo "$max_attempts"
    if [ "$max_attempts" -le 0 ]; then
      echo "Could not find Waydroid in time!"
      break
    fi

    if ! wid=$(get_wid); then
      sleep $DEFAULT_POLL
      continue
    fi
  done

  echo "Found WID"
  resize_wid "$wid" "$height" "$width"
  echo "Resized WID"

  poll_wid "$wid" "$cage_pid" &
  poll_pid="$!"

  sleep 14
  echo "launching... "
  # waydroid app launch com.iskslowtest.mislen
  waydroid app launch "$app"

  wait -- "$poll_pid"
  waydroid session stop
  echo "stopped session"
}

main "$@"
