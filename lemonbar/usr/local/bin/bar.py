#!/usr/bin/env python3

from subprocess import Popen, PIPE
import psutil
import sys
import os
import time
import signal

RESET_COLOR = "%{F-}%{B-}"

ICONS = {
    # "CPU": u'\uF0A3',
    "CPU": u'\uF054',
    "CALENDAR": u'\uF073',
    "DESKTOP_GENERIC": u'\uF07B',
    "DESKTOP1": u'\uF0AC',
    "DESKTOP2": u'\uF075',
    "DESKTOP3": u'\uF08E',
    "DESKTOP4": u'\uF085',
    "DESKTOP5": u'\uF0C3',
    "DESKTOP6": u'\uF0C2',
}

BASE_COLOR = (00, 84, 160)
END_COLOR = (255, 255, 255)

ACTIVE_DESKTOP_COLOR = "%{F#0084AA}"
INACTIVE_DESKTOP_COLOR = "%{F#004488}"


class Bar(object):
    def __init__(self, process_handle, pid):
        self.process_handle = process_handle
        self.output = ""
        self.lerp_values = init_color_lerp(BASE_COLOR, END_COLOR)
        self.pid = pid
        self.pidfile = ""


    def redraw(self, *args):
        # have to take *args because of the signal handler...

        self.output = "  ".join((cpu_pct(BASE_COLOR, self.lerp_values),
                                get_desktops(self.pid),
                                date_print()))

        self.output += "\n"
        # self.process_handle.stdin.write(bytes(self.output, "ascii"))
        self.process_handle.stdin.write(bytes(self.output, "utf-8"))
        self.process_handle.stdin.flush()


    def write_pid(self):
        temp_dir = "/".join((os.getenv("XDG_RUNTIME_DIR"), "lemonbar"))
        pidfile = "bar.py"
        self.pidfile = "/".join((temp_dir, pidfile))
        print(self.pidfile, sys.stderr)
    
        try:
            os.mkdir(temp_dir)
        except FileExistsError as e:
            pass
        except Exception as e:
            print("Unspecified error writing to $XDG_RUNTIME_DIR: %s" % e,
                  file=sys.stderr)
    
        with open(self.pidfile, 'w') as f:
            f.write(str(self.pid))


    def del_pid(self):
        try:
            os.remove(self.pidfile)
        except OSError as e:
            print("Test: %s" % e, file=sys.stderr)


    def quit(self, *args):
        self.del_pid()
        sys.exit(0)


def shell_out(cmd):
    p = Popen(cmd, stdout=PIPE, stderr=PIPE)

    out, err = p.communicate()

    try:
        output = out.decode("ascii").strip("\n")
    except Exception as e:
        output = "load_avg error"

    try:
        error = err.decode("ascii")
    except Exception as e:
        pass

    if error != "":
        output = error

    return output


def init_color_lerp(start_c, end_c):
    r, g, b = start_c
    result = ()

    for idx, color in enumerate(start_c):
        result_value = (end_c[idx] - color) / 100
        result += (result_value,)

    return result


def hex_limit(dec):
    if dec > 255:
        dec = 255
    if dec < 0:
        dec = 0

    return dec


def cpu_pct(base_color, lerp_values):
    cpu_stat = {}

    red, green, blue = base_color
    # red, green, blue lerp values
    rl, gl, bl = lerp_values

    cpus = psutil.cpu_percent(percpu=True)
    output = ""

    for core_num, percent in enumerate(cpus):
            r = hex_limit(int(red + (percent * rl)))
            g = hex_limit(int(green + (percent * gl)))
            b = hex_limit(int(blue + (percent * bl)))

            cpu_stat[core_num] = "%%{F#%02X%02X%02X}" % (r, g, b)

    # sort this back out so the cores don't come out in random order
    for core_num, color in sorted(cpu_stat.items()):
        # output += color + ICONS["CPU"] + RESET_COLOR + " "
        output += color + ICONS["CPU"] + RESET_COLOR

    return output


def get_desktops(pid):
    all_desktops = shell_out(["bspc", "query", "-D"]).split("\n")
    this_desktop = shell_out(["bspc", "query", "-D", "-d"])

    print_desktops = RESET_COLOR


    for number, desktop in enumerate(all_desktops):
        # print(desktop, file=sys.stderr)
        desktop_number = number + 1

        icon_key = "DESKTOP%s" % desktop_number

        if icon_key not in ICONS:
            icon_key = "DESKTOP_GENERIC"

        icon = ICONS[icon_key]

        active = " ".join((ACTIVE_DESKTOP_COLOR,
                           icon, RESET_COLOR))
        inactive = " ".join((INACTIVE_DESKTOP_COLOR,
                             icon, RESET_COLOR))

        # we signal our own program with USR1 to update the bar instantly
        link = "%%{A:bspc desktop ^%s -f; kill -USR1 %s:}" \
            % (desktop_number, pid)

        # print(link, file=sys.stderr)
        end_link = "%{A}"

        if desktop == this_desktop:
            print_desktops += active + " "
        else:
            print_desktops += link + inactive + end_link + " "

    return print_desktops


def date_print():
    date_str = "%{r}"
    date_str += INACTIVE_DESKTOP_COLOR
    date_str += ICONS["CALENDAR"] + ACTIVE_DESKTOP_COLOR + "  "
    date_str += time.strftime("%c")
    date_str += "   "
    return date_str



def main():
    pid = os.getpid()
    lemonbar_bin = ["lemonbar", "-n", "lemonbar"]
    lemonbar_bin += ["-f", "fontawesome-webfont:size=14"]
    lemonbar_bin += ["-f", "lato-regular:size=14"]

    p = Popen(lemonbar_bin, stdin=PIPE)

    bar = Bar(p, pid)
    bar.write_pid()

    signal.signal(signal.SIGUSR1, bar.redraw)
    signal.signal(signal.SIGINT, bar.quit)


    while True:
        bar.redraw()
        time.sleep(1)


if __name__ == "__main__":
    main()
