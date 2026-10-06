#!/usr/bin/env bash
# PreToolUse hook on Edit|Write. The first time a file is modified on a branch
# with no Linear issue in its name, inject an instruction to ASK before
# creating one. Fires once per repo+branch: the ledger entry written here is
# the "already handled" marker as well as the branch -> issue record.
#
# Opt out for a repo with a .no-linear file at its root.
set -u

# Linear team keys, used to tell a linked branch from an unlinked one. A bare
# [a-z]+-[0-9]+ would match ordinary names like fix-123, so the keys are listed.
KEYS="${CLAUDE_LINEAR_TEAM_KEYS:-ENG|SEC|CUS|VEL|VIS|DES|CX|P0}"

input=$(cat)
file=$(jq -r '.tool_input.file_path // empty' <<<"$input")
cwd=$(jq -r '.cwd // empty' <<<"$input")

dir=$([ -n "$file" ] && dirname "$file" || printf '%s' "$cwd")
[ -d "$dir" ] || dir="$cwd"
[ -n "$dir" ] || exit 0

root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -f "${root}/.no-linear" ] && exit 0

branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
[ "$branch" = "HEAD" ] && exit 0
grep -qiE "(^|/)(${KEYS})-[0-9]+" <<<"$branch" && exit 0

# A worktree's toplevel is the worktree, so the repo identity comes from the
# common git dir. Without this, each worktree of one repo looks like a new one.
common=$(git -C "$dir" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
repo=$(basename "$(dirname "${common:-$root}")")

cfg="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
ledger="${cfg}/linear-links"
slug=$(printf '%s__%s' "$repo" "$branch" | tr '/ ' '--')
entry="${ledger}/${slug}.json"
[ -f "$entry" ] && exit 0

mkdir -p "$ledger"
jq -n --arg repo "$repo" --arg path "$root" --arg branch "$branch" \
      --arg asked "$(date '+%Y-%m-%dT%H:%M:%S%z')" \
  '{repo: $repo, path: $path, branch: $branch, status: "asked", issue: null, asked_at: $asked}' \
  > "$entry"

ctx="Work is starting in ${repo} (${root}) on branch ${branch}, which has no Linear issue in its name and no entry in the Linear ledger.

ASK the user before creating anything. Propose a concrete issue title drawn from what this session is actually doing, and the team you would file it under, then wait for a yes. Do not create a Linear issue without their go-ahead, and do not ask again for this branch.

If they say yes: create the issue in Linear assigned to seth.moore@p0.dev, then record it by setting \"status\" to \"created\" and \"issue\" to the identifier in ${entry}.
If they say no: set \"status\" to \"declined\" in that same file.

Ask once, as a single short question, and carry on with the work either way."

jq -n --arg ctx "$ctx" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", additionalContext: $ctx}}'
exit 0
