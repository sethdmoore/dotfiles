# Claude migration board

A file-based chat for the agents of a Claude memory migration, and for Seth. Plain text, append-only, readable with `cat`. `make -C ~/dotfiles/claude migration` links these files into `~/claude_migration/`. `PROMPT.md` starts a migration.

## Watch it (Seth)

```sh
tail -f ~/claude_migration/chat/*.log
~/claude_migration/bin/say seth seth "@overseer keep the otf notes"   # post as yourself
```

## Talk (agents)

```sh
~/claude_migration/bin/say <channel> <your-name> "<one line>"
~/claude_migration/bin/hear <your-name> [group ...] [--wait 60]
```

- `say` writes one line. Mention who you address with `@name`. `@all` reaches everyone.
- `hear` prints new lines that mention you, `@all`, or a group you pass. Run it before each step and before you finish. `--all` replays everything.
- Keep a message to one line. Subagents cannot write report files, so return longer findings as text to the agent that spawned you.
- A question needs an answer before you act? Post it, then `hear <you> --wait 110`. If no answer comes, pick the safe option, and log the choice.
- A channel is any name of letters, digits and `-`. Questions for Seth go to `seth`.

## Folders

```
README.md, PROMPT.md   from dotfiles
bin/                   say, hear
scripts/               sess.py (session title, move, trash, verify), trashpath.py (config dir cleanup)
chat/<channel>.log
research/              the plan
agents/<name>/         each agent's log.md
trash/                 anything removed, at its original absolute path under trash/
audit/                 reviews
```

## Rules for every agent

1. Never `rm`. To remove a file, move it to `~/claude_migration/trash/<original absolute path>` and log it.
2. Log every change in `agents/<name>/log.md`, one line each: `mv <src> <dst>`, `edit <path>: <why>`, `trash <path>: <why>`.
3. Read only: Seth's own vaults, `~/dotfiles`, git repos, `settings.json`, hooks, and skills.
4. Do not touch the live metawork session folder or any session file changed in the last 2 hours. `sess.py` refuses both.
5. Files Seth made outside the config dir and the claude vault: propose moves, do not run them.
6. Never push. Never write to Linear, Slack, GitHub, or Logseq.
7. Vault commits use the `git-commit` skill and only your own paths (`git commit -- <paths>`), one at a time, when the lead agent gives you the turn.
8. The harness denies agents a transcript move. Write a script for Seth to run instead, and do not look for another route.
9. When unsure whether a note or session holds knowledge, keep it and ask.
