## Re-organize Claude's memory on this machine

You, this session, are #validator (Opus). This is a metawork session. Its work directory is ~/.config/claude (or ~/.claude if CLAUDE_CONFIG_DIR is unset).

Your job:
1. Take local backups first.
2. Kick off the project below.
3. Validate the work when everything else is done.
4. Find out whether we lost key knowledge in the move, and talk to me about it (ask questions).

### Before anything else
- Confirm `cleanupPeriodDays` is set in settings.json (dotfiles `settings.base.json` sets 365). If it is unset, stop and ask me. The 30-day cleanup deletes transcripts while the migration runs.
- Back up into ~/backups/pre-migration-<timestamp>/ with a MANIFEST.tsv holding entry counts and sha256 sums: the Claude config dir, ~/Documents/obsidian/vaults, ~/dotfiles, ~/scratch, and loose files in ~/. Compare each archive's entry count to its source.

### Board
- Run `make -C ~/dotfiles/claude migration`. It links the board (`bin/say`, `bin/hear`), the guarded helpers (`scripts/sess.py`, `scripts/trashpath.py`) and README.md into ~/claude_migration/.
- Every agent reads ~/claude_migration/README.md first. It holds the board commands and the rules.
- Watch it with `tail -f ~/claude_migration/chat/*.log`.

### Agents, in order
1. **#research** (Opus). Writes ~/claude_migration/research/: PLAN.md, a set1 sessions plan, a set2 vault plan, knowledge-checklist.md, and questions-for-seth.md with a default per question. It writes manifests for the installed helpers (scripts/sess.py for title, move, trash and verify of transcripts, scripts/trashpath.py for config cleanup) and dry-runs every one with `check`. Its plan covers:
   - Distinct project slugs aligned with the vault. Sessions from old sandboxes (/home/claude paths) are mapped or trashed.
   - Per slug, keep the newest 1 or 2 sessions as resume points. Trash a session only if its outcome is in the vault and no note cites it.
   - Every kept session gets the title `<slug>: <topic>` and moves to its project's home folder.
   - Every project and area note gets a `sessions:` frontmatter list of `<project folder>/<session-id>` for its kept sessions.
   - Vault PARA cleanup: duplicates merged, stale projects archived, oversized overviews trimmed, facts that exist only in ~/.config/claude or old memory folders carried in.
   - Nothing for a project stays in ~/.config/claude.
2. **#overseer** (Opus). Runs 2 sets of 5 Haiku agents in parallel, names them in roster.md, and follows #research's plan closely.
   - set1: sessions. 5 disjoint slices, `check` only. The harness denies agents a transcript move, so #overseer writes one POSIX sh script (real names, `set -u`) that I run, and #validator reads it first.
   - set2: vault. 1 agent per PARA folder plus 1 for memory/, Home.md and Projects.base. 5 commits in that order, each with the git-commit skill, each touching only its owner's paths.
3. **#auditor** (Opus). Reviews 1 commit at a time against the checklist. The owner amends fixes into the same commit before the next one lands. Then it reviews the set1 logs and writes audit/FINAL.md.

### Known limits
- Subagents cannot write report files. They return text, and the lead agent writes the file.
- The live metawork session folder moves last, after this session exits, with a script I run.
- Cuts made on purpose go in the vault's claude-workflow/trashed.md, with the commit that added each one and the commit that removed it.

Ask me before any delete outside ~/claude_migration/trash/, any edit to dotfiles or settings, and any decision in questions-for-seth.md that changes the plan.
