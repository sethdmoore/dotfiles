---
name: todo
description: Add, check off, remove or list items in Seth's TODO list or Claude's own TODO list. Use when Seth says "add to my TODO", "put it in your TODO", "what's on my list", "mark that done", or defers a task to a later date.
argument-hint: "[add|done|remove|list] [mine|yours] [task]"
---

# TODO lists

## Files

- Seth's: `~/Documents/obsidian/vaults/p0/TODO.md`. Grouped by `## <topic>` sections. Add an item under the matching section, or `## Other`.
- Claude's: `~/Documents/obsidian/vaults/claude/TODO.md`, with `## Dated` and `## Undated`. Create it from the frontmatter of another vault note if it is missing.
- Only the list for the vault on this machine. The `home` vault never exists on a work host.

## Item format

```
- [ ] <task> 📅 YYYY-MM-DD [[<project>]]
	- `cd <session dir> && claude --resume <session-id>`
```

- The date and the project link are optional. The date is the Obsidian Tasks format.
- Add the resume line when the item continues a Claude session. The session ID is the name of the scratchpad folder. The directory is where the session started.
- Seth's file indents sub-bullets with a tab. Claude's uses two spaces.

## Operations

- Add: Read the file, then Edit in the one line (and its sub-bullet).
- Done: change `- [ ]` to `- [x]`.
- Remove: delete the line and its sub-bullets, only when Seth asks.
- List: show open items, dated ones first, and flag any past their date.

Change only the lines the request names. Never reorder or reword Seth's other items.
