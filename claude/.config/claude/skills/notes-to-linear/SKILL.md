---
name: notes-to-linear
description: Two-way sync between Logseq TODO notes and Linear issues. Reads a Logseq page (default today's journal), extracts open #TODO blocks, and reconciles them with Linear — creating issues, pushing note edits out, pulling Linear edits back, and syncing DONE both ways. Link metadata lives in block properties on the note. Always dry-runs and confirms before writing. Invoke as /notes-to-linear [page name or date].
---

# notes-to-linear

Load the `lsq` skill first. It is required to reach LogSeq.

Keep Logseq TODO notes and Linear issues in step — mostly two-way. **Every write (Linear or Logseq)
is confirmed by me first: always dry-run (Step 4) before writing anything.**

## Tooling
- **Logseq**: everything (reads, writes, and the canonical content hashing) goes through the `lsq`
  helper — a zero-dep Go binary. Resolve it, first hit wins: (1) `command -v lsq`; (2) co-located
  `~/.claude/skills/notes-to-linear/lsq/lsq`; (3) build it — `cd ~/.claude/skills/notes-to-linear/lsq && go build -o lsq .`.
  If it truly can't run, read `lsq/main.go` and drive the Logseq HTTP API the same way it does — do
  **not** invent ad-hoc curl flows otherwise. Run `lsq` with no args for usage.
- **Linear**: claude.ai MCP connector — `mcp__claude_ai_Linear__*` (`list_teams`, `list_users`,
  `get_issue`, `save_issue`).
- **How links & hashing work**: see `lsq/README.md`. Key facts: each linked note stores
  `linear-id / linear-url / linear-origin / linear-synced / linear-hash` as block properties (all
  managed by `lsq`); **`linear-id` is the stable key — block UUIDs are not**, so always re-`scan`
  each run and never cache a uuid.

## Step 1 — Mapping
Read `~/.claude/notes-to-linear-map.json`. **Default team is ALWAYS Security** (shield) — never
`P0 security` (lock). Default assignee is me. Person-tags (`#courtney`, `#greg`) mean *who asked*,
not the assignee. If a needed tag/team isn't mapped, ask, then offer to save it back.

## Step 2 — Scan
`lsq scan "<page>"` (default page: today's journal; use the arg if I gave one). Returns candidate
blocks with `uuid, title, todo, done, tags, hash, linear` (metadata or absent) and `changed`
(logseq-side). Use `lsq get <uuid>` for a block's full subtree when you need child bodies.

## Step 3 — Derive + classify each candidate
**Payload:**
- **Title**: imperative phrase, tags stripped.
- **Description**: a real, self-contained ticket built from the child bullets — a short summary, then
  structure (checklist of things to do/cover, timeline/dates), grandchildren nested under parents,
  DONE children excluded. **Never** a bare title. **Never** an origin/"from my notes" blurb — Linear
  is a public tracker; the note link lives only in block properties.
- **Priority**: `#priority` → High (2), else default (0). **Assignee/labels** from the mapping.

**Classify:**
- **Unlinked** (no `linear-id`): DONE → skip ("done, never synced"); open → **CREATE** (origin `logseq`).
- **Linked**: `get_issue`, then `logseqChanged` = scan's `changed`; `linearChanged` =
  `issue.updatedAt > linear-synced`; plus `logseqDone` and `linearDone` (`statusType` completed/canceled).
  - **Content** — one side changed wins; prompt only when *both* did:

    | logseqChanged | linearChanged | action |
    |---|---|---|
    | no | no | none |
    | yes | no | **push** Logseq→Linear |
    | no | yes | **pull** Linear→Logseq |
    | yes | yes | **conflict → PROMPT** (recommend: `logseq`-origin → Logseq wins; `linear`-origin → Linear wins) |
  - **Status** (always, independent of content): `logseqDone && !linearDone` → set Linear Done/Canceled;
    `linearDone && !logseqDone` → `lsq done <uuid>`.
  - **PULL is additive-only**: a Linear description is a lossy flattening of a richer note, so
    **never delete/overwrite** note blocks. Append only genuinely net-new Linear content as child
    blocks (`lsq append`); reflect status/PR changes as a short appended note; list apparent
    "removals" for me to review rather than acting on them.

## Step 4 — Dry-run + confirm
Print a table of planned actions grouped by type (create / push / pull / status→Linear /
status→Logseq / conflict / no-change / skipped), each with id, title, and a one-line preview.
**Write nothing yet.** Resolve every conflict row with me. Proceed only on explicit yes.

## Step 5 — Execute + write back
- **CREATE**: `save_issue` (no `id`). **PUSH**: `save_issue` with `id` (title/description/priority).
  **STATUS→Linear**: `save_issue` with `state`. **STATUS→Logseq**: `lsq done <uuid>`. **PULL**: `lsq append`.
- Then write link metadata on the parent via `lsq prop <uuid> <key> <value>`: `linear-id`,
  `linear-url`, `linear-origin`, `linear-synced` (post-write `updatedAt`), `linear-hash`
  (from `lsq sig <uuid>`, **after** any note edits). Migrate any legacy `#linear-synced` child link
  to properties. If a write-back fails, WARN me and name the issues lacking metadata — they'd
  duplicate or re-fire next run.

## Step 6 — Report
Summarize by bucket: created, pushed, pulled, status-synced (each direction), conflicts + how
resolved, no-change, skipped, write-back failures — each with identifier + URL.

## Guardrails
- No write to Linear or Logseq without the Step 4 confirmation; resolve every conflict with me.
- Team = **Security**, never `P0 security`, unless a note clearly targets another.
- Descriptions are real tickets built from the sub-bullets — never a bare title, never a provenance blurb.
- DONE-flips and pulls edit note text — only ever within the linked block's own subtree/properties.
- Never overwrite a `linear`-origin issue's content with note contents.
- Hashing is owned by `lsq` — read it, never hand-compute.
- If Linear or Logseq is unreachable/unauthed, stop and report; never partially sync silently.
