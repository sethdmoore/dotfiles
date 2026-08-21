# lsq — Logseq helper for notes-to-linear

A single-file, **zero-dependency** Go CLI (stdlib only) that wraps the Logseq local HTTP API and
owns the canonical note-signature hashing used by the `notes-to-linear` skill's two-way sync.
Keeping the hashing in a compiled binary makes it byte-identical on every run — no LLM-derived
drift — which is what change-detection relies on.

Linear is deliberately **not** touched here; that stays on the claude.ai MCP connector.

## Build / vendor

No external modules, so vendoring is a no-op but supported:

```sh
go mod vendor        # creates nothing (stdlib only) — safe to run
go build -o lsq .    # native build
GOOS=linux GOARCH=amd64 go build -o lsq .   # for the Claude Code Linux container
```

Drop the resulting `lsq` on `PATH` (e.g. mount/copy to `~/.local/bin/lsq`).

## Environment

- `LOGSEQ_API_TOKEN` — required (bearer token for the Logseq HTTP API server).
- `LOGSEQ_API_URL` — optional; default `http://host.docker.internal:12315/api`.
  Tolerant of a missing `/api` suffix (it's appended automatically).

## Commands

| Command | Output | Wraps |
|---|---|---|
| `lsq scan <page>` | JSON array of candidate blocks (index + `changed` flags), lean — no child bodies | getPageBlocksTree + walk + hash |
| `lsq get <uuid>` | JSON: one block's full subtree with per-node `done` flags | getBlock(includeChildren) |
| `lsq sig <uuid>` | JSON `{uuid, sig, hash}` — canonical signature + 12-hex hash | getBlock(includeChildren) |
| `lsq prop <uuid> <key> <value>` | `ok` | upsertBlockProperty |
| `lsq append <uuid> <text>` | JSON `{uuid}` of the new child | insertBlock (child) |
| `lsq done <uuid>` | JSON `{uuid, first, hash}` (hash = post-change) | updateBlock (leading DONE marker) |

A candidate block is any block that has a `#TODO`/`#todo` tag (or leading TODO/DOING marker) **or**
carries a `linear-id` property. A candidate owns its whole subtree — the walk does not descend into
it looking for more candidates.

## Link metadata (block properties)

Each linked note carries its Linear link as properties on the TODO parent block, all set via
`lsq prop`:

| Property | Meaning |
|---|---|
| `linear-id` | Issue identifier, e.g. `SEC-301`. Its presence = the note is linked. **The stable key.** |
| `linear-url` | Canonical issue URL. |
| `linear-origin` | `logseq` (skill created the issue) or `linear` (pre-existing; note linked later). Sets conflict precedence. |
| `linear-synced` | ISO-8601 time of last sync. Compared against the issue's `updatedAt` to detect Linear-side changes. |
| `linear-hash` | The content hash below at last sync. Compared against the current hash to detect Logseq-side changes. |

## Gotchas

- **Block UUIDs are not stable in this graph** — an external process regenerates blocks (new uuid)
  while preserving properties. Key on `linear-id`, `scan` fresh every run, never cache/hard-code a
  uuid. (A stale uuid makes `lsq get/sig/done` error; `prop` on a stale uuid could orphan a block.)
- **Property read-back is camelCased**: you write `linear-id` but Logseq's `getBlock` returns it as
  `properties.linearId`. `lsq` handles this internally (it reads from both content and the map).
- **Legacy links**: older runs wrote a child block `Linear: [ID](url) #linear-synced` instead of
  properties. Treat as `origin: logseq`, migrate to properties, remove the child block.

### Canonical signature (must stay stable)

`sig` = the block's cleaned first-line/content followed by every **open** (non-DONE) descendant's
cleaned content, joined by newlines and trimmed. "Cleaned" = drop property lines (containing `::`),
strip `#TODO/#todo/#DOING/#doing` tags, trim. `hash` = first 12 hex of SHA-1(sig).

Do not change this algorithm without re-stamping every `linear-hash` property, or all issues will
read as changed on the next run.
