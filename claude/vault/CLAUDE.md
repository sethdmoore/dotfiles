---
type: meta
description: Rules for Claude's vault on every machine. Read before creating or editing a note.
tokens: 2650
last_worked_on: 2026-10-16
created: 2026-10-08
---

# Claude vault

This vault is Claude's memory of projects across sessions. Claude reads it before work and writes it after, in every working directory. Seth reads it too. Seth's own vaults sit beside this one in `~/Documents/obsidian/vaults`. Leave them alone unless asked.

This file and `templates/` are links into `~/dotfiles/claude/vault`, which `make -C ~/dotfiles/claude` links into the vault on every machine. The rules ship with `notes.py`, so the checker and the rules it enforces never differ. Notes and memories stay on their machine. A change to this file or a template is a dotfiles commit, not a vault commit.

## Purpose

- One overview note per project. It answers three questions: what is this, where does it stand, what is next.
- Detail goes in deep-dive notes inside the project folder. That includes research, proposals, and the directives written for agents. Files a deep dive carries (patches, screenshots, mockups) go in a folder of the same name beside it. Nothing for a project goes in `~/.config/claude`.
- Keep an overview under about 1000 tokens. Move anything longer into a deep dive.
- Project state lives in project notes. `memory/` keeps facts about how to work: feedback, user facts, references.
- `memory/` is Claude Code's auto-memory directory (`autoMemoryDirectory` in `~/.config/claude/settings.json`). Claude Code loads `memory/MEMORY.md` into every session, in every working directory. The harness system prompt sets the format of memory files, not this file. `notes.py` and the dashboard skip this folder.

## Hooks

Two hooks in `~/.config/claude/hooks` connect the vault to every session. They call `~/.config/claude/hooks/notes.py`, which lives in the `claude` package of `~/dotfiles` with the hooks, so it reaches every machine. `CLAUDE_VAULT` overrides the vault path. The claude-cli launcher mounts the vault into its container at the same path. Both hooks skip silently where the vault has no `CLAUDE.md`.

- `vault-session-start.sh` runs `notes.py context <cwd>` and injects the result: the vault path and every note whose `paths` contains the working directory, closest first, each with its Summary. An area claims a broad root such as `~/dev/git/all`, and a project claims its repos, so a session gets both. When no note claims the directory, it lists the active notes instead, newest first. It skips a resumed session.
- `vault-stop.sh` blocks the stop after a turn longer than 60 seconds that changed files a note tracks, when the turn left that note unchanged, and asks for an update. It also asks for a vault commit when a vault file the turn edited is uncommitted. Another session's changes do not count.
- There are no handoff files. A new session resumes from the vault: the brief carries the Summary of the note for the working directory, and any note loads by name with `notes.py`.

## Layout

PARA, with one folder per project:

```
1-projects/<slug>/<slug>.md    overview of an active project
1-projects/<slug>/<topic>.md   deep dive for that project
1-projects/<slug>/<topic>/     files that deep dive carries
2-areas/<slug>/<slug>.md       ongoing responsibility with no end date, with deep dives beside it
3-resources/<slug>.md          reference not tied to one project
4-archive/<slug>/              finished or dropped project, moved whole
memory/                        Claude Code auto-memory, indexed by memory/MEMORY.md
templates/                     one template per note type
Home.md, Projects.base         dashboard for Obsidian
```

PARA, the same on every machine:

- A project has an end state and a next action, and names the area it serves in `area`.
- An area is a responsibility with no end date. It holds the standards its projects keep, and it can own deep dives the way a project does.
- A resource is reference tied to no single project.
- The archive holds a project that is done, dropped, or paused for over 30 days. It keeps its folder and its status, and comes back with one `mv`.
- File names are kebab-case slugs, so shell paths have no spaces.
- Link an overview as `[[<slug>]]` and a deep dive as `[[<slug>/<topic>]]`. The folder prefix keeps a link unique when two projects share a topic name, and it still resolves after the move to `4-archive`.

## Frontmatter

Every note has frontmatter.

| Field            | Notes                                                        | On          |
| ---------------- | ------------------------------------------------------------ | ----------- |
| `type`           | `project`, `deep-dive`, `area`, `resource`, `meta`           | all         |
| `description`    | One or two sentences. Quote it if it contains `: `           | all         |
| `tokens`         | Estimated size of the note. Set by `notes.py tokens`         | all         |
| `last_worked_on` | ISO date of the last real change                             | all         |
| `created`        | ISO date                                                     | all         |
| `status`         | `active`, `paused`, `blocked`, `done`, `dropped`             | project     |
| `next_action`    | One concrete step, small enough to start now                 | project, area |
| `area`           | `"[[<area-slug>]]"`, required                                | project     |
| `project`        | `"[[<slug>]]"`, the project or area the note belongs to      | deep-dive   |
| `paths`          | Local directories where the work happens, never empty on a project. A session started in or under one loads this note, and the hooks match a session by nothing else | project, area |
| `tags`           | Optional                                                     | all         |

