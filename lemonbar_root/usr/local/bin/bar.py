#!/usr/bin/env python3

from subprocess import Popen, PIPE
import psutil
import sys
import os
import time
import signal
import json


RESET_COLOR = "%{F-}%{B-}"

# fontawesome icons
ICONS = {
    "cpu_chip": u'\uF2DB',
    "gpu_chip": u'\uF11B',
    "cpu_core": u'\uF054',
    "calendar": u'\uF073',
    "check_empty": u'\uF096',
    "check": u'\uF046',
    "unknown": u'\uF059',
    "desktop_generic": u'\uF07B',
    "monitor_generic": u'\uF108',
    "toggle_off": u'\uF204',
    "toggle_on": u'\uF205',
    "desktop1": u'\uF268',
    "desktop2": u'\uF085',
    "desktop3": u'\uF08E',
    "desktop4": u'\uF075',
    "desktop5": u'\uF0C3',
    "desktop6": u'\uF0C2',
    "arrow_right": u'\uF0DA',
    "temp0": u'\uF2CB',
    "temp1": u'\uF2CA',
    "temp2": u'\uF2C9',
    "temp3": u'\uF2C8',
    "temp4": u'\uF2C7',
}

BASE_COLOR = (00, 84, 160)
END_COLOR = (255, 255, 255)

ACTIVE_DESKTOP_COLOR = "%{F#0084AA}"
INACTIVE_DESKTOP_COLOR = "%{F#004488}"

# MONITOR_SORT = ["DVI-I-3", "DVI-I-2"]
MONITOR_SORT = ["HDMI-0", "DP-4", "DP-2"]
TEMPERATURE_SORT = ["cpu", "gpu"]

# reasonable, I think. 40C for low, 90+ for horrible
TEMP_WARNING = 55
TEMP_MAX = 90

TEMP_DIR = "/".join((os.getenv("XDG_RUNTIME_DIR"), "lemonbar"))
PID_FILE = "/".join((TEMP_DIR, "bar.py"))
FIFO_FILE = "/".join((TEMP_DIR, "bar.fifo"))

LEMONBAR_BIN = ["lemonbar", "-n", "lemonybar",
                "-f", "fontawesome-webfont:size=14",
                "-f", "lato-regular:size=14"]

NVIDIA_TEMP_BIN = ["nvidia-smi",
                   "--query-gpu=temperature.gpu",
                   "--format=csv,noheader"]

# this probably won't change
CPU_TEMP_FILE = "/sys/class/thermal/thermal_zone0/temp"

class Bar(object):
    def __init__(self, process_handle):
        self.process_handle = process_handle
        self.pid = os.getpid()
        self.output = ""
        self.hidden = False

        self.lerp_multiplicant = init_color_lerp(BASE_COLOR, END_COLOR)
        self.write_pid()
        self.write_fifo()

        self.fifo_file = ""
        self.monitors = get_monitors()


    def redraw(self, *args):
        # have to take *args because of the signal handler...

        # WARNING: DO NOT POLL xrandr !!
        # It will cause frame stutter on interval and high CPU! Very bad!
        # self.monitors = get_monitors()

        if self.hidden:
            self.output = "  ".join((command_format(len(self.monitors)),
                                     right_justify(),
                                     get_utils(self.hidden)))
        else:
            self.output = "  ".join((command_format(len(self.monitors)),
                                    get_temps(self.lerp_multiplicant),
                                    cpu_pct(self.lerp_multiplicant),
                                    get_desktops(self.monitors, self.pid),
                                    right_justify(),
                                    date_print(),
                                    get_utils(self.hidden)))
        self.output += "\n"
        self.process_handle.stdin.write(bytes(self.output, "utf-8"))
        self.process_handle.stdin.flush()

    def toggle_hidden(self, *args):
        self.hidden = not self.hidden
        self.redraw()


    def restart(self, *args):
        # this is the only way to close a file handle cleanly
        # when using Popen
        _, _ = self.process_handle.communicate()

        p = Popen(LEMONBAR_BIN, stdin=PIPE)
        self.process_handle = p
        self.monitors = get_monitors()
        self.redraw()


    def write_pid(self):
        self.pid_file = PID_FILE
        print(self.pid_file, sys.stderr)

        try:
            os.mkdir(TEMP_DIR)
        except FileExistsError as e:
            pass
        except Exception as e:
            print("Unhandled error writing to $XDG_RUNTIME_DIR: %s" % e,
                  file=sys.stderr)

        with open(self.pid_file, 'w') as f:
            f.write(str(self.pid))


    def write_fifo(self):
        pass
        # self.fifo_file = FIFO_FILE
        # os.mkfifo(FIFO_FILE)


    def del_pid(self):
        try:
            os.remove(self.pid_file)
        except OSError as e:
            print("Could not remove pid file: %s" % e, file=sys.stderr)


    def quit(self, *args):
        self.del_pid()
        sys.exit(0)


