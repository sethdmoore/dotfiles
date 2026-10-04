#!/bin/sh
# Long-lived X key injector for push to talk (see input/pushtotalk.lua).
#
# Runs one `xdotool -` that reads commands (e.g. "keydown XF86Launch5") line by
# line from a fifo, so the compositor can inject keys by writing to the fifo
# instead of forking a process per key event.
#
# usage: ptt-helper.sh {start|stop|status} FIFO
#
#   start   idempotent. Reuses a healthy helper; otherwise cleans up whatever
#           is left over (dead/orphaned helper, missing or stale fifo) and
#           starts a fresh one.
#   stop    kills the helper and removes the fifo, pidfile and lock.
#   status  exit 0 if a healthy helper is running (prints its pid), else 1.
#
# state files live next to the fifo: FIFO.pid, FIFO.lock

set -u

cmd=${1:-}
fifo=${2:-}
[ -n "$cmd" ] && [ -n "$fifo" ] || {
    echo "usage: ${0##*/} {start|stop|status} FIFO" >&2
    exit 2
}
pidfile="$fifo.pid"
lockfile="$fifo.lock"

# serialize start/stop (the lock fd is closed in the helper, see start)
exec 9>"$lockfile"
flock 9

# pid of the helper iff the pidfile points at a live `xdotool -`
helper_pid() {
    pid=$(cat "$pidfile" 2>/dev/null) || return 1
    [ -n "$pid" ] || return 1
    [ "$(tr '\0' ' ' 2>/dev/null < "/proc/$pid/cmdline")" = "xdotool - " ] || return 1
    echo "$pid"
}

# helper is alive *and* reading the fifo that currently exists. If the fifo was
# deleted/recreated it holds the old inode, and writes would go nowhere.
healthy() {
    pid=$(helper_pid) || return 1
    [ -p "$fifo" ] || return 1
    [ "$(readlink "/proc/$pid/fd/0" 2>/dev/null)" = "$fifo" ]
}

kill_helper() {
    pid=$(helper_pid) || return 0
    kill "$pid" 2>/dev/null
    # wait up to ~1s for it to go away
    i=0
    while kill -0 "$pid" 2>/dev/null && [ "$i" -lt 10 ]; do
        sleep 0.1
        i=$((i + 1))
    done
    kill -0 "$pid" 2>/dev/null && kill -9 "$pid" 2>/dev/null
    return 0
}

case "$cmd" in
start)
    if healthy; then
        exit 0
    fi

    kill_helper
    rm -f "$fifo" "$pidfile"
    mkfifo -m 600 "$fifo" || exit 1

    # `<>` opens the fifo read-write so xdotool never sees EOF between writers.
    # 9>&- so the helper doesn't inherit (and hold) the lock.
    xdotool - <> "$fifo" 9>&- >/dev/null 2>&1 &
    echo $! > "$pidfile"
    ;;
stop)
    kill_helper
    rm -f "$fifo" "$pidfile" "$lockfile"
    ;;
status)
    if healthy; then
        helper_pid
    else
        exit 1
    fi
    ;;
*)
    echo "usage: ${0##*/} {start|stop|status} FIFO" >&2
    exit 2
    ;;
esac
