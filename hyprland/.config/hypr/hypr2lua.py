#!/usr/bin/env python3
"""
hypr2lua.py — convert Hyprland .conf (hyprlang) to .lua

Scope: only attempts conversions that are documented in the Hyprland Lua API
(https://wiki.hypr.land/Configuring/Basics/). For uncertain dispatchers or
syntax it falls back to `hl.dsp.exec_raw("<original>")`, which is the
officially-documented escape hatch that runs an old-style hyprlang dispatcher
string. Anything truly unrecognised becomes a `-- I don't know how to do this:`
comment so you can hand-fix it.

This is intentionally conservative. It is NOT a 100% lossless converter --
think of the output as a starting point you'll review.

Usage:
    python3 hypr2lua.py <input.conf> [output.lua]
    python3 hypr2lua.py <input_dir>                # converts every .conf in tree

If output is omitted, prints to stdout (single file) or writes .lua next to
each .conf (directory mode).
"""

from __future__ import annotations
import argparse
import os
import re
import sys
from pathlib import Path
from typing import List, Tuple, Optional


# --------------------------------------------------------------------------- #
# Small helpers
# --------------------------------------------------------------------------- #

def lua_str(s: str) -> str:
    """Quote a string for Lua, escaping backslashes and double-quotes."""
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def strip_inline_comment(line: str) -> Tuple[str, str]:
    """
    Split a hyprlang line into (code, comment) where comment includes the '#'.
    Hyprlang uses `#` for comments. We don't try to be clever about `#` inside
    strings -- hyprlang doesn't really have strings.
    """
    idx = line.find("#")
    if idx == -1:
        return line, ""
    return line[:idx], line[idx:]


def indent(s: str, n: int = 4) -> str:
    pad = " " * n
    return "\n".join(pad + ln if ln else ln for ln in s.split("\n"))


# --------------------------------------------------------------------------- #
# Variable expansion
# --------------------------------------------------------------------------- #
# Hyprlang lets you write `$name = value` and reference it as `$name`. We
# collect these and inline-expand them in the Lua output. Lua has its own
# variables but the .conf files reference vars across `source =` files, which
# is harder to track. Inlining is the cleanest approach for a one-shot
# converter.

class VarTable:
    def __init__(self):
        self.vars: dict[str, str] = {}

    def define(self, name: str, value: str) -> None:
        # Resolve any vars inside `value` immediately so later expansion
        # doesn't have to recurse.
        self.vars[name] = self.expand(value)

    def expand(self, s: str) -> str:
        # Greedy match: $foo_bar_baz before $foo. Sort keys longest-first.
        if not self.vars:
            return s
        for k in sorted(self.vars.keys(), key=len, reverse=True):
            s = s.replace("$" + k, self.vars[k])
        return s


# --------------------------------------------------------------------------- #
# Block / section state
# --------------------------------------------------------------------------- #
# Hyprlang blocks look like:
#     general {
#         gaps_in = 5
#     }
# Some blocks are nested (e.g. `decoration { shadow { ... } }`).
# Window/workspace/layer rules use the same brace syntax but go to dedicated
# hl.* calls. Everything else flows into hl.config({...}).

# Top-level keys that map to hl.config({ <key> = {...} })
CONFIG_BLOCKS = {
    "general", "decoration", "animations", "input", "gestures", "misc",
    "binds", "cursor", "group", "dwindle", "master", "scrolling", "render",
    "xwayland", "opengl", "debug", "ecosystem", "experimental",
}

# Nested-inside-decoration sub-blocks (and a couple of others). These become
# nested Lua tables rather than separate hl.config() calls.
NESTED_BLOCKS = {
    "shadow", "blur", "touchpad", "touchdevice", "tablet",
    "groupbar",  # under group
}


# --------------------------------------------------------------------------- #
# Value coercion
# --------------------------------------------------------------------------- #

# Things that read as bool-ish in hyprlang
BOOL_TRUE = {"true", "yes", "on", "1"}
BOOL_FALSE = {"false", "no", "off", "0"}


def looks_like_int(s: str) -> bool:
    return bool(re.fullmatch(r"-?\d+", s))


def looks_like_float(s: str) -> bool:
    return bool(re.fullmatch(r"-?\d+\.\d+", s))


def coerce_scalar(value: str) -> str:
    """
    Convert a hyprlang scalar to its Lua literal. Falls back to a quoted
    string. Note: hyprlang is loose about bool/yes/no -- we DO convert the
    word forms (true/false/yes/no/on/off) to Lua booleans, but we leave
    bare 0/1 as integers, because many hyprland options take an integer
    that happens to be one of those values (e.g. follow_mouse = 1 selects
    a mouse-follow MODE, not a boolean). Getting that wrong silently
    changes behavior.
    """
    v = value.strip()
    if v == "":
        return '""'
    # Only word forms -> booleans, NOT 0/1.
    if v.lower() in ("true", "yes", "on"):
        return "true"
    if v.lower() in ("false", "no", "off"):
        return "false"
    if looks_like_int(v):
        return v
    if looks_like_float(v):
        return v
    return lua_str(v)


# Specific keys whose values we know to be numeric or color-ish (and so the
# above coercion is safe). Anything else we hand-craft below.

# --------------------------------------------------------------------------- #
# Color parsing
# --------------------------------------------------------------------------- #

def parse_color(value: str) -> str:
    """
    Hyprlang colors can be:
        rgba(33ccffee)            -> 0xee33ccff (Lua uses ARGB hex)
        rgb(595959)               -> 0xff595959
        rgba(0, 0, 0, 0.0)        -> built into 0xAARRGGBB
        0xeeAABBCC                -> passthrough
    Returns a Lua expression (number literal). Falls back to a quoted string.

    Per the example hyprland.lua, both string ("rgba(...)") and integer (0x...)
    forms appear to be accepted. We pass through the original string form
    when easy, which is the most readable.
    """
    v = value.strip()
    # If they already wrote 0x... -- keep it.
    if re.fullmatch(r"0[xX][0-9a-fA-F]+", v):
        return v
    # rgba(hex) and rgb(hex) -- the example file uses string form for these
    # so we preserve them verbatim.
    if re.fullmatch(r"(?i)rgba?\([^)]*\)", v):
        return lua_str(v)
    # gradient: "rgba(...) rgba(...) 45deg"
    if "rgba(" in v or "rgb(" in v:
        return lua_str(v)
    # Last resort
    return lua_str(v)


