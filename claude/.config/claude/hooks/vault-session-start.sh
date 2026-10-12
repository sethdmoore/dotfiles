#!/usr/bin/env bash
# SessionStart hook. Injects a brief of Claude's Obsidian vault: where it is,
# which note lists this directory in `paths` with its Summary, and the active
# notes.
# Exits quietly where the vault is absent, for example inside a container.
set -u

vault="${CLAUDE_VAULT:-$HOME/Documents/obsidian/vaults/claude}"
[ -f "$vault/CLAUDE.md" ] || exit 0

cwd=$(jq -r '.cwd // empty')
[ -n "$cwd" ] || exit 0

ctx=$(CLAUDE_VAULT="$vault" python3 "$(dirname "${BASH_SOURCE[0]}")/notes.py" context "$cwd") || exit 0
jq -n --arg ctx "$ctx" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $ctx}}'
exit 0
