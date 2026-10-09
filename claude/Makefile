# Merges the settings templates into Claude Code's settings.json. Run once per
# machine after `stow claude`, and again after a template changes:
#
#   make -C ~/dotfiles/claude         personal machine
#   make -C ~/dotfiles/claude work    work machine, adds the Linear hook
#
# A template wins on every key it names, and a key no template names keeps the
# value Claude Code wrote. An array is replaced, except permissions.allow,
# which is unioned so a permission granted in a session survives. Two
# templates must not name the same hook event, or the later one replaces it.
#
# jq edits the JSON instead of sed or awk: it is portable across BSD and
# GNU, keeps the file valid JSON, and statusline.sh already requires it.
CLAUDE_CONFIG_DIR ?= $(HOME)/.claude
SETTINGS := $(CLAUDE_CONFIG_DIR)/settings.json
MERGE := (map(.permissions.allow // []) | add | unique) as $$allow \
  | reduce .[] as $$t ({}; . * $$t) \
  | if $$allow == [] then . else .permissions.allow = $$allow end

.PHONY: settings work
settings: TEMPLATES := settings.base.json
work: TEMPLATES := settings.base.json settings.work.json
settings work:
	@command -v jq >/dev/null 2>&1 || { echo 'jq is required, please install it' >&2; exit 1; }
	@[ -f '$(SETTINGS)' ] || printf '{}\n' > '$(SETTINGS)'
	@jq -s '$(MERGE)' '$(SETTINGS)' $(TEMPLATES) > '$(SETTINGS).tmp'
	@cp -p '$(SETTINGS)' '$(SETTINGS).bak'
	@mv '$(SETTINGS).tmp' '$(SETTINGS)'
	@echo 'merged $(TEMPLATES) into $(SETTINGS)'
