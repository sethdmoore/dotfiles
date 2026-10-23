#!/usr/bin/env python3
"""Helpers for Claude's Obsidian vault, $CLAUDE_VAULT or ~/Documents/obsidian/vaults/claude.

  notes.py <note ...>                 print each note whole
  notes.py +<section> ... <note ...>  print only the named sections, e.g. +summary +references, or +top for the text above the first section
  notes.py -<section> ... <note ...>  print each note without the named sections, e.g. -summary
  notes.py index [dir]                one line per note: tokens, last_worked_on, path, description
  notes.py tokens [file ...]          set the `tokens` field of each note (default: every note), then check it
  notes.py check [file ...]           Summary first, References last, every [[link]] resolves
  notes.py match <dir>                notes whose `paths` field contains dir, closest first
  notes.py context <dir>              the brief the SessionStart hook injects: the note that claims dir, or the newest notes
  notes.py fold-memory <dir ...>      move memories saved before the vault existed into memory/, and index them
  notes.py stop                       the Stop hook: commits the turn's vault edits, prints a block decision or nothing

A note is a path, or a link target such as claude-workflow/hooks. A section is
a `## ` heading, named in lowercase with dashes (`## Deep dives` is deep-dives),
or by a prefix that only one heading has.
"""
import datetime
import fnmatch
import json
import math
import os
import pathlib
import re
import subprocess
import sys
import textwrap
import time

VAULT = pathlib.Path(os.environ.get("CLAUDE_VAULT", "~/Documents/obsidian/vaults/claude")).expanduser().resolve()
SELF = pathlib.Path(__file__).absolute()
HOME = pathlib.Path.home()
SKIP = {".obsidian", "templates", "memory"}
PARA = {"1-projects", "2-areas", "3-resources", "4-archive"}
HIDDEN = {".git", ".obsidian", ".trash"}
TOKENS = re.compile(r"^tokens:.*$", re.M)
FENCE = re.compile(r"^(```|~~~)")
LINK = re.compile(r"!?\[\[([^\]|#]*)[^\]]*\]\]")
CODE = re.compile(r"^(```|~~~).*?^\1[^\n]*$|`[^`\n]*`", re.M | re.S)
BRIEF_LIMIT = 3
NEXT_LIMIT = 100
SCRATCH = [pathlib.Path(p).resolve() for p in ("/tmp", "/private/tmp", "/var/folders")]
SUMMARY_LIMIT = 150
# Frontmatter a note needs beyond description, last_worked_on and created. The vault CLAUDE.md has the table.
REQUIRED = {
    "project": ("status", "next_action", "area", "paths"),
    "area": ("paths",),
    "deep-dive": ("project",),
    "resource": (),
    "meta": (),
}


def notes(paths):
    if paths:
        found = [resolve(p) for p in paths]
        missing = [p for p, f in zip(paths, found) if f is None]
        if missing:
            sys.exit(f"no note matches {', '.join(missing)}")
        return found
    # The vault CLAUDE.md is the rules, not a note, and on an old vault it has no frontmatter.
    return sorted(p for p in VAULT.rglob("*.md") if not SKIP & set(p.relative_to(VAULT).parts) and p != VAULT / "CLAUDE.md")


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


def top_text(text):
    """The text after the frontmatter and before the first `## ` heading."""
    head, _ = sections(text)
    frontmatter, _ = split(text)
    if frontmatter is None:
        return head
    return head[len(frontmatter):].split("\n", 2)[-1].lstrip("\n")


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
    kind = field(frontmatter, "type")
    if kind not in REQUIRED:
        found.append(f"frontmatter `type` is `{kind}`, not one of {', '.join(REQUIRED)}")
    for name in ("description", "last_worked_on", "created", *REQUIRED.get(kind, ())):
        if not (listfield(frontmatter, name) if name == "paths" else field(frontmatter, name)):
            found.append(f"frontmatter `{name}` is empty, and a {kind or 'note'} needs it")
    if kind not in ("", "meta") and path.is_relative_to(VAULT) and path.relative_to(VAULT).parts[0] not in PARA:
        found.append("the note is outside the PARA folders, see Migrating a vault to PARA in the vault CLAUDE.md")
    if kind not in ("", "meta"):
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
    paths = [resolve(target) for target in targets]
    for target, path in zip(targets, paths):
        if path is None:
            print(f"no note matches {target}", file=sys.stderr)
            status = 1
            continue
        text = path.read_text()
        if sum(p is not None for p in paths) > 1:
            print(f"==> {shown(path)} <==")
        if not selectors:
            print(text.rstrip())
            continue
        head, parts = sections(text)
        names = [name for name, _ in parts]
        chosen, with_top = set(), False
        for selector in selectors:
            if signs == {"+"} and slug(selector[1:]) == "top":
                with_top = True
                continue
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
            body = ([top_text(text)] if with_top else []) + [parts[i][1] for i in sorted(chosen)]
            if body:
                print("".join(body).rstrip())
            rest = [f"{name} {estimate(part)}" for i, (name, part) in enumerate(parts) if i not in chosen]
            if rest:
                print(f"(not loaded: {', '.join(rest)})")
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
            print(f"{estimated:>6}  {shown(path)}")
    report(paths)