# --------------------------------------------------------------------------- #
# Bind handling
# --------------------------------------------------------------------------- #
# The bind family of keywords:
#   bind   = MODS, KEY, dispatcher, args...
#   bindl  = ...    (locked)
#   bindr  = ...    (release)
#   binde  = ...    (repeat)
#   bindel = ...    (locked + repeat)   -- letters can be combined in any order
#   bindm  = ...    (mouse)
#   bindo  = ...    (long_press)
#   bindp  = ...    (bypass inhibit)
#   bindd  = MODS, KEY, description, dispatcher, args...
# We split off the leading "bind" and treat each remaining letter as a flag.

BIND_FLAG_TO_LUA = {
    # letter -> Lua flag-table key
    "l": "locked",
    "r": "release",
    "e": "repeating",
    "m": "mouse",
    "o": "long_press",
    "p": "bypass_inhibit",
    "n": "non_consuming",
    "t": "transparent",
    "i": "ignore_mods",
    "s": "separate",
    "c": "click",
    "g": "drag",
    "d": "description",   # special: requires a description arg
}


def parse_bind_keyword(kw: str) -> Tuple[List[str], bool]:
    """
    'bind'   -> ([], False)
    'bindel' -> (['locked','repeating'], False)
    'bindd'  -> (['description'], True)         (True means: pull description)
    """
    if not kw.startswith("bind"):
        return [], False
    rest = kw[4:]
    flags = []
    has_desc = False
    for ch in rest:
        lua_flag = BIND_FLAG_TO_LUA.get(ch)
        if lua_flag is None:
            # Unknown flag; keep as a literal flag string so the user can fix.
            flags.append("unknown_flag_" + ch)
        else:
            if ch == "d":
                has_desc = True
            flags.append(lua_flag)
    return flags, has_desc


def normalize_mods(mods: str) -> str:
    """
    Turn 'SUPER SHIFT' / 'SUPER+SHIFT' / 'SUPER, SHIFT' into 'SUPER + SHIFT'.
    Empty stays empty.
    """
    m = mods.strip()
    if not m:
        return ""
    # split on whitespace, commas, plus signs
    parts = [p for p in re.split(r"[\s,+]+", m) if p]
    return " + ".join(parts)


def build_key_string(mods: str, key: str) -> str:
    """Produce the first arg to hl.bind, e.g. 'SUPER + Q' or just 'XF86AudioRaiseVolume'."""
    m = normalize_mods(mods)
    k = key.strip()
    if m and k:
        return m + " + " + k
    return m or k


# Maps the OLD hyprlang dispatcher name -> a function that builds the Lua
# dispatcher expression (string). For each, args is a list of trimmed arg
# tokens that were comma-separated in the original. The function may return
# None to mean "I don't know how to do this -- use exec_raw fallback".

def disp_exec(args: List[str]) -> Optional[str]:
    # `exec, my command --here` -- args are already comma-separated, but the
    # command itself can contain commas. We rejoin in the caller; here we
    # just take args[0] as the full command string.
    if not args:
        return None
    cmd = ", ".join(args).strip()
    return f"hl.dsp.exec_cmd({lua_str(cmd)})"


def disp_killactive(args: List[str]) -> Optional[str]:
    return "hl.dsp.window.close()"


def disp_togglefloating(args: List[str]) -> Optional[str]:
    return 'hl.dsp.window.float({ action = "toggle" })'


def disp_pseudo(args: List[str]) -> Optional[str]:
    return "hl.dsp.window.pseudo()"


def disp_movefocus(args: List[str]) -> Optional[str]:
    if not args:
        return None
    d = args[0].strip()
    dir_map = {"l": "left", "r": "right", "u": "up", "d": "down",
               "left": "left", "right": "right", "up": "up", "down": "down"}
    if d in dir_map:
        return f'hl.dsp.focus({{ direction = "{dir_map[d]}" }})'
    return None


def disp_workspace(args: List[str]) -> Optional[str]:
    """
    workspace, N            -> hl.dsp.focus({ workspace = N })
    workspace, e+1 / e-1    -> hl.dsp.focus({ workspace = "e+1" })
    workspace, special:foo  -> hl.dsp.focus({ workspace = "special:foo" })
    """
    if not args:
        return None
    ws = args[0].strip()
    if looks_like_int(ws):
        return f"hl.dsp.focus({{ workspace = {ws} }})"
    return f"hl.dsp.focus({{ workspace = {lua_str(ws)} }})"


def disp_togglespecialworkspace(args: List[str]) -> Optional[str]:
    name = args[0].strip() if args else "magic"
    return f"hl.dsp.workspace.toggle_special({lua_str(name)})"


def disp_movewindow_mouse(args: List[str]) -> Optional[str]:
    # bindm = ..., movewindow      (drag with mouse)
    return "hl.dsp.window.drag()"


def disp_resizewindow_mouse(args: List[str]) -> Optional[str]:
    return "hl.dsp.window.resize()"


def disp_fullscreen(args: List[str]) -> Optional[str]:
    # Uncertain in Lua API. The wiki shows fullscreen_state for the
    # decoupled variant but the simple "toggle fullscreen" Lua name isn't
    # confirmed in my research. Fall through to exec_raw.
    return None


def disp_layoutmsg(args: List[str]) -> Optional[str]:
    # layoutmsg, togglesplit  -> hl.dsp.layout("togglesplit")
    # layoutmsg, move +col    -> hl.dsp.layout("move +col")
    if not args:
        return None
    msg = " ".join(a.strip() for a in args)
    return f"hl.dsp.layout({lua_str(msg)})"


