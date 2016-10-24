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

CPU_THRESHOLDS = [
    (00.0, "%{B#00CC00}"),
    (20.0, "%{B#AACC00}"),
    (40.0, "%{B#CCCC00}"),
    (60.0, "%{B#FFCC00}"),
    (89.0, "%{B#FFCC22}"),
    (95.0, "%{B#FF0000}")
]


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


def cpu_pct():
    cpu_stat = {}
    cpus = psutil.cpu_percent(percpu=True)
    output = ""

    for core_num, percent in enumerate(cpus):
        for threshold, color in CPU_THRESHOLDS:
            if percent >= threshold:
                cpu_stat[core_num] = color

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
    p = Popen(["lemonbar"], stdin=PIPE)

    while True:
        # output = load_avg()
        output = cpu_pct()
        output += " "
        output += date_print()
        output += "\n"
        p.stdin.write(bytes(output, "ascii"))
        p.stdin.flush()
        time.sleep(1)


if __name__ == "__main__":
    main()
