# Sets up Claude Code on a machine after `stow claude`. Run it again after a
# template changes:
#
#   make -C ~/dotfiles/claude         personal machine
#   make -C ~/dotfiles/claude work    work machine, adds the Linear hook
#
# Both stow this package into $(HOME) (the `stow` target), so the hooks and
# statusline.sh exist before settings.json points at them, merge the settings
# templates into settings.json, then link the vault rules into the vault and
# make its folders (the `vault` target).
#
# A template wins on every key it names, and a key no template names keeps the
# value Claude Code wrote. An array is replaced, except permissions.allow,
# which is unioned so a permission granted in a session survives. Two
# templates must not name the same hook event, or the later one replaces it.
#
# jq edits the JSON instead of sed or awk: it is portable across BSD and
# GNU, keeps the file valid JSON, and statusline.sh already requires it.
CLAUDE_CONFIG_DIR ?= $(HOME)/.claude
PACKAGE := $(notdir $(CURDIR))
SETTINGS := $(CLAUDE_CONFIG_DIR)/settings.json
MERGE := (map(.permissions.allow // []) | add | unique) as $$allow \
  | reduce .[] as $$t ({}; . * $$t) \
  | if $$allow == [] then . else .permissions.allow = $$allow end

.PHONY: stow settings work
settings: TEMPLATES := settings.base.json
work: TEMPLATES := settings.base.json settings.work.json
settings work: stow
	@command -v jq >/dev/null 2>&1 || { echo 'jq is required, please install it' >&2; exit 1; }
	@[ -f '$(SETTINGS)' ] || printf '{}\n' > '$(SETTINGS)'
	@jq -s '$(MERGE)' '$(SETTINGS)' $(TEMPLATES) > '$(SETTINGS).tmp'
	@cp -p '$(SETTINGS)' '$(SETTINGS).bak'
	@mv '$(SETTINGS).tmp' '$(SETTINGS)'
	@echo 'merged $(TEMPLATES) into $(SETTINGS)'
	@$(MAKE) --no-print-directory vault

stow:
	@command -v stow >/dev/null 2>&1 || { echo 'stow is required, please install it' >&2; exit 1; }
	@stow -d '$(abspath $(CURDIR)/..)' -t '$(HOME)' '$(PACKAGE)'

# The vault rules and templates live in vault/ here, beside notes.py, which
# enforces them. Every run links them into the vault, so a vault made before a
# rule changed gets the rule its checker enforces. A different file or folder
# in their place moves to $(BEFORE) first.
#
# The seed tarball holds notes and memories only, and installs only where the
# vault has no git repository, so it never overwrites a vault's history. A
# vault without CLAUDE.md is not new: on 2026-10-16 that test let the seed
# overwrite the work Mac's vault. Memories Claude Code saved before the vault
# existed, in the vault's own memory/ or at the path the vault had before
# 2026-10-12, are moved aside first: tar would keep their MEMORY.md and leave
# the seeded memories unindexed. notes.py then folds them in, and leaves only
# a file whose name the seed also has, for a session to merge by hand.
VAULT ?= $(or $(CLAUDE_VAULT),$(HOME)/Documents/obsidian/vaults/claude)
SEED ?= $(HOME)/vault-seed/claude-vault-seed.tar.gz
OLD_MEMORY ?= $(HOME)/Documents/vaults/obsidian/claude/memory
STAGED := $(HOME)/claude-memory-before-seed
BEFORE := $(HOME)/claude-vault-rules-before-dotfiles
RULES := $(CURDIR)/vault

.PHONY: vault
vault:
	@if [ ! -d '$(VAULT)/.git' ] && [ -f '$(SEED)' ]; then \
	  i=0; for d in '$(VAULT)/memory' '$(OLD_MEMORY)'; do \
	    [ -d "$$d" ] || continue; i=$$((i+1)); mkdir -p '$(STAGED)'; mv "$$d" "$(STAGED)/$$i"; \
	  done; \
	  mkdir -p '$(dir $(VAULT))' && tar -xzf '$(SEED)' -C '$(dir $(VAULT))' && echo 'installed the seed at $(VAULT)'; \
	  [ ! -d '$(STAGED)' ] || CLAUDE_VAULT='$(VAULT)' python3 .config/claude/hooks/notes.py fold-memory '$(STAGED)'/*; \
	fi
	@mkdir -p '$(VAULT)/1-projects' '$(VAULT)/2-areas' '$(VAULT)/3-resources' '$(VAULT)/4-archive' '$(VAULT)/memory'
	@[ -d '$(VAULT)/.git' ] || { git -C '$(VAULT)' init -q && echo 'made $(VAULT) a git repository'; }
	@for f in CLAUDE.md templates; do \
	  t='$(VAULT)'/$$f; \
	  [ "$$(readlink "$$t")" != '$(RULES)'/$$f ] || continue; \
	  if [ -L "$$t" ]; then rm "$$t"; \
	  elif [ -e "$$t" ] && diff -rq "$$t" '$(RULES)'/$$f >/dev/null 2>&1; then rm -r "$$t"; \
	  elif [ -e "$$t" ]; then mkdir -p '$(BEFORE)' && mv "$$t" '$(BEFORE)'/ && echo "moved the old $$f to $(BEFORE)"; fi; \
	  ln -s '$(RULES)'/$$f "$$t" && echo "linked $$t to the rules in dotfiles"; \
	done

# The migration board and its guarded session helpers (migration/README.md).
# Links each into ~/claude_migration. A file already there that matches is
# replaced by the link, and a different one is kept and reported.
MIGRATION ?= $(HOME)/claude_migration
MIGRATION_FILES := bin/say bin/hear scripts/sess.py scripts/trashpath.py README.md PROMPT.md

.PHONY: migration
migration:
	@mkdir -p '$(MIGRATION)/bin' '$(MIGRATION)/scripts' '$(MIGRATION)/chat' '$(MIGRATION)/agents' '$(MIGRATION)/trash'
	@for f in $(MIGRATION_FILES); do \
	  s='$(CURDIR)/migration'/$$f; t='$(MIGRATION)'/$$f; \
	  [ "$$(readlink "$$t")" != "$$s" ] || continue; \
	  if [ -e "$$t" ] && ! cmp -s "$$t" "$$s"; then echo "kept $$t, it differs from dotfiles"; continue; fi; \
	  rm -f "$$t" && ln -s "$$s" "$$t" && echo "linked $$t"; \
	done