# Things we KNOW the Lua name for. Everything else falls through to exec_raw.
DISPATCHER_MAP = {
    "exec":                disp_exec,
    "killactive":          disp_killactive,
    "togglefloating":      disp_togglefloating,
    "pseudo":              disp_pseudo,
    "movefocus":           disp_movefocus,
    "workspace":           disp_workspace,
    "togglespecialworkspace": disp_togglespecialworkspace,
    "movewindow":          disp_movewindow_mouse,    # bindm context only
    "resizewindow":        disp_resizewindow_mouse,  # bindm context only
    "fullscreen":          disp_fullscreen,
    "layoutmsg":           disp_layoutmsg,
}

# Dispatchers we explicitly defer to exec_raw, with a TODO note, because they
# either have a Lua equivalent we couldn't confirm or take complex syntax.
EXEC_RAW_DISPATCHERS = {
    "forcekillactive",
    "movetoworkspace",
    "movetoworkspacesilent",
    "swapwindow",
    "resizeactive",
    "moveactive",
    "pass",
    "sendshortcut",
    "global",
    "submap",
    "centerwindow",
    "pin",
    "togglegroup",
    "changegroupactive",
    "lockactivegroup",
    "moveoutofgroup",
    "moveintogroup",
    "togglesplit",
    "fullscreenstate",
    "movecurrentworkspacetomonitor",
    "moveworkspacetomonitor",
    "focusworkspaceoncurrentmonitor",
    "renameworkspace",
    "exit",
    "dpms",
    "bringactivetotop",
    "cyclenext",
    "focuscurrentorlast",
    "focusurgentorlast",
    "alterzorder",
}


def build_exec_raw(dispatcher: str, args: List[str]) -> str:
    """Construct hl.dsp.exec_raw("dispatcher args...") fallback."""
    if args:
        raw = dispatcher + " " + ",".join(args)
    else:
        raw = dispatcher
    return f"hl.dsp.exec_raw({lua_str(raw.strip())})"


# --------------------------------------------------------------------------- #
# Window-rule property handling
# --------------------------------------------------------------------------- #
#
# Hyprlang:
#   windowrule {
#       name = some-name
#       match:class = ^foo$
#       match:initial_title = ^bar$
#       match:tag = mytag
#       float = on
#       size = 1280 720
#       tag = +game
#   }
#
# Lua:
#   hl.window_rule({
#       name = "some-name",
#       match = { class = "^foo$", initial_title = "^bar$", tag = "mytag" },
#       float = true,
#       size = {1280, 720},
#       tag = "+game",
#   })

# Whitespace-separated number pairs (or expressions) used for size/move.
# Keys whose value is "<num> <num>".
COORD_PAIR_KEYS = {"size", "move", "minsize", "maxsize"}


def parse_match_subkey(k: str) -> str:
    """Convert hyprlang match:foo_bar to Lua key foo_bar (snake_case is preserved)."""
    return k[len("match:"):]


def normalize_inline_comment(comment: str) -> str:
    """Convert a hyprlang `#comment` chunk into a Lua `--comment` chunk."""
    if not comment:
        return ""
    c = comment.lstrip()
    if c.startswith("#"):
        c = "--" + c[1:]
    return c


def coerce_rule_value(key: str, value: str) -> str:
    v = value.strip()
    if key in COORD_PAIR_KEYS:
        parts = re.split(r"\s+", v)
        if len(parts) == 2 and all(looks_like_int(p) or looks_like_float(p) for p in parts):
            return "{" + parts[0] + ", " + parts[1] + "}"
        # Expressions or "monitor_h-120" etc -> pass as strings
        if len(parts) == 2:
            return "{" + lua_str(parts[0]) + ", " + lua_str(parts[1]) + "}"
        return lua_str(v)
    # Only word forms -> booleans. Leave 0/1 as ints.
    if v.lower() in ("true", "yes", "on"):
        return "true"
    if v.lower() in ("false", "no", "off"):
        return "false"
    if looks_like_int(v):
        return v
    if looks_like_float(v):
        return v
    return lua_str(v)


# --------------------------------------------------------------------------- #
# Animations / bezier / animation lines (top-level keywords inside `animations`)
# --------------------------------------------------------------------------- #

def emit_bezier(name: str, p0x: str, p0y: str, p1x: str, p1y: str) -> str:
    return (f'hl.curve({lua_str(name)}, '
            f'{{ type = "bezier", points = {{ {{{p0x}, {p0y}}}, {{{p1x}, {p1y}}} }} }})')


def emit_animation(parts: List[str]) -> Optional[str]:
    """
    parts come from "animation = NAME, ONOFF, SPEED, CURVE, [STYLE]"
    Returns one `hl.animation({...})` call, or None on parse failure.
    """
    if len(parts) < 4:
        return None
    name, onoff, speed, curve = (p.strip() for p in parts[:4])
    enabled = onoff in ("1", "true", "yes", "on")
    extra_style = parts[4].strip() if len(parts) >= 5 else None

    pieces = [
        f"leaf = {lua_str(name)}",
        f"enabled = {'true' if enabled else 'false'}",
        f"speed = {speed}",
        f"bezier = {lua_str(curve)}",
    ]
    if extra_style:
        pieces.append(f"style = {lua_str(extra_style)}")
    return "hl.animation({ " + ", ".join(pieces) + " })"


# --------------------------------------------------------------------------- #
# The main converter
# --------------------------------------------------------------------------- #

