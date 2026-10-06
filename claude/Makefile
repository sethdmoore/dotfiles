# Points Claude Code at the stowed status line. Run once per machine after
# `stow claude`:  make -C ~/dotfiles/claude
#
# jq edits the JSON instead of sed or awk: it is portable across BSD and
# GNU, keeps the file valid JSON, and statusline.sh already requires it.
CLAUDE_CONFIG_DIR ?= $(HOME)/.claude
SETTINGS := $(CLAUDE_CONFIG_DIR)/settings.json
COMMAND  := "$${CLAUDE_CONFIG_DIR:-$$HOME/.claude}/statusline.sh"

.PHONY: statusline
statusline:
	@command -v jq >/dev/null 2>&1 || { echo 'jq is required, please install it' >&2; exit 1; }
	@[ -f '$(SETTINGS)' ] || printf '{}\n' > '$(SETTINGS)'
	@grep -q '"statusLine"' '$(SETTINGS)' || { \
	  jq --arg cmd '$(COMMAND)' '.statusLine = {type: "command", command: $$cmd, padding: 0}' '$(SETTINGS)' > '$(SETTINGS).tmp' \
	  && mv '$(SETTINGS).tmp' '$(SETTINGS)' && echo 'statusLine added to $(SETTINGS)'; }
