#!/usr/bin/env bash
# Stop hook. After a turn longer than THRESHOLD seconds, asks the model to
# update the vault notes for the work the turn changed, and to commit the
# vault when the turn left vault files uncommitted.
#
# A note counts as changed work when its `paths` cover a file the turn
# edited with Edit, Write, MultiEdit or NotebookEdit, or cover the working
# directory and its repository gained a commit or a modified file during the
# turn. A turn that only read, or worked somewhere no note tracks, asks for
# nothing, because every ask costs a model call over the whole context.
#
# Several sessions share the vault, so a note counts as updated, and a vault
# file as this session's to commit, only when this turn edited it with one of
# those tools. A file's mtime would also count another session's edits.
#
# Two Stop hooks that both block may not both reach the model, so both
# checks live in this one hook.
set -u

THRESHOLD="${CLAUDE_VAULT_STOP_SECONDS:-60}"

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
input=$(cat)

# stop_hook_active is true when this stop follows an earlier block from
# this hook. Allow it, or the loop never ends.
[ "$(jq -r '.stop_hook_active // false' <<<"$input")" = true ] && exit 0

transcript=$(jq -r '.transcript_path // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")
[ -f "$transcript" ] || exit 0
[ -n "$cwd" ] || exit 0

vault="${CLAUDE_VAULT:-$HOME/Documents/obsidian/vaults/claude}"
[ -f "$vault/CLAUDE.md" ] || exit 0
vault=$(cd "$vault" && pwd)

# The turn starts at the last typed user prompt. A typed prompt carries a
# string content, and a tool result carries an array, so the filter below
# skips tool results. jq parses the timestamp because macOS date has no -d.
# fromdateiso8601 rejects fractional seconds, so sub() strips them.
start_s=$(jq -r 'select(.type == "user" and (.message.content | type) == "string") | .timestamp // empty | sub("\\.[0-9]+"; "") | fromdateiso8601' "$transcript" 2>/dev/null | tail -n 1)
[ -n "$start_s" ] || exit 0
elapsed=$(($(date +%s) - start_s))
[ "$elapsed" -le "$THRESHOLD" ] && exit 0

newer() { [ "$(date -r "$1" +%s)" -ge "$start_s" ]; }

# repo_changed: the repository holding $1 gained a commit, or a modified or
# untracked file, since the turn started. A path that is gone counts.
repo_changed() {
  local top f
  top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null) || return 1
  [ "$(git -C "$top" log -1 --format=%ct 2>/dev/null || echo 0)" -ge "$start_s" ] && return 0
  while IFS= read -r f; do
    { [ ! -e "$top/$f" ] || newer "$top/$f"; } && return 0
  done < <(git -C "$top" status --porcelain 2>/dev/null | cut -c4-)
  return 1
}

edited=$(jq -r --argjson start "$start_s" '
  select(.type == "assistant")
  | select((.timestamp // "" | sub("\\.[0-9]+"; "") | try fromdateiso8601 catch 0) >= $start)
  | .message.content[]? | select(.type == "tool_use" and (.name | test("^(Edit|Write|MultiEdit|NotebookEdit)$")))
  | .input.file_path // .input.notebook_path // empty' "$transcript" 2>/dev/null | sort -u)
was_edited() { case $'\n'"$edited"$'\n' in *$'\n'"$1"$'\n'*) return 0 ;; esac; return 1; }

dirs=$(while IFS= read -r f; do [ -n "$f" ] && dirname "$f"; done <<<"$edited" | sort -u)
repo_changed "$cwd" && dirs=$(printf '%s\n%s\n' "$dirs" "$cwd" | sort -u)

# stale: the notes for each changed directory, left out when the turn
# already updated one of that directory's notes.
stale=""
while IFS= read -r d; do
  [ -n "$d" ] || continue
  matched=$(CLAUDE_VAULT="$vault" python3 "$here/notes.py" match "$d" 2>/dev/null)
  [ -n "$matched" ] || continue
  fresh=false
  while IFS= read -r n; do was_edited "$n" && fresh=true; done <<<"$matched"
  [ "$fresh" = true ] && continue
  while IFS= read -r n; do
    case ", $stale, " in *", $n, "*) ;; *) stale="${stale:+$stale, }$n" ;; esac
  done <<<"$matched"
done <<<"$dirs"

# dirty: a vault file this turn edited and nobody committed.
dirty=false
while IFS= read -r f; do
  case "$f" in "$vault"/*) ;; *) continue ;; esac
  [ -n "$(git -C "$vault" status --porcelain -- "$f" 2>/dev/null)" ] && { dirty=true; break; }
done <<<"$edited"

[ -z "$stale" ] && [ "$dirty" = false ] && exit 0

# The ~ spelling matches the Bash allow rules in settings.json.
case "$vault" in "$HOME"/*) vshow="~${vault#"$HOME"}" ;; *) vshow="$vault" ;; esac
case "$here" in "$HOME"/*) nshow="~${here#"$HOME"}/notes.py" ;; *) nshow="$here/notes.py" ;; esac

reason="Before you stop:"
if [ -n "$stale" ]; then
  reason+=" This turn changed files that the vault note ${stale} tracks. When several are named, update the ones this turn worked on. Rewrite State, and the Summary when State changed. Set status, next_action, and last_worked_on, add each new source to References, and add a Log line only when something shipped, broke, or was decided. Then run: python3 ${nshow} tokens <note>, and fix each problem it reports."
fi
reason+=" Commit the vault changes with the git-commit skill and git -C ${vshow}. Stage nothing while the skill runs, then run git add <files> && git commit as one command. Skip the commit when git -C ${vshow} status shows nothing."
jq -n --arg reason "$reason" '{decision: "block", reason: $reason, suppressOutput: true}'
exit 0
