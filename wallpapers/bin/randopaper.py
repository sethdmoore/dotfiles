#!/usr/bin/env python3
import os
import sys
from random import choice as draw_straws


def main():
    if len(sys.argv) < 2:
        directory = os.environ.get("HOME")
        if not directory:
            os.exit(2)
        wallpaper_dir = os.path.join(directory, ".wallpapers")
    else:
        wallpaper_dir = sys.argv[1]

    ls = os.listdir(wallpaper_dir)
    result = os.path.join(wallpaper_dir, draw_straws(ls))
    print(result, end="")


if __name__ == '__main__':
    main()