class Converter:
    def __init__(self):
        self.vars = VarTable()
        # Things we emit as separate top-level Lua statements:
        self.preamble: List[str] = []
        self.statements: List[str] = []

        # While we're inside a `windowrule { ... }` block we accumulate fields.
        self.in_windowrule = False
        self.windowrule_fields: List[Tuple[str, str]] = []   # (key, raw value)

        # Same for workspace { ... } block (workspace rule body when used as block)
        self.in_workspace_block = False
        self.workspace_block_fields: List[Tuple[str, str]] = []

        # Stack of nested config blocks. Each entry is (name, list-of-"key = lua_value").
        # We assemble nested table strings as we leave each block.
        # Top of stack is the innermost block.
        self.block_stack: List[Tuple[str, List[str]]] = []

    # ------------------------------------------------------------------ #
    # Line dispatch
    # ------------------------------------------------------------------ #

    def feed_line(self, raw_line: str, comment_out_lines: List[str]) -> None:
        """Process one logical line. comment_out_lines collects line comments to attach."""
        line = raw_line.rstrip("\n")
        # Pull off trailing comment so we can preserve it.
        code, comment = strip_inline_comment(line)
        stripped = code.strip()

        # Pure comment / blank?
        if not stripped:
            if comment:
                self._emit_comment_line(comment)
            else:
                self._emit_blank()
            return

        # Closing brace?
        if stripped == "}":
            self._close_block(comment)
            return

        # Variable definition: $name = value   (only at top level)
        m = re.match(r"^\$([A-Za-z0-9_][A-Za-z0-9_]*)\s*=\s*(.*)$", stripped)
        if m and not self.block_stack and not self.in_windowrule and not self.in_workspace_block:
            name, value = m.group(1), m.group(2).strip()
            self.vars.define(name, value)
            self._emit_comment_line(f"-- (variable) ${name} = {value}" + (" " + comment if comment else ""))
            return

        # Expand $vars in everything that follows.
        expanded = self.vars.expand(stripped)

        # Window rule block opener (check BEFORE the generic block regex,
        # because windowrule isn't a hl.config block -- it's a separate call).
        if re.match(r"^windowrule(?:v2)?\s*\{\s*$", expanded):
            self.in_windowrule = True
            self.windowrule_fields = []
            if comment:
                self._emit_comment_line(comment)
            return

        # Layer rule block opener
        if re.match(r"^layerrule\s*\{\s*$", expanded):
            self.in_windowrule = True
            self.windowrule_fields = [("__rule_kind__", "layer")]
            if comment:
                self._emit_comment_line(comment)
            return

        # Workspace rule block opener:  workspace { ... }  (rare; usually one-line)
        if re.match(r"^workspace\s*\{\s*$", expanded):
            self.in_workspace_block = True
            self.workspace_block_fields = []
            if comment:
                self._emit_comment_line(comment)
            return

        # Block opener:   NAME { ... or  NAME {
        m = re.match(r"^([A-Za-z_][\w\-]*)\s*\{\s*$", expanded)
        if m:
            self._open_block(m.group(1), comment)
            return

        # If we're collecting a windowrule body, route there.
        if self.in_windowrule:
            self._feed_rule_field(stripped, comment)
            return
        if self.in_workspace_block:
            self._feed_workspace_field(stripped, comment)
            return

        # source = ./other.conf -- emit a Lua require() with .conf stripped
        m = re.match(r"^source\s*=\s*(.+)$", expanded)
        if m:
            path = m.group(1).strip()
            # ./foo.conf  ->  require("foo") relative to this file
            # Strip leading ./ and any .conf extension.
            cleaned = re.sub(r"^\.\/", "", path)
            cleaned = re.sub(r"\.conf$", "", cleaned)
            self.statements.append(f"require({lua_str(cleaned)})" + (("  " + normalize_inline_comment(comment)) if comment else ""))
            return

        # env = NAME,VALUE
        m = re.match(r"^env\s*=\s*([^,]+),\s*(.*)$", expanded)
        if m:
            name, val = m.group(1).strip(), m.group(2).strip()
            self.statements.append(f"hl.env({lua_str(name)}, {lua_str(val)})" + (("  " + normalize_inline_comment(comment)) if comment else ""))
            return

        # exec-once = ...
        m = re.match(r"^exec-once\s*=\s*(.*)$", expanded)
        if m:
            cmd = m.group(1).strip()
            # The example file uses hl.on("hyprland.start", function() hl.exec_cmd(...) end)
            # We emit one hl.on block per file, but for simplicity just emit
            # individual `hl.on("hyprland.start", ...)` calls -- they stack.
            self.statements.append(
                f'hl.on("hyprland.start", function() hl.exec_cmd({lua_str(cmd)}) end)'
                + (("  " + normalize_inline_comment(comment)) if comment else "")
            )
            return

        # exec = ... (run on every reload)  -- no documented Lua equivalent for
        # the "run on every reload" semantics I could verify. Use exec_cmd
        # at top level, which runs on config load.
        m = re.match(r"^exec\s*=\s*(.*)$", expanded)
        if m:
            cmd = m.group(1).strip()
            self.statements.append(
                f"hl.exec_cmd({lua_str(cmd)})"
                + (("  -- was: exec = ... " + comment) if comment else "  -- was: exec = ...")
            )
            return

        # workspace = ID, rules...   (one-line workspace rule)
        m = re.match(r"^workspace\s*=\s*(.+)$", expanded)
        if m:
            self._emit_workspace_rule_oneline(m.group(1), comment)
            return

        # gesture = fingers, direction, action
        m = re.match(r"^gesture\s*=\s*(.+)$", expanded)
        if m:
            self._emit_gesture(m.group(1), comment)
            return

        # device { ... }  -- already handled by block opener above; here only
        # the one-line form `device = name = foo, sensitivity = -0.5` could
        # in theory exist but it's not standard.

        # bezier inside an animations block (we're inside block_stack[-1] == "animations")
        m = re.match(r"^bezier\s*=\s*(.+)$", expanded)
        if m and self.block_stack and self.block_stack[-1][0] == "animations":
            parts = [p.strip() for p in m.group(1).split(",")]
            if len(parts) == 5:
                name, p0x, p0y, p1x, p1y = parts
                # Curves are top-level hl.curve calls per the example.
                # We collect them as separate statements but place them
                # after the current block closes? Actually, the example shows
                # they live AT TOP LEVEL outside any hl.config({...}) call --
                # so we emit them as deferred top-level statements.
                self.preamble.append(emit_bezier(name, p0x, p0y, p1x, p1y)
                                     + (("  " + normalize_inline_comment(comment)) if comment else ""))
                return

        # animation = leaf, on/off, speed, curve, [style]   (inside animations block)
        m = re.match(r"^animation\s*=\s*(.+)$", expanded)
        if m and self.block_stack and self.block_stack[-1][0] == "animations":
            parts = [p.strip() for p in m.group(1).split(",")]
            line_out = emit_animation(parts)
            if line_out is not None:
                self.preamble.append(line_out + (("  " + normalize_inline_comment(comment)) if comment else ""))
                return
            # else fall through to the "I don't know" path

        # bind family: bind, bindl, bindel, bindd, bindo, bindp, bindm, ...
        m = re.match(r"^(bind[a-z]*)\s*=\s*(.*)$", expanded)
        if m:
            self._emit_bind(m.group(1), m.group(2), comment)
            return

        # permission = ...     (kept as a comment with TODO, since Lua syntax
        # is `hl.permission(pattern, perm, action)` per the example file)
        m = re.match(r"^permission\s*=\s*(.+)$", expanded)
        if m:
            parts = [p.strip() for p in m.group(1).split(",")]
            if len(parts) == 3:
                self.statements.append(
                    f"hl.permission({lua_str(parts[0])}, {lua_str(parts[1])}, {lua_str(parts[2])})"
                    + (("  " + normalize_inline_comment(comment)) if comment else "")
                )
                return

        # Inside a config block: key = value or col.subkey = value
        if self.block_stack:
            self._feed_block_field(stripped, comment)
            return

        # Top-level "name = value" with no recognised handler:
        # Emit as an unknown so the user can fix.
        self._unknown(raw_line)

    # ------------------------------------------------------------------ #
    # Block open/close
    # ------------------------------------------------------------------ #

    def _open_block(self, name: str, comment: str) -> None:
        self.block_stack.append((name, []))
        if comment:
            self.block_stack[-1][1].append("-- " + comment.lstrip("# ").rstrip())

    def _close_block(self, trailing_comment: str) -> None:
        if not self.block_stack:
            # Unbalanced }; might be the end of windowrule/workspace, which
            # we don't track via block_stack.
            if self.in_windowrule:
                self._finish_windowrule(trailing_comment)
                return
            if self.in_workspace_block:
                self._finish_workspace_block(trailing_comment)
                return
            self._unknown("} (unmatched)")
            return

        name, fields = self.block_stack.pop()

        # Build the Lua table body.
        body = "\n".join(fields)
        table = "{\n" + indent(body, 4) + "\n}"

        if not self.block_stack:
            # Top-level block: decide whether it's a config block or its own
            # special function.
            if name in CONFIG_BLOCKS:
                self.statements.append(
                    f"hl.config({{ {name} = {table} }})"
                    + (("  " + normalize_inline_comment(trailing_comment)) if trailing_comment else "")
                )
            elif name == "device":
                # device { name = "foo", sensitivity = -0.5 } -> hl.device({...})
                self.statements.append(
                    f"hl.device({table})"
                    + (("  " + normalize_inline_comment(trailing_comment)) if trailing_comment else "")
                )
            elif name in ("monitor", "monitorv2"):
                # Both monitor and monitorv2 hyprlang blocks map to hl.monitor({...})
                # per https://wiki.hypr.land/Configuring/Basics/Monitors/
                self.statements.append(
                    f"hl.monitor({table})"
                    + (("  " + normalize_inline_comment(trailing_comment)) if trailing_comment else "")
                )
            else:
                # Unknown top-level block -- pass as config anyway and let the
                # user fix it; emit a TODO comment.
                self.statements.append(
                    f"-- TODO: unknown block '{name}', passing into hl.config() best-effort\n"
                    f"hl.config({{ {name} = {table} }})"
                    + (("  " + normalize_inline_comment(trailing_comment)) if trailing_comment else "")
                )
        else:
            # Nested block -- emit as a sub-table entry of the enclosing block.
            self.block_stack[-1][1].append(f"{name} = {table},")

    # ------------------------------------------------------------------ #
    # Field collection (config block scalars)
    # ------------------------------------------------------------------ #

    def _feed_block_field(self, stripped: str, comment: str) -> None:
        # Match "key = value" or "col.active_border = ..."
        m = re.match(r"^([A-Za-z_][\w\.\-]*)\s*=\s*(.*)$", stripped)
        if not m:
            self._unknown(stripped)
            return
        key, value = m.group(1), m.group(2).strip()
        value = self.vars.expand(value)

        cur_block_name = self.block_stack[-1][0]

        # Special-case general.col.active_border / .inactive_border
        if key.startswith("col."):
            sub = key[len("col."):]
            lua_val = self._coerce_border_color(value)
            # Nested under col = { ... }
            # Find or create a `col = {...}` field in the current block.
            self._append_subtable_entry("col", sub, lua_val)
            return

        # general.allow_tearing etc. -- normal scalar
        if cur_block_name == "animations" and key == "enabled":
            # "enabled = yes, please :)" -> true
            v = "true" if value.lower().startswith(("y", "t", "1", "on")) else "false"
            self.block_stack[-1][1].append(f"enabled = {v},"
                                           + (("  " + normalize_inline_comment(comment)) if comment else ""))
            return

        # general / decoration / etc. -- map to scalars/booleans.
        lua_val = coerce_scalar(value)
        line = f"{key} = {lua_val},"
        if comment:
            line += "  " + normalize_inline_comment(comment)
        self.block_stack[-1][1].append(line)

    def _coerce_border_color(self, value: str) -> str:
        """
        general.col.active_border = rgba(...) rgba(...) 45deg
        general.col.active_border = rgba(...)
        general.col.inactive_border = rgba(...)
        """
        v = value.strip()
        # Two rgba(...) plus an angle?
        m = re.match(
            r"^(rgba?\([^)]+\))\s+(rgba?\([^)]+\))(?:\s+(\d+)deg)?\s*$", v
        )
        if m:
            c1, c2, ang = m.group(1), m.group(2), m.group(3)
            ang_str = f", angle = {ang}" if ang else ""
            return f'{{ colors = {{{lua_str(c1)}, {lua_str(c2)}}}{ang_str} }}'
        # Single color -- pass as a string per the example file.
        return lua_str(v)

    def _append_subtable_entry(self, sub_name: str, key: str, lua_val: str) -> None:
        """
        Append `key = lua_val` into a sub-table named sub_name inside the
        current block. Creates the sub-table if it doesn't exist yet.

        We keep this simple: each `col.foo = ...` becomes its own
        `col = { foo = ..., }` sub-entry. Multiple entries in one block get
        merged at the end (cheap post-pass below).
        """
        fields = self.block_stack[-1][1]
        # See if there's already a "col = {" line we should append to.
        # We use a marker convention: store the col entries flat with a
        # sentinel and merge in _close_block. For simplicity, store as a
        # specially-prefixed string that close_block recognises:
        fields.append(f"__SUBTABLE__:{sub_name}:{key}={lua_val},")

    # Override _close_block to merge __SUBTABLE__ entries before assembly.
    # We do this by post-processing the fields list right before building
    # `table`. Easiest: re-implement here.

    # (Patched below via wrapping)

    # ------------------------------------------------------------------ #
    # Window rule body collection
    # ------------------------------------------------------------------ #

    def _feed_rule_field(self, stripped: str, comment: str) -> None:
        m = re.match(r"^([A-Za-z_][\w:\-\.]*)\s*=\s*(.*)$", stripped)
        if not m:
            self._unknown("windowrule: " + stripped)
            return
        key, value = m.group(1), m.group(2).strip()
        value = self.vars.expand(value)
        self.windowrule_fields.append((key, value))
        if comment:
            self.windowrule_fields.append(("__comment__", comment))

    def _finish_windowrule(self, trailing_comment: str) -> None:
        # Determine if this is a layer_rule (marked sentinel) or window_rule
        kind = "window"
        if self.windowrule_fields and self.windowrule_fields[0] == ("__rule_kind__", "layer"):
            kind = "layer"
            self.windowrule_fields = self.windowrule_fields[1:]

        match_entries: List[str] = []
        outer_entries: List[str] = []
        name_field: Optional[str] = None
        comments: List[str] = []

        for k, v in self.windowrule_fields:
            if k == "__comment__":
                comments.append(v)
                continue
            if k == "name":
                name_field = v
                continue
            if k.startswith("match:") or (kind == "layer" and k.startswith("namespace")):
                sub = parse_match_subkey(k) if k.startswith("match:") else k
                match_entries.append(f"{sub} = {coerce_rule_value(sub, v)},")
                continue
            outer_entries.append(f"{k} = {coerce_rule_value(k, v)},")

        # Build the table.
        parts = []
        if name_field is not None:
            parts.append(f"name = {lua_str(name_field)},")
        if match_entries:
            parts.append("match = {\n" + indent("\n".join(match_entries), 4) + "\n},")
        parts.extend(outer_entries)

        body = "\n".join(parts)
        call = f"hl.{kind}_rule({{\n" + indent(body, 4) + "\n})"
        if trailing_comment:
            call += "  " + normalize_inline_comment(trailing_comment)
        for c in comments:
            self.statements.append("-- " + c.lstrip("# ").rstrip())
        self.statements.append(call)

        self.in_windowrule = False
        self.windowrule_fields = []

    # ------------------------------------------------------------------ #
    # workspace { ... } block (rare, but support it)
    # ------------------------------------------------------------------ #

    def _feed_workspace_field(self, stripped: str, comment: str) -> None:
        # We just append as-is, since the body is dispatcher-specific (e.g.
        # scrolling { direction = right }-style). Best handled as a block
        # config -- but the user's actual config uses one-line workspace = ...
        # so this path is mostly defensive.
        m = re.match(r"^([A-Za-z_][\w:\-\.]*)\s*=\s*(.*)$", stripped)
        if not m:
            self._unknown("workspace-block: " + stripped)
            return
        self.workspace_block_fields.append((m.group(1), m.group(2).strip()))

    def _finish_workspace_block(self, trailing_comment: str) -> None:
        # No clean way to know the workspace ID here, so emit a TODO.
        self.statements.append(
            "-- TODO: workspace { ... } block has no inferrable workspace id; "
            "convert manually. Original fields:\n"
            + "\n".join(f"--   {k} = {v}" for k, v in self.workspace_block_fields)
        )
        self.in_workspace_block = False
        self.workspace_block_fields = []

    # ------------------------------------------------------------------ #
    # One-line workspace rule
    # ------------------------------------------------------------------ #

    def _emit_workspace_rule_oneline(self, body: str, comment: str) -> None:
        # workspace = 2, layoutopt:direction:right, layout:scrolling
        # workspace = w[tv1], gapsout:0, gapsin:0
        # First token is the workspace identifier. The rest are k:v pairs
        # separated by commas, where k itself may have ":" inside.
        parts = [p.strip() for p in body.split(",") if p.strip()]
        if not parts:
            self._unknown("workspace = " + body)
            return
        ws_id = parts[0]
        ws_lua: str
        if looks_like_int(ws_id):
            ws_lua = ws_id
        else:
            ws_lua = lua_str(ws_id)

        rule_entries: List[str] = []
        # Many old-style workspace rule keys (e.g. gapsout:0, gapsin:0,
        # bordersize:0, rounding:0, decorate:0) use `key:value` syntax.
        # The Lua form uses key = value with underscores. We translate
        # a few well-known ones; everything else we pass via a string-keyed
        # entry and a TODO.
        KNOWN = {
            "gapsout": "gaps_out",
            "gapsin": "gaps_in",
            "bordersize": "border_size",
            "rounding": "rounding",
            "decorate": "decorate",
            "border": "border",
            "shadow": "shadow",
            "monitor": "monitor",
            "default": "default",
            "persistent": "persistent",
            "on-created-empty": "on_created_empty",
        }

        unknown_bits: List[str] = []
        for kv in parts[1:]:
            if ":" not in kv:
                unknown_bits.append(kv)
                continue
            k, v = kv.split(":", 1)
            k = k.strip()
            v = v.strip()
            if k == "layout":
                rule_entries.append(f"layout = {lua_str(v)},")
            elif k == "layoutopt":
                # layoutopt:direction:right => layout_opts = { direction = "right" }
                if ":" in v:
                    sk, sv = v.split(":", 1)
                    rule_entries.append(
                        f"layout_opts = {{ {sk.strip()} = {coerce_rule_value(sk.strip(), sv.strip())} }},"
                    )
                else:
                    unknown_bits.append(kv)
            elif k in KNOWN:
                rule_entries.append(f"{KNOWN[k]} = {coerce_rule_value(KNOWN[k], v)},")
            else:
                unknown_bits.append(kv)

        body_str = (
            f"workspace = {ws_lua},\n"
            + indent("\n".join(rule_entries), 0)
        )
        out = "hl.workspace_rule({\n" + indent(body_str, 4) + "\n})"
        if unknown_bits:
            out += "  -- TODO: unconverted: " + ", ".join(unknown_bits)
        if comment:
            out += "  " + normalize_inline_comment(comment)
        self.statements.append(out)

    # ------------------------------------------------------------------ #
    # Gestures
    # ------------------------------------------------------------------ #

    def _emit_gesture(self, body: str, comment: str) -> None:
        # gesture = 3, horizontal, workspace
        parts = [p.strip() for p in body.split(",")]
        if len(parts) < 3:
            self._unknown("gesture = " + body)
            return
        fingers, direction, action = parts[0], parts[1], parts[2]
        extra = parts[3:]
        entries = [
            f"fingers = {fingers},",
            f"direction = {lua_str(direction)},",
            f"action = {lua_str(action)},",
        ]
        if extra:
            entries.append(f"-- TODO: extra gesture args dropped: {extra}")
        body_str = "\n".join(entries)
        self.statements.append("hl.gesture({\n" + indent(body_str, 4) + "\n})"
                               + (("  " + normalize_inline_comment(comment)) if comment else ""))

    # ------------------------------------------------------------------ #
    # Bind emission
    # ------------------------------------------------------------------ #

    def _emit_bind(self, keyword: str, rest: str, comment: str) -> None:
        flags, has_desc = parse_bind_keyword(keyword)

        # Format:                bind = MODS, KEY, DISPATCHER, ARGS...
        # With description flag: bindd = MODS, KEY, DESC, DISPATCHER, ARGS...
        # The ARGS portion is the LAST field and may itself contain commas
        # (e.g. an exec command like `sh -c "a, b"`), so we don't split it.
        # Comma-split into exactly N parts: 4 normally, 5 if has_desc, where
        # the final part is the entire (possibly comma-bearing) args string.
        n_head = 4 if has_desc else 3   # number of leading single-token fields
        parts_split = rest.split(",", n_head)
        # Pad with empty strings if the user wrote a dispatcher with no args
        # (e.g. `bind = SUPER, q, killactive,`).
        while len(parts_split) < n_head + 1:
            parts_split.append("")
        head_tokens = [p.strip() for p in parts_split[:n_head]]
        args_tail = parts_split[n_head]  # raw, may include commas

        if has_desc:
            mods, key, desc, disp_name = head_tokens
        else:
            mods, key, disp_name = head_tokens
            desc = None

        # disp_args is the trailing args portion, comma-split. Empty string
        # means "no args" (e.g. killactive).
        if args_tail.strip() == "":
            disp_args: List[str] = []
        else:
            disp_args = [a.strip() for a in args_tail.split(",")]

        # Look up dispatcher
        lua_disp: Optional[str] = None
        if disp_name in DISPATCHER_MAP:
            lua_disp = DISPATCHER_MAP[disp_name](disp_args)

        if lua_disp is None:
            # Fall back to exec_raw with the ORIGINAL dispatcher + args.
            lua_disp = build_exec_raw(disp_name, disp_args)
            todo = f"  -- TODO: verify exec_raw mapping for '{disp_name}'"
        else:
            todo = ""

        key_str = build_key_string(mods, key)
        flag_table = ""
        if flags:
            kvs = []
            for f in flags:
                if f.startswith("unknown_flag_"):
                    kvs.append(f"-- unknown flag: {f}")
                else:
                    if f == "description":
                        continue
                    kvs.append(f"{f} = true")
            if has_desc and desc:
                kvs.append(f"description = {lua_str(desc)}")
            if kvs:
                flag_table = ", { " + ", ".join(kvs) + " }"

        line = f"hl.bind({lua_str(key_str)}, {lua_disp}{flag_table})"
        if comment:
            line += "  " + normalize_inline_comment(comment)
        if todo:
            line += todo
        self.statements.append(line)

    # ------------------------------------------------------------------ #
    # Miscellaneous emit helpers
    # ------------------------------------------------------------------ #

    def _emit_comment_line(self, comment: str) -> None:
        # Convert a leading '#' to '--' so it's a valid Lua comment.
        c = comment.lstrip()
        if c.startswith("#"):
            c = "--" + c[1:]
        self.statements.append(c)

    def _emit_blank(self) -> None:
        self.statements.append("")

    def _unknown(self, original: str) -> None:
        msg = f"-- I don't know how to do this: {original.strip()}"
        self.statements.append(msg)

    # ------------------------------------------------------------------ #
    # Output assembly
    # ------------------------------------------------------------------ #

    def render(self) -> str:
        # Resolve any __SUBTABLE__: entries that snuck into block-output. We
        # didn't actually keep those in block_stack at render time, because
        # close_block already flushed; for the user's configs (which include
        # `col.active_border = ...`) we instead handled that earlier via the
        # _coerce_border_color path. The __SUBTABLE__ mechanism is unused in
        # practice for these configs, but post-process anyway to be safe.
        out_lines: List[str] = []
        for stmt in self.statements:
            if "__SUBTABLE__:" in stmt:
                stmt = re.sub(
                    r"__SUBTABLE__:([A-Za-z_][\w]*):([A-Za-z_][\w]*)=",
                    r"\1.\2 = ",
                    stmt,
                )
            out_lines.append(stmt)

        # Header + variable note + preamble (curves/animations) + body.
        header = [
            "-- AUTO-GENERATED from a hyprlang .conf by hypr2lua.py",
            "-- Review carefully. Unverified dispatchers were converted to",
            "-- hl.dsp.exec_raw(\"...\") fallbacks; lines flagged with TODO",
            "-- need a manual check against https://wiki.hypr.land/Configuring/Basics/",
            "",
        ]
        body = "\n".join(out_lines)
        preamble = "\n".join(self.preamble)
        if preamble:
            preamble = "\n-- == animation curves / animations (lifted to top level) ==\n" + preamble + "\n"
        return "\n".join(header) + preamble + "\n" + body + "\n"


