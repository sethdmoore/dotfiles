#!/usr/bin/env python3
"""Helpers for Claude's Obsidian vault, $CLAUDE_VAULT or ~/Documents/obsidian/vaults/claude.

  notes.py index [dir]        one line per note: tokens, last_worked_on, path, description
  notes.py tokens [file ...]  set the `tokens` field of each note (default: every note)
  notes.py match <dir>        notes whose `paths` field contains dir, closest first
  notes.py context <dir>      the brief the SessionStart hook injects
"""
import fnmatch
import math
import os
import pathlib
import re
import sys

VAULT = pathlib.Path(os.environ.get("CLAUDE_VAULT", "~/Documents/obsidian/vaults/claude")).expanduser().resolve()
SELF = pathlib.Path(__file__).absolute()
HOME = pathlib.Path.home()
SKIP = {".obsidian", "templates", "memory"}
TOKENS = re.compile(r"^tokens:.*$", re.M)
BRIEF_LIMIT = 30


def notes(paths):
    if paths:
        return [pathlib.Path(p).resolve() for p in paths]
    return sorted(p for p in VAULT.rglob("*.md") if not SKIP & set(p.relative_to(VAULT).parts))


def split(text):
    if not text.startswith("---\n"):
        return None, text
    end = text.find("\n---", 4)
    if end == -1:
        return None, text
    return text[:end], text[end:]


def field(frontmatter, name):
    match = re.search(rf"^{name}:[ \t]*(.*)$", frontmatter, re.M)
    return match.group(1).strip().strip("\"'") if match else ""


def listfield(frontmatter, name):
    match = re.search(rf"^{name}:[ \t]*(.*)$((?:\n[ \t]+- .*)*)", frontmatter, re.M)
    if not match:
        return []
    inline, block = match.groups()
    items = inline.strip("[]").split(",") if inline.startswith("[") else re.findall(r"- (.*)", block)
    return [i.strip().strip("\"'") for i in items if i.strip()]


def frontmatters():
    for path in notes([]):
        frontmatter, _ = split(path.read_text())
        if frontmatter is not None:
            yield path, frontmatter


def tilde(path):
    return f"~/{path.relative_to(HOME)}" if path.is_relative_to(HOME) else str(path)


def matches(directory):
    target = pathlib.Path(directory).expanduser().resolve()
    depth = {}
    for path, frontmatter in frontmatters():
        for entry in listfield(frontmatter, "paths"):
            root = pathlib.Path(entry).expanduser()
            # A glob entry such as ~/dev/git/all/app-* matches sibling worktrees.
            glob = any(c in entry for c in "*?[")
            if glob:
                hit = any(fnmatch.fnmatchcase(str(d), str(root)) for d in (target, *target.parents))
            else:
                root = root.resolve()
                hit = target.is_relative_to(root)
            if hit:
                # At equal depth an exact path beats a glob, so ~/x/app-foo wins over ~/x/app-*.
                depth[path] = max(depth.get(path, (0, 0)), (len(root.parts), not glob))
    return sorted(depth, key=depth.get, reverse=True)


def index(args):
    root = (VAULT / args[0]).resolve() if args else VAULT
    for path, frontmatter in frontmatters():
        if not path.is_relative_to(root):
            continue
        tokens, date, description = (field(frontmatter, f) for f in ("tokens", "last_worked_on", "description"))
        print(f"{tokens:>6}  {date:<10}  {path.relative_to(VAULT)}  {description}")


def tokens(args):
    for path in notes(args):
        text = path.read_text()
        frontmatter, body = split(text)
        if frontmatter is None or not TOKENS.search(frontmatter):
            print(f"skipped, no tokens field: {path}", file=sys.stderr)
            continue
        # About 4 characters per token for English markdown. Rounded up to the nearest 10.
        estimate = max(10, math.ceil(len(text) / 40) * 10)
        updated = TOKENS.sub(f"tokens: {estimate}", frontmatter, count=1) + body
        if updated != text:
            path.write_text(updated)
            print(f"{estimate:>6}  {path.relative_to(VAULT)}")


def match(args):
    for path in matches(args[0]):
        print(path)


def context(args):
    matched = matches(args[0])
    lines = [f"Your Obsidian vault at {tilde(VAULT)} is your memory of projects across sessions. Read {tilde(VAULT / 'CLAUDE.md')} before you write a note."]
    if matched:
        lines.append(f"This directory belongs to {', '.join(tilde(p) for p in matched)}. Read it before you work on the project.")
    else:
        lines.append("No note lists this directory in `paths`. If the work here will span sessions, add the directory to a note's `paths`, or create a project note.")
    listed = []
    for path, frontmatter in frontmatters():
        kind = field(frontmatter, "type")
        rel = path.relative_to(VAULT)
        if kind in ("deep-dive", "meta") or rel.parts[0] == "4-archive":
            continue
        listed.append((field(frontmatter, "last_worked_on"), rel, kind, field(frontmatter, "status"), field(frontmatter, "description")))
    listed.sort(reverse=True)
    lines.append("Notes, newest first (type, status, last worked on):")
    for date, rel, kind, status, description in listed[:BRIEF_LIMIT]:
        lines.append(f"- {rel} ({', '.join(filter(None, (kind, status, date)))}): {description}")
    if len(listed) > BRIEF_LIMIT:
        lines.append(f"- {len(listed) - BRIEF_LIMIT} more: run python3 {tilde(SELF)} index")
    print("\n".join(lines))


if __name__ == "__main__":
    commands = {"index": index, "tokens": tokens, "match": match, "context": context}
    if len(sys.argv) < 2 or sys.argv[1] not in commands or (sys.argv[1] in ("match", "context") and len(sys.argv) < 3):
        sys.exit(__doc__)
    commands[sys.argv[1]](sys.argv[2:])
