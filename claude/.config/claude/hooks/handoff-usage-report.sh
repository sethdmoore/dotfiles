#!/usr/bin/env bash
# Compare handoff summaries against /compact, from handoffs/usage.jsonl and
# the compact_boundary records in every transcript.
#
#   handoff-usage-report.sh [--json]
#
# cost_eq is in base-input-token units (see handoff-usage.sh). Estimates:
#   handoff write  = 0.1 * context + 5 * handoff tokens
#                    (one more cached turn, plus the summary as output)
#   compact (warm) = 0.1 * pre + 5 * summary tokens
#   compact (cold) = 1.0 * pre + 5 * summary tokens
#                    (the cache expired, so the pass re-reads everything)
# The compaction call leaves no usage record in the transcript, so warm
# and cold bracket its real cost. Measured columns are not estimates.
set -u
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
log="${cfg}/handoffs/usage.jsonl"
json=false; [ "${1:-}" = "--json" ] && json=true

# First assistant message context of a transcript: the baseline a fresh
# session pays before any work.
first_ctx() {
  [ -f "$1" ] || { echo null; return; }
  jq -c 'select(.type == "assistant" and .message.usage != null) | .message.usage | (.input_tokens + .cache_creation_input_tokens + .cache_read_input_tokens)' "$1" 2>/dev/null | head -n 1 | grep . || echo null
}

handoffs=$([ -f "$log" ] && jq -c 'select(.event == "handoff")' "$log" || true)
starts=$([ -f "$log" ] && jq -c 'select(.event == "session_start")' "$log" || true)

# Attach to each session_start the measured first-message context.
starts_ctx=$(while IFS= read -r s; do
  [ -n "$s" ] || continue
  t=$(jq -r '.transcript // empty' <<<"$s")
  jq -c --argjson c "$(first_ctx "$t")" '. + {first_context: $c}' <<<"$s"
done <<<"$starts")

compacts=$(for f in "$cfg"/projects/*/*.jsonl; do
  [ -f "$f" ] || continue
  grep -q '"compact_boundary"' "$f" 2>/dev/null || continue
  "$here/handoff-usage.sh" compactions "$f"
done)

if $json; then
  jq -cs '{handoffs: .[0], session_starts: .[1], compactions: .[2]}' \
    <(jq -s . <<<"$handoffs") <(jq -s . <<<"$starts_ctx") <(jq -s . <<<"$compacts")
  exit 0
fi

k() { jq -r 'if . == null then "-" else (. / 1000 | round | tostring + "K") end' <<<"${1:-null}"; }

echo "HANDOFFS (from usage.jsonl)"
printf '%-17s %-22s %8s %8s %9s %8s %9s\n' when project context handoff write_eq turn_s next_ctx
while IFS= read -r h; do
  [ -n "$h" ] || continue
  IFS=$'\x1f' read -r ts cwd ctx ht el <<<"$(jq -r '[.ts, .cwd, .context_tokens, .handoff_tokens, .turn_elapsed_s] | map(tostring) | join("\u001f")' <<<"$h")"
  # The next fresh session for the same cwd shows what the resume cost.
  nxt=$(jq -r --arg cwd "$cwd" --arg ts "$ts" 'select(.cwd == $cwd and .ts > $ts and (.source == "startup" or .source == "clear")) | .first_context' <<<"$starts_ctx" | head -n 1)
  write=$(jq -n --argjson c "$ctx" --argjson t "$ht" '0.1 * $c + 5 * $t | floor')
  printf '%-17s %-22s %8s %8s %9s %8s %9s\n' "${ts:0:16}" "${cwd##*/}" "$(k "$ctx")" "$ht" "$(k "$write")" "$el" "$(k "${nxt:-null}")"
done <<<"$handoffs"

echo
echo "COMPACTIONS (from transcripts)"
printf '%-17s %-22s %-7s %8s %8s %8s %9s %9s %6s\n' when project trigger before after summary warm_eq cold_eq secs
while IFS= read -r c; do
  [ -n "$c" ] || continue
  IFS=$'\x1f' read -r ts t trig pre post before after sum ms <<<"$(jq -r '[.ts, .transcript, .trigger, .pre_tokens, .post_tokens, .context_before, .context_after, .summary_tokens, .duration_ms] | map(tostring) | join("\u001f")' <<<"$c")"
  proj=$(basename "$(dirname "$t")"); proj=${proj##*-}
  warm=$(jq -n --argjson p "$pre" --argjson s "${sum/null/0}" '0.1 * $p + 5 * $s | floor')
  cold=$(jq -n --argjson p "$pre" --argjson s "${sum/null/0}" '$p + 5 * $s | floor')
  printf '%-17s %-22s %-7s %8s %8s %8s %9s %9s %6s\n' "${ts:0:16}" "$proj" "$trig" "$(k "$before")" "$(k "$after")" "${sum}" "$(k "$warm")" "$(k "$cold")" "$((ms / 1000))"
done <<<"$compacts"

echo
echo "FRESH SESSION BASELINE (first message context, from session_start events)"
jq -r 'select(.first_context != null and (.source == "startup" or .source == "clear")) | "\(.ts[0:16])  \(.cwd | split("/") | last)  first_ctx=\(.first_context / 1000 | round)K  handoff=\(.handoff_tokens) tokens"' <<<"$starts_ctx" | tail -n 10
