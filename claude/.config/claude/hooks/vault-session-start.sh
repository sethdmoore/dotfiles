#!/usr/bin/env bash
# SessionStart hook. Injects a brief of Claude's Obsidian vault: where it is,
# and the note that lists this directory in `paths` with its Summary, or every
# active note when none does.
# Exits quietly where the vault is absent, for example inside a container.
#
# Skips a resume. The transcript already holds the brief, and the i-have-adhd
# plugin does not repeat its rules on resume, so a second brief lands below them.
# Prints plain text, not additionalContext. Claude Code appends
# additionalContext after all plain text, and plain text lands in the order the
# hooks finish. This hook usually beats the plugin's Node hook, so the ADHD
# rules usually land last. Claude Code guarantees no order.
set -u

vault="${CLAUDE_VAULT:-$HOME/Documents/obsidian/vaults/claude}"
[ -f "$vault/CLAUDE.md" ] || exit 0

input=$(cat)
[ "$(jq -r '.source // empty' <<<"$input")" = resume ] && exit 0
cwd=$(jq -r '.cwd // empty' <<<"$input")
[ -n "$cwd" ] || exit 0

CLAUDE_VAULT="$vault" python3 "$(dirname "${BASH_SOURCE[0]}")/notes.py" context "$cwd" || true
exit 0
