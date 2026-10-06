#!/usr/bin/env bash
# Token usage from a Claude Code transcript, for the handoff hooks.
#
# Usage:
#   handoff-usage.sh stats TRANSCRIPT [TURN_START_EPOCH]   -> one JSON object
#   handoff-usage.sh compactions TRANSCRIPT                -> one JSON object per compaction
#
# The transcript format is internal to Claude Code and can change between
# releases. Every number here is approximate. Known shape as of 2.1.285:
#   - One assistant message is written as several records, one per content
#     block, all with the same message.id and the same usage. Dedupe by id.
#   - message.usage carries input_tokens, cache_creation_input_tokens,
#     cache_read_input_tokens, output_tokens, and cache_creation.{5m,1h}.
#   - The context window size at a message is input + cache_creation +
#     cache_read of that message.
#   - A compaction writes a system record with subtype compact_boundary and
#     compactMetadata.{trigger,preTokens,postTokens,durationMs}, plus a user
#     record with isCompactSummary=true that holds the summary text.
#
# weighted = input + 1.25*cache_5m_writes + 2*cache_1h_writes + 0.1*cache_reads
# follows Anthropic's published cache multipliers, so it is the input cost in
# base-input-token units. cost_eq adds output at 5x, the ratio every current
# Claude model uses. Multiply cost_eq by the model's base input price per
# token for a dollar figure.
set -u

# Cheap first pass: shrink each assistant record to a few fields, so the
# second pass can slurp without holding tool results in memory.
_assistant_rows() {
  jq -c 'select(.type == "assistant" and .message.usage != null)
         | {id: .message.id, ts: .timestamp,
            i: (.message.usage.input_tokens // 0),
            cc: (.message.usage.cache_creation_input_tokens // 0),
            c5: (.message.usage.cache_creation.ephemeral_5m_input_tokens // null),
            c1: (.message.usage.cache_creation.ephemeral_1h_input_tokens // 0),
            cr: (.message.usage.cache_read_input_tokens // 0),
            o: (.message.usage.output_tokens // 0)}' "$1" 2>/dev/null
}

# stats TRANSCRIPT [TURN_START_EPOCH]
stats() {
  local transcript=$1 start=${2:-0}
  local turns
  turns=$(jq -r 'select(.type == "user" and (.message.content | type) == "string") | .type' "$transcript" 2>/dev/null | wc -l | tr -d ' ')
  _assistant_rows "$transcript" | jq -s --argjson start "$start" --argjson turns "$turns" '
    def epoch: (sub("\\.[0-9]+"; "") | fromdateiso8601);
    # A row missing the 5m/1h split counts all writes as 5m.
    def c5: (if .c5 == null then .cc else .c5 end);
    def weighted: (.i + 1.25 * c5 + 2 * .c1 + 0.1 * .cr);
    def sum(f): (map(f) | add // 0);
    def roll: {
      messages: length,
      input: sum(.i), cache_write: sum(.cc), cache_read: sum(.cr), output: sum(.o),
      weighted_input: (sum(weighted) | floor),
      cost_eq: ((sum(weighted) + 5 * sum(.o)) | floor)
    };
    (unique_by(.id) | sort_by(.ts)) as $all
    | ($all | map(select((.ts | epoch) >= $start))) as $turn
    | ($all | last) as $l
    | {
        turns: $turns,
        context_tokens: (if $l then ($l.i + $l.cc + $l.cr) else 0 end),
        session: ($all | roll),
        turn: ($turn | roll)
      }'
}

# compactions TRANSCRIPT -> one JSON line per compact_boundary, with the
# measured context size of the last message before and the first after.
compactions() {
  local transcript=$1
  {
    _assistant_rows "$transcript" | jq -c '{k: "a", ts, ctx: (.i + .cc + .cr)}'
    jq -c 'select(.type == "system" and .subtype == "compact_boundary")
           | {k: "c", ts: .timestamp, m: .compactMetadata}' "$transcript" 2>/dev/null
    jq -c 'select(.isCompactSummary == true)
           | {k: "s", ts: .timestamp,
              chars: (.message.content | if type == "string" then length else (map(.text // "") | join("") | length) end)}' "$transcript" 2>/dev/null
  } | jq -cs --arg t "$transcript" '
    sort_by(.ts) as $rows
    | [ range(0; $rows | length) as $i
        | $rows[$i] | select(.k == "c")
        | ($rows[:$i] | map(select(.k == "a")) | last) as $before
        | ($rows[$i+1:] | map(select(.k == "a")) | first) as $after
        | ($rows[:$i+2] | map(select(.k == "s")) | last) as $sum
        | { event: "compact", ts: .ts, transcript: $t,
            trigger: .m.trigger,
            pre_tokens: .m.preTokens, post_tokens: .m.postTokens,
            duration_ms: .m.durationMs,
            context_before: ($before.ctx // null),
            context_after: ($after.ctx // null),
            summary_tokens: (if $sum then ($sum.chars / 4 | floor) else null end) } ]
    | .[]'
}

case "${1:-}" in
  stats) stats "$2" "${3:-0}" ;;
  compactions) compactions "$2" ;;
  *) echo "usage: $0 stats TRANSCRIPT [TURN_START_EPOCH] | compactions TRANSCRIPT" >&2; exit 2 ;;
esac
