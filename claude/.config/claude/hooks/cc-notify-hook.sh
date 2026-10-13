#!/bin/sh
# Notification hook. The banner body says what Claude wants: "Approve: " and
# the pending tool call's description, or the last line of Claude's reply.
# Without a usable transcript it falls back to Claude Code's generic message.
payload=$(cat)
field() { printf %s "$payload" | jq -r "$1 // empty" 2>/dev/null; }
cwd=$(field .cwd)
message=$(field .message)
transcript=$(field .transcript_path)
case $(field .notification_type) in
  permission_prompt) want=tool_use ;;
  idle_prompt) want=text ;;
  '') want= ;;
  *) transcript= ;;
esac

# Transcripts reach several MB, and the last line can be half written.
blurb=$(tail -n 300 "$transcript" 2>/dev/null | jq -nrR --arg want "$want" '
  [inputs | fromjson? | select(.type == "assistant") | .message.content[]?
    | select(.type == $want or ($want == "" and (.type == "text" or .type == "tool_use")))] | last
  | if .type == "tool_use" then
      "Approve: " + ([.input.description, .input.file_path,
        (.input.command // "" | split("\n")[0]),
        (.input.prompt // "" | split("\n")[0]), .name]
        | map(select(type == "string" and . != "")) | first)
    elif .type == "text" then
      .text | split("\n") | map(select(test("\\S"))) | last // ""
        | gsub("`|\\*\\*"; "") | sub("^\\s*([#>-]+\\s*)?"; "")
    else empty end
  | gsub("\\s+"; " ") | if length > 140 then .[:137] + "..." else . end
' 2>/dev/null)

exec "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/cc-notify" "${cwd##*/}" "${blurb:-$message}"