# A patched _close_block that merges __SUBTABLE__ entries. We monkey-patch
# the class method to keep the original code above readable.
_original_close_block = Converter._close_block


def _patched_close_block(self, trailing_comment: str) -> None:
    if self.block_stack:
        name, fields = self.block_stack[-1]
        # Gather sub-table entries by name.
        subs: dict[str, List[str]] = {}
        new_fields: List[str] = []
        for f in fields:
            m = re.match(r"^__SUBTABLE__:([A-Za-z_][\w]*):([A-Za-z_][\w]*)=(.*)$", f)
            if m:
                sub_name, sub_key, sub_val = m.group(1), m.group(2), m.group(3).rstrip(",")
                subs.setdefault(sub_name, []).append(f"{sub_key} = {sub_val},")
            else:
                new_fields.append(f)
        for sub_name, sub_entries in subs.items():
            sub_body = "\n".join(sub_entries)
            new_fields.append(f"{sub_name} = {{\n" + indent(sub_body, 4) + "\n},")
        self.block_stack[-1] = (name, new_fields)
    _original_close_block(self, trailing_comment)


Converter._close_block = _patched_close_block


# --------------------------------------------------------------------------- #
# File-level entry point
# --------------------------------------------------------------------------- #

# Files that look like Hyprland config files but actually belong to OTHER
# Hypr-ecosystem apps that have NOT (yet) migrated to Lua. We must NOT touch
# these — converting them produces garbage. The list is conservative.
NON_HYPRLAND_CONFIGS = {
    "hyprlock.conf",     # hyprlock — still hyprlang
    "hyprtoolkit.conf",  # hyprtoolkit — its own format, not hyprland
    "hyprpaper.conf",    # hyprpaper — still hyprlang
    "hypridle.conf",     # hypridle — still hyprlang
    "xdph.conf",         # xdg-desktop-portal-hyprland — still hyprlang
}