def check(args):
    sys.exit(0 if report(notes(args)) else 1)


def match(args):
    for path in matches(args[0]):
        print(path)


def context(args):
    matched = matches(args[0])
    command = f"python3 {tilde(SELF)}"
    lines = [f"Your Obsidian vault at {tilde(VAULT)} is your memory of projects across sessions. Before you write a note, run `{command} +top CLAUDE`, which names the sections to load. Do not read the whole file."]
    if not matched and any(pathlib.Path(args[0]).expanduser().resolve().is_relative_to(s) for s in SCRATCH):
        print(lines[0])
        return
    if not matched:
        lines.append("No note lists this directory in `paths`. If Seth asks to resume without naming a project, show him the first three notes below with their next step, and ask which one. If the work here will span sessions, add the directory to a note's `paths`, or create a project note.")
    for path in matched:
        _, parts = sections(path.read_text())
        summary = [part for name, part in parts if name == "summary"]
        if not summary:
            lines.append(f"This directory belongs to {tilde(path)}. Load it with `{command} {tilde(path)}` before you work on the project.")
            continue
        rest = ", ".join(f"{name} {estimate(part)}" for name, part in parts if name != "summary")
        lines.append(f"Note: {tilde(path)}. Rest: `{command} -summary {tilde(path)}`, or `+<section>`: {rest}.")
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
    for date, _, rel, kind, status, description, next_action in listed[:BRIEF_LIMIT]:
        line = f"- {rel} ({', '.join(filter(None, (kind, status, date)))}): {description}"
        if next_action:
            line += f" Next: {textwrap.shorten(next_action, NEXT_LIMIT, placeholder='...')}"
        lines.append(line)
    if len(listed) > BRIEF_LIMIT:
        lines.append(f"- {len(listed) - BRIEF_LIMIT} more. For the full list, run `{command} index`.")
    print("\n".join(lines))


def fold_memory(args):
    """Each file moves into memory/ with an index line, unless memory/ already has its name. Those stay for a session to merge."""
    memory = VAULT / "memory"
    memory.mkdir(exist_ok=True)
    index = memory / "MEMORY.md"
    added, kept = [], []
    for directory in (pathlib.Path(a) for a in args):
        for path in sorted(directory.iterdir()):
            if path.name == "MEMORY.md":
                path.unlink()
            elif (memory / path.name).exists():
                kept.append(path)
            else:
                frontmatter, _ = split(path.read_text()) if path.suffix == ".md" else (None, "")
                title = (field(frontmatter or "", "name") or path.stem).replace("-", " ").capitalize()
                added.append(f"- [{title}]({path.name}): {field(frontmatter or '', 'description')}")
                path.rename(memory / path.name)
        if not any(directory.iterdir()):
            directory.rmdir()
    if added:
        text = index.read_text() if index.exists() else ""
        index.write_text(text.rstrip("\n") + f"\n\n## Folded in by make vault, sort these\n" + "\n".join(added) + "\n")
        print(f"folded {len(added)} memories into {tilde(memory)}")
    for path in kept:
        print(f"kept {tilde(path)}: memory/ already has {path.name}. Ask Claude to merge it.")
    for directory in (pathlib.Path(a).parent for a in args):
        if directory.exists() and not any(directory.iterdir()):
            directory.rmdir()


EDITORS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}


def lines_backward(path, chunk=1 << 20):
    with open(path, "rb") as f:
        end = f.seek(0, os.SEEK_END)
        rest = b""
        while end > 0:
            start = max(0, end - chunk)
            f.seek(start)
            lines = (f.read(end - start) + rest).split(b"\n")
            # Above the start of the file, the first piece is the end of a line the next chunk back begins.
            rest = lines.pop(0) if start else b""
            end = start
            yield from reversed(lines)


