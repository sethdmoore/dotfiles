#!/usr/bin/env python3

from subprocess import Popen, PIPE
import psutil
import sys
import time
# import datetime

RESET_COLOR = "%{F-}%{B-}"

ICONS = {
    "CPU": " "
}

BASE_COLOR = (00,84,160)
END_COLOR = (255,255,255)


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

    return


def init_color_lerp(base_color, end_color):
    # end_ccolor is white 255 255 255
    # r * load * 2.55 | g * load * 1.71 |  b * load * 0.95
    color_values = color_lerp(base_color, end_color)

    return color_values


def color_lerp(start_c, end_c):
    r, g, b = start_c
    # re, ge, be = end_c
    result = ()

    for idx, color in enumerate(start_c):
        result_value = (end_c[idx] - color) / 100
        # print(result_value, sys.stdout)
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
    # print(base_color, file=sys.stdout)
    # print(lerp_values, file=sys.stdout)
    rl, gl, bl = lerp_values

    cpus = psutil.cpu_percent(percpu=True)
    output = ""

    for core_num, percent in enumerate(cpus):
            r = hex_limit(int(red + (percent * rl)))
            g = hex_limit(int(green + (percent * gl)))
            b = hex_limit(int(blue + (percent * bl)))

            cpu_stat[core_num] = "%%{B#%02X%02X%02X}" % (r, g, b)

    # print(cpu_stat, file=sys.stdout)
    # sort this back out so the cores don't come out in random order
    for core_num, color in sorted(cpu_stat.items()):
        output += color + ICONS["CPU"] + RESET_COLOR + " "


    # return " ".join(str(cpu) for cpu in cpus)
    return output


def load_avg():
    try:
        with open("/proc/loadavg", "r",) as f:
            output = f.read().strip("\n")
    except Exception as e:
        print("%s" % e, file=sys.stderr)
        output = "load error"

    return output


def date_print():
    date_str = "%{r}"
    date_str += time.strftime("%c")
    date_str += "   "
    return date_str


def main():
    # p = Popen(["lemonbar"], stdin=PIPE, stdout=PIPE, stderr=PIPE)
    lerp_values = init_color_lerp(BASE_COLOR, END_COLOR)

    p = Popen(["lemonbar"], stdin=PIPE)

    while True:
        # output = load_avg()
        output = cpu_pct(BASE_COLOR, lerp_values)
        output += " "
        output += date_print()
        output += "\n"
        p.stdin.write(bytes(output, "ascii"))
        p.stdin.flush()
        time.sleep(0.5)


if __name__ == "__main__":
    main()