def is_skippable(path: Path) -> bool:
    return path.name in NON_HYPRLAND_CONFIGS


def collect_vars(in_path: Path) -> VarTable:
    """First pass: scan every .conf in a tree for `$name = value` definitions
    and return a single VarTable. Variables in hyprlang have file-spanning
    scope when sourced, so we treat them as global."""
    vt = VarTable()
    for conf in in_path.rglob("*.conf"):
        for ln in conf.read_text().splitlines():
            code, _ = strip_inline_comment(ln)
            m = re.match(r"^\s*\$([A-Za-z0-9_][A-Za-z0-9_]*)\s*=\s*(.*)$", code)
            if m:
                vt.define(m.group(1), m.group(2).strip())
    return vt


def convert_file(in_path: Path, out_path: Optional[Path],
                 shared_vars: Optional[VarTable] = None) -> None:
    text = in_path.read_text()
    conv = Converter()
    if shared_vars is not None:
        # Pre-seed the converter's VarTable with the shared one. Local
        # definitions in this file will still override (define() replaces).
        conv.vars.vars = dict(shared_vars.vars)
    deferred: List[str] = []
    for ln in text.splitlines():
        conv.feed_line(ln, deferred)
    lua = conv.render()
    if out_path is None:
        sys.stdout.write(lua)
    else:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(lua)


