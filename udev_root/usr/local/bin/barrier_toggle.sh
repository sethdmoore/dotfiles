#!/bin/sh
export DISPLAY=:0
export USER_ID=$(id -u $USER)
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

echo $DBUS_SESSION_BUS_ADDRESS

main() {
  local mode
  mode="$1"

  if [ "$mode" = "client" ]; then
    systemctl --user stop barrierd.service
    systemctl --user start barrier.service
  elif [ "$mode" = "server" ]; then
    systemctl --user stop barrier.service
    systemctl --user start barrierd.service
  else
    echo "You must run the script with 'client' or 'server' as first argument!"
    exit 2
  fi
}

main $@
