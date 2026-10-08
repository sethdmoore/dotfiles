#!/usr/bin/env bash
# Stop hook. When the turn ran longer than THRESHOLD seconds and no fresh
# handoff summary exists, block the stop and ask the model to write one.
# The summary lands at ~/.claude/handoffs/<cwd with / as ->.md, one file
# for each project, so a fresh session after /clear can resume from it.
#
# Once a fresh summary exists, the hook appends a one-line token usage
# footer to it and logs the event to handoffs/usage.jsonl, so handoffs can
# be compared against /compact (see handoff-usage-report.sh).
#
# When notes in the Obsidian vault list this directory in `paths` and the
# turn changed none of them, the same block asks for a note update. When the
# vault has uncommitted changes, from any session, it asks for a commit.
# Two Stop hooks that both block may not both reach the model, so the vault
# check lives here instead of in its own hook.
set -u

# 60s forces claude to write a summary
THRESHOLD="${CLAUDE_HANDOFF_THRESHOLD_SECONDS:-60}"

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
input=$(cat)

transcript=$(jq -r '.transcript_path // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
session=$(jq -r '.session_id // empty' <<<"$input")
[ -f "$transcript" ] || exit 0
[ -n "$cwd" ] || exit 0

# The turn starts at the last typed user prompt. A typed prompt carries a
# string content, and a tool result carries an array, so the filter below
# skips tool results. jq parses the timestamp because macOS date has no -d.
# fromdateiso8601 rejects fractional seconds, so sub() strips them.
start_s=$(jq -r 'select(.type == "user" and (.message.content | type) == "string") | .timestamp // empty | sub("\\.[0-9]+"; "") | fromdateiso8601' "$transcript" 2>/dev/null | tail -n 1)
[ -n "$start_s" ] || exit 0

now_s=$(date +%s)
elapsed=$((now_s - start_s))

cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
slug=$(printf '%s' "$cwd" | tr '/' '-')
handoff="${cfg}/handoffs/${slug}.md"
log="${cfg}/handoffs/usage.jsonl"
marker='<!-- usage '

# A summary written during this turn satisfies the rule.
fresh=false
if [ -f "$handoff" ]; then
  mtime=$(date -r "$handoff" +%s)
  [ "$mtime" -ge "$start_s" ] && fresh=true
fi

# note: the vault notes for this directory joined with " or ", left empty
# when the turn already updated one of them.
vault="${CLAUDE_VAULT:-$HOME/Documents/vaults/obsidian/claude}"
note=""
if [ -f "$vault/tools/notes.py" ]; then
  while IFS= read -r n; do
    if [ "$(date -r "$n" +%s)" -ge "$start_s" ]; then
      note=""
      break
    fi
    note="${note:+$note or }$n"
  done < <(python3 "$vault/tools/notes.py" match "$cwd" 2>/dev/null)
fi
dirty=false
[ -n "$(git -C "$vault" status --porcelain 2>/dev/null)" ] && dirty=true

# finalize: append the usage footer and log the event, once per write.
# The footer is an HTML comment so the next session reads it as data,
# not as part of the summary. The token count for the handoff is bytes/4.
finalize() {
  tail -n 1 "$handoff" | grep -q "^${marker}" && return 0
  local stats bytes
  stats=$("$here/handoff-usage.sh" stats "$transcript" "$start_s") || return 0
  bytes=$(wc -c <"$handoff" | tr -d ' ')
  local line
  line=$(jq -rn --argjson s "$stats" --argjson b "$bytes" --arg e "$elapsed" '
    def k: (. / 1000 | round | tostring + "K");
    "\($ENV.marker)\(now | strftime("%Y-%m-%dT%H:%MZ")): context \($s.context_tokens | k) tokens, handoff ~\($b / 4 | round) tokens, turn \($e)s. Session: \($s.turns) turns, \($s.session.messages) msgs, cache read \($s.session.cache_read | k), cache write \($s.session.cache_write | k), output \($s.session.output | k), cost_eq \($s.session.cost_eq | k) -->"')
  printf '\n%s\n' "$line" >>"$handoff"
  jq -cn --argjson s "$stats" --argjson b "$bytes" --arg e "$elapsed" \
     --arg cwd "$cwd" --arg sid "$session" --arg t "$transcript" --arg h "$handoff" '
    {event: "handoff", ts: (now | todate), cwd: $cwd, session_id: $sid, transcript: $t,
     handoff: $h, handoff_bytes: $b, handoff_tokens: ($b / 4 | floor),
     turn_elapsed_s: ($e | tonumber)} + $s' >>"$log"
}
export marker

# stop_hook_active is true when this stop follows an earlier block from
# this hook. Allow it, or the loop never ends. The model wrote the summary
# between the block and this stop, so finalize it here.
active=$(jq -r '.stop_hook_active // false' <<<"$input")
if [ "$active" = "true" ]; then
  [ "$fresh" = true ] && finalize
  exit 0
fi

[ "$fresh" = true ] && finalize
[ "$fresh" = true ] && [ -z "$note" ] && [ "$dirty" = false ] && exit 0
[ "$elapsed" -le "$THRESHOLD" ] && exit 0

mkdir -p "${cfg}/handoffs"

# The ~ spelling matches the Bash allow rule for notes.py in settings.json.
case "$vault" in "$HOME"/*) vshow="~${vault#"$HOME"}" ;; *) vshow="$vault" ;; esac

reason="This turn ran ${elapsed}s, above the ${THRESHOLD}s handoff limit. Before you stop:"
if [ "$fresh" != true ]; then
  reason+=" Write a handoff summary to ${handoff}. Use a Bash heredoc (cat > \"${handoff}\" <<'EOF' ... EOF), not the Write or Edit tool, so the update does not render as a visible diff. Write it for a session with zero context: the task in one line, what is done, what is not, the key file paths, the decisions this turn made, and the exact next step. Overwrite the old file. Do not repeat your final message to the user."
fi
if [ -n "$note" ]; then
  reason+=" Update the vault note ${note}, whose paths cover this directory. When several are named, update the one this turn worked on. Rewrite State, set status, next_action, and last_worked_on, and add a Log line only when something shipped, broke, or was decided. Then run: python3 ${vshow}/tools/notes.py tokens <note>. If this turn did not change the project, leave the note alone."
fi
if [ -n "$note" ] || [ "$dirty" = true ]; then
  reason+=" Once the vault changes are done, commit them with the git-commit skill and git -C ${vshow}. Skip the commit when git -C ${vshow} status shows nothing."
fi
jq -n --arg reason "$reason" '{decision: "block", reason: $reason, suppressOutput: true}'
exit 0
