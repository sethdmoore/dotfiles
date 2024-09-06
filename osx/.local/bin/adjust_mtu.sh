#!/bin/sh

# Some VPNs require a lower MTU when tethering
# Let's make this process painless

VPN_MTU="1350"
VPN_DEV_PREFIX="utun"
ROUTE_CHECK_HOST="8.8.8.8"

get_interface() {
  # prints the primary interface with route to 8.8.8.8
  route get "$ROUTE_CHECK_HOST" \
    | grep interface \
    | awk -F ':' '{print $2}' \
    | tr -d ' '
}


check_interface() {
  interface="$1"

  if ! echo "$interface" | grep -q "$VPN_DEV_PREFIX"; then
    echo "Want: interface='${VPN_DEV_PREFIX}#'"
    echo "Got:  interface='${interface}'"
    echo "Are you connected to the VPN?"
    exit 1
  fi
}


set_mtu() {
  interface="$1"

  sudo ifconfig \
    "${interface}" \
    mtu "${VPN_MTU}"
}


main() {
  if ! interface="$(get_interface)"; then
    echo "Failed to get primary interface"
    exit 2
  fi

  check_interface "$interface"

  if ! set_mtu "$interface"; then
    echo "Failed to set MTU"
    exit 2
  fi
}


main "$@"
