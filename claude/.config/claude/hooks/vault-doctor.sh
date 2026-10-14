#!/usr/bin/env bash
# Checks every link between a Claude Code session and the Obsidian vault
# brief, and prints the first one that is broken. Run it on a machine where a
# session starts without the vault brief:
#   ~/.config/claude/hooks/vault-doctor.sh [dir]
# dir is the directory a session would start in. Default: the current one.
set -u

dir="${1:-$PWD}"
config="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
hooks="$config/hooks"
vault="${CLAUDE_VAULT:-$HOME/Documents/obsidian/vaults/claude}"
fail=0

ok()   { printf 'ok    %s\n' "$1"; }
bad()  { printf 'FAIL  %s\n      fix: %s\n' "$1" "$2"; fail=1; }

[ -n "${CLAUDE_CONFIG_DIR:-}" ] && ok "CLAUDE_CONFIG_DIR=$CLAUDE_CONFIG_DIR" \
  || bad "CLAUDE_CONFIG_DIR is unset, Claude Code reads ~/.claude" "stow the zsh package (zsh/.zshenv exports it) and open a new shell"

for f in vault-session-start.sh vault-stop.sh notes.py; do
  [ -f "$hooks/$f" ] && ok "$hooks/$f" \
    || bad "$hooks/$f is missing" "cd ~/dotfiles && git pull && stow claude"
done

for tool in python3 jq; do
  command -v "$tool" >/dev/null && ok "$tool on PATH" || bad "$tool is not on PATH" "install $tool, the hooks need it"
done

settings="$config/settings.json"
if [ -f "$settings" ] && jq -e '[.hooks.SessionStart[]?.hooks[]?.command // empty] | any(test("vault-session-start"))' "$settings" >/dev/null 2>&1; then
  ok "$settings runs vault-session-start.sh on SessionStart"
else
  bad "$settings does not run vault-session-start.sh" "make -C ~/dotfiles/claude (add 'work' on the work Mac)"
fi
if [ -f "$settings" ] && jq -e '.autoMemoryDirectory // empty | test("vaults/claude/memory")' "$settings" >/dev/null 2>&1; then
  ok "autoMemoryDirectory points into the vault"
else
  bad "autoMemoryDirectory is not the vault memory folder" "make -C ~/dotfiles/claude"
fi

[ -d "$vault" ] && ok "vault at $vault" || bad "no vault at $vault" "copy the seed to ~/vault-seed/claude-vault-seed.tar.gz and run make -C ~/dotfiles/claude, or set CLAUDE_VAULT"
[ -f "$vault/CLAUDE.md" ] && ok "$vault/CLAUDE.md exists, so the hooks are live" \
  || bad "$vault/CLAUDE.md is missing, so both hooks exit silently" "make -C ~/dotfiles/claude installs the seed vault, which carries CLAUDE.md"

if [ "$fail" = 0 ]; then
  echo
  echo "The brief a session in $dir would get:"
  echo "-----"
  printf '{"cwd":"%s","source":"startup"}' "$dir" | CLAUDE_VAULT="$vault" bash "$hooks/vault-session-start.sh"
  echo "-----"
  n=$(CLAUDE_VAULT="$vault" python3 "$hooks/notes.py" match "$dir" | wc -l | tr -d ' ')
  [ "$n" -gt 0 ] && ok "$n note(s) claim $dir, the brief carries a Summary" \
    || echo "note  no note claims $dir. The brief lists active notes instead. Add the directory to a note's paths for a Summary."
fi
exit $fail
