#!/usr/bin/env python3
"""Helpers for Claude's Obsidian vault, $CLAUDE_VAULT or ~/Documents/obsidian/vaults/claude.

  notes.py <note ...>                 print each note whole
  notes.py +<section> ... <note ...>  print only the named sections, e.g. +summary +references
  notes.py -<section> ... <note ...>  print each note without the named sections, e.g. -summary
  notes.py index [dir]                one line per note: tokens, last_worked_on, path, description
  notes.py tokens [file ...]          set the `tokens` field of each note (default: every note), then check it
  notes.py check [file ...]           Summary first, References last, every [[link]] resolves
  notes.py match <dir>                notes whose `paths` field contains dir, closest first
  notes.py context <dir>              the brief the SessionStart hook injects: the note that claims dir, or every note

A note is a path, or a link target such as claude-workflow/hooks. A section is
a `## ` heading, named in lowercase with dashes (`## Deep dives` is deep-dives),
or by a prefix that only one heading has.
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
HIDDEN = {".git", ".obsidian", ".trash"}
TOKENS = re.compile(r"^tokens:.*$", re.M)
FENCE = re.compile(r"^(```|~~~)")
LINK = re.compile(r"!?\[\[([^\]|#]*)[^\]]*\]\]")
CODE = re.compile(r"^(```|~~~).*?^\1[^\n]*$|`[^`\n]*`", re.M | re.S)
BRIEF_LIMIT = 30
SUMMARY_LIMIT = 150


def notes(paths):
    if paths:
        found = [resolve(p) for p in paths]
        missing = [p for p, f in zip(paths, found) if f is None]
        if missing:
            sys.exit(f"no note matches {', '.join(missing)}")
        return found
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


def shown(path):
    return str(path.relative_to(VAULT)) if path.is_relative_to(VAULT) else tilde(path)


def estimate(text):
    # About 4 characters per token for English markdown. Rounded up to the nearest 10.
    return max(10, math.ceil(len(text) / 40) * 10)


def slug(heading):
    return re.sub(r"[^a-z0-9]+", "-", heading.lower()).strip("-")


def sections(text):
    """The head (frontmatter and any text before the first `## ` heading), then (slug, text) per section.

    A section runs to the next `## ` heading, the rule Obsidian uses for [[note#Heading]].
    """
    head, parts, fenced = [], [], False
    for line in text.splitlines(keepends=True):
        if FENCE.match(line):
            fenced = not fenced
        if not fenced and line.startswith("## "):
            parts.append((slug(line[3:]), [line]))
        elif parts:
            parts[-1][1].append(line)
        else:
            head.append(line)
    return "".join(head), [(name, "".join(lines)) for name, lines in parts]


def pick(wanted, names):
    """Index of the section `wanted` names: an exact slug, else a prefix only one slug has."""
    wanted = slug(wanted)
    if wanted in names:
        return names.index(wanted)
    prefixed = [i for i, name in enumerate(names) if name.startswith(wanted)]
    return prefixed[0] if len(prefixed) == 1 else None


def files():
    return [p for p in VAULT.rglob("*") if p.is_file() and not HIDDEN & set(p.relative_to(VAULT).parts)]


def resolve(name, every=None):
    """The file a path or a link target names. Like Obsidian, a target matches the end of a vault path."""
    path = pathlib.Path(name).expanduser()
    if path.is_file():
        return path.resolve()
    name = re.sub(r"^!?\[\[|\]\]$", "", name).split("|")[0].split("#")[0].strip()
    if not name:
        return None
    hits = []
    for p in every if every is not None else files():
        rel = p.relative_to(VAULT).as_posix()
        if rel.endswith(".md"):
            rel = rel[:-3]
        if rel == name.removesuffix(".md") or rel.endswith("/" + name.removesuffix(".md")):
            hits.append(p)
    return min(hits, key=lambda p: len(p.parts)) if hits else None


def problems(path, every):
    text = path.read_text()
    frontmatter, _ = split(text)
    frontmatter = frontmatter or ""
    _, parts = sections(text)
    names = [name for name, _ in parts]
    found = []
    if field(frontmatter, "type") not in ("", "meta"):
        if names[:1] != ["summary"]:
            found.append("the first section is not ## Summary")
        elif estimate(parts[0][1]) > SUMMARY_LIMIT:
            found.append(f"the Summary is about {estimate(parts[0][1])} tokens, over {SUMMARY_LIMIT}")
        if names[-1:] != ["references"]:
            found.append("the last section is not ## References")
    if listfield(frontmatter, "links"):
        found.append("frontmatter `links` is set, move its URLs into ## References")
    for target in LINK.findall(CODE.sub("", text)):
        if target.strip() and resolve(target, every) is None:
            found.append(f"[[{target}]] matches no file in the vault")
    return found


def report(paths):
    every, clean = files(), True
    for path in paths:
        for problem in problems(path, every):
            print(f"check {shown(path)}: {problem}", file=sys.stderr)
            clean = False
    return clean


def show(args):
    selectors = [a for a in args if a[:1] in "+-" and len(a) > 1]
    targets = [a for a in args if a not in selectors]
    signs = {s[0] for s in selectors}
    if not targets or len(signs) > 1:
        sys.exit("name at least one note, and either +sections or -sections, not both\n" + __doc__)
    status = 0
    for target in targets:
        path = resolve(target)
        if path is None:
            print(f"no note matches {target}", file=sys.stderr)
            status = 1
            continue
        text = path.read_text()
        print(f"==> {shown(path)} <==")
        if not selectors:
            print(text.rstrip())
            continue
        head, parts = sections(text)
        names = [name for name, _ in parts]
        chosen = set()
        for selector in selectors:
            i = pick(selector[1:], names)
            if i is not None:
                chosen.add(i)
            elif signs == {"+"} and slug(selector[1:]) == "summary":
                description = field(split(text)[0] or "", "description")
                print(f"(no Summary section. The description: {description})")
            elif signs == {"+"}:
                print(f"no section {selector[1:]} in {shown(path)}. It has: {', '.join(names)}", file=sys.stderr)
                status = 1
        if signs == {"+"}:
            if chosen:
                print("".join(parts[i][1] for i in sorted(chosen)).rstrip())
            rest = [f"{name} {estimate(part)}" for i, (name, part) in enumerate(parts) if i not in chosen]
            if rest:
                print(f"(Not loaded, tokens each: {', '.join(rest)}. Load one with +<section>.)")
        else:
            print((head + "".join(part for i, (_, part) in enumerate(parts) if i not in chosen)).rstrip())
    sys.exit(status)


def index(args):
    root = (VAULT / args[0]).resolve() if args else VAULT
    for path, frontmatter in frontmatters():
        if not path.is_relative_to(root):
            continue
        tokens, date, description = (field(frontmatter, f) for f in ("tokens", "last_worked_on", "description"))
        print(f"{tokens:>6}  {date:<10}  {path.relative_to(VAULT)}  {description}")


def tokens(args):
    paths = notes(args)
    for path in paths:
        text = path.read_text()
        frontmatter, body = split(text)
        if frontmatter is None or not TOKENS.search(frontmatter):
            print(f"skipped, no tokens field: {path}", file=sys.stderr)
            continue
        estimated = estimate(text)
        updated = TOKENS.sub(f"tokens: {estimated}", frontmatter, count=1) + body
        if updated != text:
            path.write_text(updated)
            print(f"{estimated:>6}  {path.relative_to(VAULT)}")
    report(paths)


def check(args):
    sys.exit(0 if report(notes(args)) else 1)


def match(args):
    for path in matches(args[0]):
        print(path)


def context(args):
    matched = matches(args[0])
    command = f"python3 {tilde(SELF)}"
    lines = [f"Your Obsidian vault at {tilde(VAULT)} is your memory of projects across sessions. Read {tilde(VAULT / 'CLAUDE.md')} before you write a note."]
    if not matched:
        lines.append("No note lists this directory in `paths`. If Seth asks to resume without naming a project, show him the first three notes below with their next step, and ask which one. If the work here will span sessions, add the directory to a note's `paths`, or create a project note.")
    for path in matched:
        _, parts = sections(path.read_text())
        summary = [part for name, part in parts if name == "summary"]
        if not summary:
            lines.append(f"This directory belongs to {tilde(path)}. Load it with `{command} {tilde(path)}` before you work on the project.")
            continue
        rest = ", ".join(f"{name} {estimate(part)}" for name, part in parts if name != "summary")
        lines.append(f"This directory belongs to {tilde(path)}. Its Summary is below and already loaded. When the work needs more, run `{command} -summary {tilde(path)}` for the rest of the note, or `+<section>` for single sections (tokens each: {rest}).")
        lines.append(summary[0].split("\n", 1)[1].strip())
    # Other sessions update the other notes all day, so a claimed directory gets its own note alone.
    if matched:
        print("\n".join(lines))
        return
    listed = []
    for path, frontmatter in frontmatters():
        kind = field(frontmatter, "type")
        rel = path.relative_to(VAULT)
        if kind in ("deep-dive", "meta") or rel.parts[0] == "4-archive":
            continue
        # The file time orders notes that share a date, so the last one touched comes first.
        listed.append((field(frontmatter, "last_worked_on"), path.stat().st_mtime, rel, kind, field(frontmatter, "status"), field(frontmatter, "description"), field(frontmatter, "next_action")))
    listed.sort(reverse=True)
    lines.append("Notes, newest first (type, status, last worked on):")
    for i, (date, _, rel, kind, status, description, next_action) in enumerate(listed[:BRIEF_LIMIT]):
        line = f"- {rel} ({', '.join(filter(None, (kind, status, date)))}): {description}"
        if i < 3 and next_action:
            line += f" Next: {next_action}"
        lines.append(line)
    if len(listed) > BRIEF_LIMIT:
        lines.append(f"- {len(listed) - BRIEF_LIMIT} more: run {command} index")
    print("\n".join(lines))


if __name__ == "__main__":
    commands = {"index": index, "tokens": tokens, "check": check, "match": match, "context": context}
    if len(sys.argv) < 2 or (sys.argv[1] in ("match", "context") and len(sys.argv) < 3):
        sys.exit(__doc__)
    if sys.argv[1] in commands:
        commands[sys.argv[1]](sys.argv[2:])
    else:
        show(sys.argv[1:])
