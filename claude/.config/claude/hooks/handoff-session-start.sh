#!/usr/bin/env bash
# SessionStart hook. When a handoff summary exists for this project, tell
# the model where it is, so a resume after /clear needs no context.
# Every start is logged to handoffs/usage.jsonl so the report can measure
# what a fresh session costs against what a /compact leaves behind.
set -u

input=$(cat)
cwd=$(jq -r '.cwd // empty' <<<"$input")
[ -n "$cwd" ] || exit 0

cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
slug=$(printf '%s' "$cwd" | tr '/' '-')
handoff="${cfg}/handoffs/${slug}.md"

bytes=0
[ -f "$handoff" ] && bytes=$(wc -c <"$handoff" | tr -d ' ')
mkdir -p "${cfg}/handoffs"
jq -cn --argjson in "$input" --arg h "$handoff" --argjson b "$bytes" '
  {event: "session_start", ts: (now | todate), cwd: $in.cwd,
   session_id: ($in.session_id // null), transcript: ($in.transcript_path // null),
   source: ($in.source // null), handoff: $h, handoff_bytes: $b,
   handoff_tokens: ($b / 4 | floor)}' >>"${cfg}/handoffs/usage.jsonl" 2>/dev/null

[ -f "$handoff" ] || exit 0

when=$(date -r "$handoff" '+%Y-%m-%d %H:%M %Z')
ctx="A handoff summary from an earlier session is at ${handoff}, written ${when}. When the user asks to resume or continue, read that file first."
jq -n --arg ctx "$ctx" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
exit 0
