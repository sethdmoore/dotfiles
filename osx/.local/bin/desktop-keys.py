#!/usr/bin/env python3
"""Binds Option+1..5 to the native "Switch to Desktop 1..5" shortcuts.

A shortcut only works once its Desktop exists in Mission Control.
"""

import ctypes
import subprocess

FIRST_DESKTOP_HOTKEY = 118
OPTION = 0x80000
KEYCODES = [18, 19, 20, 21, 23]

SKYLIGHT = ctypes.CDLL("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight")
SKYLIGHT.CGSSetSymbolicHotKeyValue.argtypes = [
    ctypes.c_int,
    ctypes.c_uint16,
    ctypes.c_uint16,
    ctypes.c_uint32,
]
SKYLIGHT.CGSSetSymbolicHotKeyEnabled.argtypes = [ctypes.c_int, ctypes.c_bool]


def save(hotkey: int, char: int, keycode: int) -> None:
    value = f"{{enabled = 1; value = {{ parameters = ({char}, {keycode}, {OPTION}); type = standard; }}; }}"
    subprocess.run(
        ["defaults", "write", "com.apple.symbolichotkeys", "AppleSymbolicHotKeys",
         "-dict-add", str(hotkey), value],
        check=True,
    )


# The saved preference only loads at login, and activateSettings -u does not
# push it to the WindowServer on macOS 27, so set the live value too.
def apply(hotkey: int, char: int, keycode: int) -> None:
    if SKYLIGHT.CGSSetSymbolicHotKeyValue(hotkey, char, keycode, OPTION) != 0:
        raise RuntimeError(f"CGSSetSymbolicHotKeyValue failed for hotkey {hotkey}")
    if SKYLIGHT.CGSSetSymbolicHotKeyEnabled(hotkey, True) != 0:
        raise RuntimeError(f"CGSSetSymbolicHotKeyEnabled failed for hotkey {hotkey}")


def main() -> None:
    for index, keycode in enumerate(KEYCODES):
        hotkey = FIRST_DESKTOP_HOTKEY + index
        char = ord("1") + index
        save(hotkey, char, keycode)
        apply(hotkey, char, keycode)


if __name__ == "__main__":
    main()
