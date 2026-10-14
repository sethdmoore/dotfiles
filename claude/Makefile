# Sets up Claude Code on a machine after `stow claude`. Run it again after a
# template changes:
#
#   make -C ~/dotfiles/claude         personal machine
#   make -C ~/dotfiles/claude work    work machine, adds the Linear hook
#
# Both merge the settings templates into settings.json, then install the
# vault from the seed tarball when no vault exists yet (the `vault` target).
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
	@$(MAKE) --no-print-directory vault

# The seed tarball holds the vault as a git repo under claude/. Memories Claude
# Code saved before the vault existed, in the vault's own memory/ or at the
# path the vault had before 2026-10-12, are moved aside first: tar -k would
# keep their MEMORY.md and leave the seeded memories unindexed. notes.py then
# folds them in, and leaves only a file whose name the seed also has, for a
# session to merge by hand.
VAULT ?= $(or $(CLAUDE_VAULT),$(HOME)/Documents/obsidian/vaults/claude)
SEED ?= $(HOME)/vault-seed/claude-vault-seed.tar.gz
OLD_MEMORY ?= $(HOME)/Documents/vaults/obsidian/claude/memory
STAGED := $(HOME)/claude-memory-before-seed

.PHONY: vault
vault:
	@[ ! -f '$(VAULT)/CLAUDE.md' ] || exit 0; \
	if [ ! -f '$(SEED)' ]; then echo 'no vault at $(VAULT). Copy the seed to $(SEED), or run make vault SEED=<path>'; exit 0; fi; \
	i=0; for d in '$(VAULT)/memory' '$(OLD_MEMORY)'; do \
	  [ -d "$$d" ] || continue; i=$$((i+1)); mkdir -p '$(STAGED)'; mv "$$d" "$(STAGED)/$$i"; \
	done; \
	mkdir -p '$(dir $(VAULT))' && tar -xzf '$(SEED)' -C '$(dir $(VAULT))' && echo 'installed the vault at $(VAULT)'; \
	[ -d '$(STAGED)' ] && CLAUDE_VAULT='$(VAULT)' python3 .config/claude/hooks/notes.py fold-memory '$(STAGED)'/*; \
	exit 0
