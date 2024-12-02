#!/bin/sh
export DISPLAY=:0
export USER_ID=$(id -u $USER)
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"

echo $DBUS_SESSION_BUS_ADDRESS

main() {
  local mode
  mode="$1"

  if [ "$mode" = "client" ]; then
    systemctl --user stop input-leapd.service
    systemctl --user start input-leap.service
  elif [ "$mode" = "server" ]; then
    systemctl --user stop input-leap.service
    systemctl --user start input-leapd.service
  else
    echo "You must run the script with 'client' or 'server' as first argument!"
    exit 2
  fi
}

main $@