# determines the start and end colors
# return a tuple
def init_color_lerp(start_c, end_c):
    r, g, b = start_c
    result = ()

    for idx, color in enumerate(start_c):
        result_value = (end_c[idx] - color) / 100
        result += (result_value,)

    return result


# always stick lemonbar on the correct monitor
def command_format(monitor_count):
    if monitor_count == 2:
        return "%{Sl}"
    else:
        return "%{S0}"


# wrap Popen to make it not so horrible every time we want to shell out
def shell_out(cmd):
    # universal_newlines returns a str object instead of an io*
    p = Popen(cmd, stdout=PIPE, stderr=PIPE, universal_newlines=True)
    error = ""

    out, err = p.communicate()

    out = out.strip("\n")

    if error != "":
        out = error

    return out


# ensure we don't go under or over 8 bit
def hex_limit(dec):
    if dec > 255:
        dec = 255
    if dec < 0:
        dec = 0

    return dec


def lerp_multiply(percent, lerp_multiplicant):
    # red, green, blue lerp values
    rl, gl, bl = lerp_multiplicant

    red, green, blue = BASE_COLOR
    r = hex_limit(int(red + (percent * rl)))
    g = hex_limit(int(green + (percent * gl)))
    b = hex_limit(int(blue + (percent * bl)))
    return r,g,b


# return the lerp values, scaled against TEMP_WARNING and TEMP_MAX
def temperature_range(input_temp):
    # http://stackoverflow.com/a/25835683 so nice.
    temp = ((input_temp - TEMP_WARNING) * 100) // (TEMP_MAX - TEMP_WARNING)
    if temp < 0:
        temp = 0
    return temp


# return CPU and GPU temperatures
def get_temps(lerp_multiplicant):
    temps = {}
    temps["cpu"] = 0
    temps["gpu"] = 0
    output = ""
    with open(CPU_TEMP_FILE, "r") as t:
        cpu_temp = t.read()

    # floor division
    temps["cpu"] = int(cpu_temp) // 1000

    temps["gpu"] = shell_out(NVIDIA_TEMP_BIN)
    try:
        temps["gpu"] = int(temps["gpu"])
    except ValueError as e:
        temps["gpu"] = 255

    temps["gpu_lerp"] = temperature_range(temps["gpu"])

    temps["cpu_lerp"] = temperature_range(temps["cpu"])

    print("real c%s, floaty c%s" % (temps["cpu"], temps["cpu_lerp"]), file=sys.stderr)
    print("real g%s, floaty g%s" % (temps["gpu"], temps["gpu_lerp"]), file=sys.stderr)

    for temp_type in TEMPERATURE_SORT:
        temp_key = "%s_lerp" % temp_type
        icon_key = "%s_chip" % temp_type

        if temps["gpu"] == 255 and temp_type == "gpu":
            icon_key = "unknown"

        r,g,b = lerp_multiply(temps[temp_key], lerp_multiplicant)
        output += "%%{F#%02X%02X%02X}" % (r, g, b)
        output += ICONS[icon_key] + RESET_COLOR + "  "
    output += INACTIVE_DESKTOP_COLOR + "|" + RESET_COLOR

    return str(output)


def cpu_pct(lerp_multiplicant):
    cpu_stat = {}

    cpus = psutil.cpu_percent(percpu=True)
    output = ""

    for core_num, percent in enumerate(cpus):
        r,g,b = lerp_multiply(percent, lerp_multiplicant)

        cpu_stat[core_num] = "%%{F#%02X%02X%02X}" % (r, g, b)

    # sort this back out so the cores don't come out in random order
    for core_num, color in sorted(cpu_stat.items()):
        # output += color + ICONS["CPU"] + RESET_COLOR + " "
        output += color + ICONS["cpu_core"] + RESET_COLOR

    return output


