---
name: add-to-notes
description: Append an entry to the user's Logseq notes via the local Logseq HTTP gateway. Defaults to today's daily journal; can target a named page or a specific journal date, and supports a parent block with nested child bullets. Use whenever the user says things like "add this to my notes", "log this to my journal", "note this for today", "put this in my daily note", or "add a TODO to my notes". Invoke as /add-to-notes [what to add].
---

# add-to-notes

Write a note into the user's Logseq graph through its local HTTP API gateway. Journal pages are the
default target. This exists so appending a note is one step, not a manual API dance.

## Environment (verified working)
- Gateway: `POST $LOGSEQ_API_URL/api` (currently `http://host.docker.internal:12315/api`), header
  `Authorization: Bearer $LOGSEQ_API_TOKEN`. Both are in the environment — **never print the token.**
- Body shape: `{"method":"<logseq.Editor.*>","args":[...]}`.
- The graph is file-based markdown; workflow is LATER/NOW, so the done marker is `DONE` (not just for
  `#TODO`). Date format is read live from `logseq.App.getUserConfigs.preferredDateFormat`.
- Related: `/notes-to-linear` syncs `#TODO` blocks to Linear. If you add an actionable TODO here that
  should become an issue, tag it `#TODO` and mention that `/notes-to-linear` can sync it.

## Default usage — run the bundled script
The script resolves the target page, appends, and verifies. Prefer it over hand-rolled curl.

```bash
python3 ~/.claude/skills/add-to-notes/append_note.py "PARENT LINE" \
  --child "first detail" --child "second detail"
```

- No `--page`/`--date` → **today's journal**, resolved from `preferredDateFormat`. "Today" is
  computed in **America/New_York** (the user is US Eastern; the container clock is UTC), override
  with `--tz` or pin an exact day with `--date YYYY-MM-DD`.
- `--page "Some Page"` appends to a named page instead of a journal.
- `--dry-run` prints the resolved page + payload without writing — use it first if the target page
  is at all ambiguous.
- A leading `DONE `/`LATER `/`NOW ` on the parent line sets that task marker.

## What to do when invoked
1. Turn the user's request into a **parent line** (a concise headline; prefix `DONE`/`LATER` if it's
   a task) and optional **child bullets** (details, links, evidence). Keep the user's voice; don't
   pad. Markdown (`**bold**`, links) renders in Logseq.
2. If the target isn't clearly "today", confirm the page/date, or run `--dry-run` first.
3. Run the script. Report the resolved page name and the block count it confirmed.
4. Only ask the user for anything if the write fails or the target is genuinely ambiguous — this
   should normally be a single, quiet step.

## Direct API (fallback / advanced)
If you need nesting deeper than one level, block properties, or edits, call the API directly:
- Append top-level block: `logseq.Editor.appendBlockInPage` → `["<page>", "<content>"]` (returns the
  block, including its `uuid`).
- Add children under a block: `logseq.Editor.insertBatchBlock` →
  `["<uuid>", [{"content": "..."}], {"sibling": false}]`.
- Verify: `logseq.Editor.getBlock` → `["<uuid>", {"includeChildren": true}]`.
- Resolve a page's blocks: `logseq.Editor.getPageBlocksTree` → `["<page name>"]`.
- Block properties (non-destructive): `logseq.Editor.upsertBlockProperty` → `["<uuid>","key","val"]`.

## Notes / gotchas
- `insertBatchBlock` returns a null/empty body on success — don't treat that as failure; **verify with
  `getBlock`** (the script does this).
- Block properties written kebab-case (`linear-id`) read back camelCased (`linearId`).
- Writing to notes is an outward action, but a low-stakes one the user explicitly asked for — no
  confirmation needed for a normal "add this" unless the target page is unclear.
