---
name: lsq
description: Query and edit Logseq notes from the shell via the local HTTP API. Use whenever you need to SEARCH the user's Logseq graph for a topic/project, read a page's blocks, or read/annotate a specific block. `lsq search <query>` finds blocks by content across the whole graph; scan/get/sig/prop/append/done operate on a page or block. Invoke the compiled `lsq` binary — do not hand-roll curl calls to the Logseq API.
---

# lsq — Logseq shell helper

`lsq` is a zero-dependency Go binary that wraps the Logseq local HTTP API. It owns the canonical
note-signature hashing used by [[notes-to-linear]] two-way sync, so hashes are byte-identical every
run. Reach for it any time you need to get data out of, or a small annotation into, the user's Logseq
graph.

## ⚠️ If the API is unreachable, the desktop app isn't running

Logseq's HTTP API is served by the **Logseq desktop application** — it only exists while that app is
open. If `lsq` errors with a connection failure, or returns empty/blank for a query you expect to
match, the cause is almost always that **the user forgot to start Logseq**.

Do **NOT** start probing the network, trying alternate ports/methods, or otherwise "ripping apart"
connectivity. **Ask the user to start the Logseq desktop app, then retry.**

## Resolve the binary (first hit wins)

1. `command -v lsq` (if it's on `PATH`)
2. co-located canonical source: `~/.claude/skills/notes-to-linear/lsq/lsq`
3. build it: `cd ~/.claude/skills/notes-to-linear/lsq && go build -o lsq .`
   (or `GOOS=linux GOARCH=amd64 go build -o lsq .` for the Linux container)

Run `lsq` with no args for usage. The source of truth is `~/.claude/skills/notes-to-linear/lsq/main.go`.

## Environment

- `LOGSEQ_API_TOKEN` — **required** (bearer token for the Logseq HTTP API server).
- `LOGSEQ_API_URL` — optional; default `http://host.docker.internal:12315/api`
  (a missing `/api` suffix is appended automatically).

## Commands

| Command | Output |
|---|---|
| `lsq search <query> [limit]` | JSON array of blocks whose content matches `query` (case-insensitive substring), each `{uuid, page, snippet}`. `limit` defaults to 50. Searches the **whole graph** — this is how you find which page/journal a project lives on. |
| `lsq scan <page>` | JSON array of candidate TODO/linked blocks on one page (lean; change flags). |
| `lsq get <uuid>` | JSON: one block's full subtree with per-node `done` flags. |
| `lsq sig <uuid>` | JSON `{uuid, sig, hash}` — canonical signature + 12-hex hash. |
| `lsq prop <uuid> <key> <value>` | set a block property (non-destructive) → `ok`. |
| `lsq append <uuid> <text>` | append a child block → `{uuid}` of the new block. |
| `lsq done <uuid>` | flip a block to a leading DONE marker → `{uuid, first, hash}`. |

Typical flow to find something: `lsq search "<topic>"` → note the `page`/`uuid` of the best hit →
`lsq get <uuid>` for its full subtree (or `lsq scan "<page>"` to see all TODOs on that page).

## How `search` works (and why)

`search` runs a datascript query via `logseq.DB.datascriptQuery`. This Logseq build's query sandbox
has quirks the implementation works around — **do not "simplify" these away**:

- `clojure.string/lower-case` is **not** exposed in the sandbox.
- A regex/string passed as an `:in` parameter arrives as a bare string (`.exec is not a function`).
- The only reliable form is building the pattern **inside** the query with `(re-pattern "…")`, using a
  `(?i)`-flagged, metacharacter-escaped literal (`regexp.QuoteMeta` + `clojureStr`). Hence no `:in`.
- A malformed query returns **HTTP 200 with an `{"error": "..."}` body**, so `cmdSearch` inspects the
  body for `error` and surfaces it rather than silently returning zero hits.

## Guardrails

- Use the compiled `lsq` binary; don't invent ad-hoc curl flows against the Logseq API.
- `search/scan/get/sig` are read-only; `prop/append/done` write to the note — only run them when the
  task calls for it.
- Block UUIDs are **not stable** in this graph (an external process regenerates them). Never cache a
  uuid across runs; re-`search`/`scan` fresh. See [[notes-to-linear]] for the linking model.
- Hashing is owned by `lsq` (`sig`) — read it, never hand-compute.