## Note body

Every note except `meta` opens with `## Summary` and ends with `## References`. `notes.py check` enforces both, and the frontmatter table above.

- `## Summary`: two to five sentences, under about 150 tokens. What the note is, where it stands, and `[[links]]` to the notes a reader opens next. It condenses the body and adds no fact the body lacks.
- `## References`: the sources behind the facts in the note, one bullet each, so a reader can check a claim instead of trusting it. Web URLs (PRs, issues, docs, Linear, Notion), `owner/repo#123`, Linear IDs, `repo@commit`, and local repository or file paths. Cite only a source the note names or one you opened. Never build a URL you have not seen. A note with no outside source says so in one bullet.
- An overview has three sections between those two:
  - `## State`: what is true now. Rewrite it each session. Do not append.
  - `## Deep dives`: one bullet per deep-dive note, a link plus a few words.
  - `## Log`: dated one-liners, newest first. Keep about ten. Move older lines to `<slug>/log.md`.
- An area has `## Scope`, `## Standards` and `## Projects` between those two.
- The next action lives in frontmatter only.

## Reading a note

Load a note with `notes.py`, the way Claude Code loads a skill: the Summary first, the rest only when the work needs it. Do not load a section twice.

```
notes.py +summary <note>             the Summary alone, and the size of each other section
notes.py -summary <note>             the rest of the note, once its Summary is loaded
notes.py +state +references <note>   the named sections only
notes.py <note>                      the whole note, for a deep dive you will read in full
```

- `notes.py` is `python3 ~/.config/claude/hooks/notes.py`. A note is a path or a link target such as `claude-workflow/hooks`, and one call takes several. A section is its heading in lowercase with dashes, or a prefix only one heading has.
- The session start brief already holds the Summary of the note for the working directory. Load the rest with `-summary`.
- The Edit tool needs a Read of the whole file first. Before you edit a note, Read it instead of loading it with `notes.py`.

## Workflow

1. In a directory no note claims, the session start brief lists the active notes. For the full list, run `python3 ~/.config/claude/hooks/notes.py index` (or `index 1-projects`). Load a note's Summary only when its description says it is relevant.
2. New project: copy `templates/project.md` to `1-projects/<slug>/<slug>.md`, replace `{{date}}`, name its `area`, and list the repos it touches in `paths`. New area: `templates/area.md` to `2-areas/<slug>/<slug>.md`.
3. After working on a project: rewrite State, and the Summary when State changed. Update `status`, `next_action`, `last_worked_on`, add each new source to References, and add a Log line.
4. After every edit, run `python3 ~/.config/claude/hooks/notes.py tokens <changed files>`. It also reports what `check` finds. Fix each problem.
5. Done, dropped, or paused for over 30 days: set `status`, then `mv 1-projects/<slug> 4-archive/`.
6. The vault is a git repository with no remote, one per machine. Commit note and memory changes with the `git-commit` skill and `git -C ~/Documents/obsidian/vaults/claude`, in the turn that made them. Other sessions commit here too, so stage nothing while the skill runs. Once it returns the message, run `git add <files> && git commit` as one command.

## Migrating a vault to PARA

A vault from before PARA keeps its notes in a flat folder such as `projects/`, and `notes.py check` reports the fields they lack. Migrate it once, in one session:

1. Move each overview to `1-projects/<slug>/<slug>.md` with `git mv`, and its deep dives into the same folder, each with `project` set.
2. A note with no end state is an area. Set `type: area`, move it to `2-areas/<slug>/<slug>.md`, and give it `## Scope`, `## Standards` and `## Projects`.
3. Give every project an `area`. The areas on every machine are `claude-workflow` (Claude Code tooling, the vault, the `claude` dotfiles package) and `personal-machines` (Seth's own machines and the rest of dotfiles). Create either from `templates/area.md` when this vault lacks it. A work machine adds work areas. Create any other area only after Seth agrees.
4. Fill a missing `created` from the file's first commit, `git log --diff-filter=A --format=%as -- <file> | tail -n 1`, or else the oldest date in its Log.
5. Fill a missing `paths` with the directories its State and References name that exist on this machine. Ask Seth when none does.
6. Move a project that is done, dropped, or paused for over 30 days to `4-archive/`.
7. Run `notes.py check` until it reports nothing, then commit the vault.