def last_turn(transcript):
    """When the last prompt arrived, and each file an edit tool wrote since. Reads back from the end of the transcript."""
    edited = set()
    for line in lines_backward(transcript):
        try:
            entry = json.loads(line)
        except ValueError:
            continue
        content = (entry.get("message") or {}).get("content")
        # A prompt carries a string content, and a tool result carries a list.
        if entry.get("type") == "user" and isinstance(content, str):
            return datetime.datetime.fromisoformat(entry["timestamp"].replace("Z", "+00:00")).timestamp(), edited
        if entry.get("type") == "assistant" and isinstance(content, list):
            for block in content:
                tool_input = block.get("input") or {}
                path = tool_input.get("file_path") or tool_input.get("notebook_path")
                if block.get("type") == "tool_use" and block.get("name") in EDITORS and path:
                    edited.add(pathlib.Path(path).expanduser().resolve())
    return None, edited


def stale_notes(edited):
    """Live notes that track a file the turn edited, when the turn updated none of the notes that track it."""
    stale = []
    # A note may track the vault itself, and editing the vault is note upkeep, not work to record.
    for directory in sorted({p.parent for p in edited if not p.is_relative_to(VAULT)}):
        matched = [n for n in matches(directory) if n.relative_to(VAULT).parts[0] != "4-archive"]
        if not edited & set(matched):
            stale += [n for n in matched if n not in stale]
    return stale


def git(*args):
    return subprocess.run(["git", "-C", str(VAULT), *args], capture_output=True, text=True, timeout=5, check=True).stdout


def commit_message(names):
    head = "vault: update "
    text = head + ", ".join(names)
    if len(text) <= 72 or len(names) == 1:
        return text
    kept = names[:1]
    for name in names[1:]:
        if len(head + ", ".join(kept + [name]) + f" and {len(names) - len(kept) - 1} more") > 72:
            break
        kept.append(name)
    return head + ", ".join(kept) + f" and {len(names) - len(kept)} more"


def auto_commit(edited):
    """Commit the vault files this turn edited. The pathspec keeps other sessions' staged and unstaged work out."""
    paths = [os.path.relpath(p, VAULT) for p in edited if p.is_relative_to(VAULT)]
    if not paths:
        return
    entries = git("status", "--porcelain", "-z", "-uall", "--", *paths).split("\0")
    changed = [entry[3:] for entry in entries if entry]
    if not changed:
        return
    git("add", "-A", "--", *changed)
    identity = []
    # The claude-cli container has no git config, so borrow the author of the last vault commit.
    if subprocess.run(["git", "-C", str(VAULT), "config", "user.email"], capture_output=True, timeout=5).returncode:
        name, email = git("log", "-1", "--format=%an%n%ae").splitlines()
        identity = ["-c", f"user.name={name}", "-c", f"user.email={email}"]
    git(*identity, "commit", "-q", "-m", commit_message(changed), "--", *changed)


def stop(args):
    """The Stop hook. Commits the turn's vault edits, and prints a block decision for stale notes, or nothing. Any error allows the stop."""
    try:
        event = json.load(sys.stdin)
        if not (VAULT / "CLAUDE.md").is_file():
            return
        start, edited = last_turn(event["transcript_path"])
        # Runs before the early returns, so a turn that updates a stale note still gets its commit.
        try:
            auto_commit(edited)
        except Exception:
            pass
        # stop_hook_active is true when this stop follows a block from this hook. Allow it, or the loop never ends.
        if event.get("stop_hook_active") or start is None or not edited or time.time() - start <= int(os.environ.get("CLAUDE_VAULT_STOP_SECONDS", 180)):
            return
        stale = stale_notes(edited)
        if stale:
            ask = f"Update vault note {', '.join(map(shown, stale))} for this turn: State, status, next_action, last_worked_on, References, then python3 {tilde(SELF)} tokens <note>."
            print(json.dumps({"decision": "block", "reason": "Before you stop: " + ask, "suppressOutput": True}))
    except Exception:
        return


if __name__ == "__main__":
    commands = {"index": index, "tokens": tokens, "check": check, "match": match, "context": context, "fold-memory": fold_memory, "stop": stop}
    if len(sys.argv) < 2 or (sys.argv[1] in ("match", "context", "fold-memory") and len(sys.argv) < 3):
        sys.exit(__doc__)
    if sys.argv[1] in commands:
        commands[sys.argv[1]](sys.argv[2:])
    else:
        show(sys.argv[1:])