def convert_text(text: str) -> str:
    conv = Converter()
    deferred_comments: List[str] = []
    for ln in text.splitlines():
        conv.feed_line(ln, deferred_comments)
    return conv.render()


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("input", type=Path, help="Input .conf file or directory")
    ap.add_argument("output", type=Path, nargs="?",
                    help="Output .lua file (single-file mode) "
                         "or output directory (directory mode)")
    args = ap.parse_args()

    if args.input.is_dir():
        out_root = args.output if args.output else args.input
        shared_vars = collect_vars(args.input)
        skipped: List[Path] = []
        for conf in args.input.rglob("*.conf"):
            if is_skippable(conf):
                skipped.append(conf)
                continue
            rel = conf.relative_to(args.input)
            out_path = (out_root / rel).with_suffix(".lua")
            convert_file(conf, out_path, shared_vars=shared_vars)
            print(f"  {conf}  ->  {out_path}", file=sys.stderr)
        if skipped:
            print("", file=sys.stderr)
            print("Skipped (not Hyprland configs; these apps haven't moved to Lua):",
                  file=sys.stderr)
            for s in skipped:
                print(f"  - {s}", file=sys.stderr)
    else:
        if args.output is None:
            convert_file(args.input, None)
        else:
            out = args.output
            if out.is_dir():
                out = out / (args.input.stem + ".lua")
            convert_file(args.input, out)
            print(f"  {args.input}  ->  {out}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
