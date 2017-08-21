#!/usr/bin/env python3
import os
from random import choice as draw_straws

def main():
    home = os.environ.get("HOME")
    if not home:
        os.exit(2)

    wallpaper_dir = os.path.join(home, ".wallpapers")

    ls = os.listdir(wallpaper_dir)
    result = os.path.join(wallpaper_dir, draw_straws(ls))
    print(result, end="")


if __name__ == '__main__':
    main()