def get_utils(hidden):
    if hidden:
        return_str = INACTIVE_DESKTOP_COLOR
        icon_hide = ICONS["toggle_off"]
    else:
        return_str = ACTIVE_DESKTOP_COLOR
        icon_hide = ICONS["toggle_on"]

    return_str += "%{A:urxvt &:}" + ICONS["monitor_generic"] + "%{A}" + "  "
    return_str += "%%{A:xargs kill -SIGINT < %s &:}" % PID_FILE + icon_hide + "%{A}" + "  "
    return return_str


def get_desktops(monitors, pid):
    # bspc query -T -m DVI-I-2
    all_desktops = []
    active_desktops = []
    for idx, monitor in enumerate(monitors):
        json_blob = shell_out(["bspc", "query", "-T", "-m", monitor])

        try:
            json_blob = json.loads(json_blob)
        except Exception as e:
            print("Could not decode [bspc query -T -m " +
                  monitor + "] %s" % e, file=sys.stderr)
        if 'desktops' in json_blob:
            all_desktops.append(json_blob['desktops'])
        active_desktops.append(json_blob['focusedDesktopId'])

        # active_desktops[monitor] = shell_out(["bspc", "query", "-T", "-d"])

    print_desktops = RESET_COLOR


    for monitor_num, monitor in enumerate(all_desktops):
        # print(desktop, file=sys.stderr)
        print_desktops += INACTIVE_DESKTOP_COLOR + "[ " + RESET_COLOR
        for idx, desktops in enumerate(monitor):
            desktop_id = desktops['id']

            desktop_number = desktops['name']

            icon_key = "desktop%s" % desktop_number

            if icon_key not in ICONS:
                icon_key = "desktop_generic"

            icon = ICONS[icon_key]

            active = " ".join((ACTIVE_DESKTOP_COLOR,
                               icon, RESET_COLOR))
            inactive = " ".join((INACTIVE_DESKTOP_COLOR,
                                 icon, RESET_COLOR))

            # we signal our own program with USR1 to update the bar instantly
            link = "%%{A:bspc desktop ^%s -f; kill -USR1 %s:}" \
                % (desktop_number, pid)

            end_link = "%{A}"

            if desktop_id == active_desktops[monitor_num]:
                print_desktops += active + " "
            else:
                print_desktops += link + inactive + end_link + " "
        print_desktops += INACTIVE_DESKTOP_COLOR +  "] " + RESET_COLOR

    return print_desktops


def get_monitors():
    out = shell_out(["xrandr", "-q"])
    out = out.split("\n")
    unsorted_monitors = []
    monitors = []
    for idx, line in enumerate(out):
        display = ""
        if "*" in line:
            try:
                display = out[idx-1]
            except Exception as e:
                print("Could not reliably determine monitors", file=sys.stderr)
            unsorted_monitors.append(display.split(" ")[0])


    for monitor in MONITOR_SORT:
        try:
            idx = unsorted_monitors.index(monitor)
            monitors.append(unsorted_monitors[idx])
        # this should only occur if your MONITOR_SORT is invalid
        except Exception as e:
            pass

    # failsafe
    if len(monitors) == 0:
        monitors = unsorted_monitors

    # validation
    if len(monitors) > 0:
        return monitors
    else:
        print("No monitors detected!", file=sys.stderr)
        sys.exit(2)

def right_justify():
    return "%{r}"

def date_print():
    date_str = INACTIVE_DESKTOP_COLOR
    link = '%{A:notify-send "$(cal_wrapper)":}'
    end_link = "%{A}"

    date_str += link
    date_str += ICONS["calendar"] + ACTIVE_DESKTOP_COLOR + "  "
    date_str += time.strftime("%c")
    date_str += "   "
    date_str += end_link
    # print(date_str, file=sys.stderr)
    return date_str


def main():

    p = Popen(LEMONBAR_BIN, stdin=PIPE)

    bar = Bar(p)

    signal.signal(signal.SIGUSR1, bar.redraw)
    signal.signal(signal.SIGUSR2, bar.restart)
    signal.signal(signal.SIGINT, bar.toggle_hidden)


    while True:
        bar.redraw()
        time.sleep(1)


if __name__ == "__main__":
    main()
