#!/usr/bin/env python3
"""Move files under the Claude config dir to ~/claude_migration/trash/<abs path>, one log line each.

  python3 -I trashpath.py check <list.tsv>
  python3 -I trashpath.py apply <list.tsv> --agent NAME

List rows, tab separated, '#' lines ignored:  <absolute path or ~/...>\t<reason>
"""
import os, re, shutil, sys, time

HOME = os.path.expanduser('~')
CFG = os.environ.get('CLAUDE_CONFIG_DIR') or os.path.join(HOME, '.claude')
TRASH = os.path.join(HOME, 'claude_migration/trash')
REFUSE = [os.path.join(CFG, p) for p in (
    'projects', 'settings.json', '.credentials.json', '.claude.json', 'hooks', 'skills', 'skills_disabled',
    'CLAUDE.md', 'statusline.sh', 'cc-notify', 'plugins', 'jobs', 'daemon', 'sessions', 'session-env',
    'file-history', 'history.jsonl', 'agents', 'keybindings.json', 'notes-to-linear-map.json', 'ENV',
    'policy-limits.json', 'remote-settings.json', 'tasks', 'cache', 'state', 'telemetry', 'backups')]


VAULT = os.environ.get('CLAUDE_VAULT') or os.path.join(HOME, 'Documents/obsidian/vaults/claude')


def cited(p):
    """First vault note that names this file's config-relative path, so a trash never breaks a citation."""
    rel = re.compile(re.escape(os.path.relpath(p, HOME)) + r'(?![A-Za-z0-9._+-])')
    for root, dirs, files in os.walk(VAULT):
        dirs[:] = [d for d in dirs if d not in ('.git', '.obsidian')]
        for f in files:
            if f.endswith('.md'):
                fp = os.path.join(root, f)
                try:
                    if rel.search(open(fp, errors='replace').read()):
                        return os.path.relpath(fp, VAULT)
                except OSError:
                    pass
    return ''


def rows(path):
    out = []
    for n, line in enumerate(open(path), 1):
        line = line.rstrip('\n')
        if not line.strip() or line.startswith('#'):
            continue
        p, reason = line.split('\t', 1)
        out.append((n, os.path.abspath(os.path.expanduser(p)), reason))
    return out


def run(path, agent=None):
    bad = 0
    for n, p, reason in rows(path):
        err = None
        if not p.startswith(CFG + '/'):
            err = f'not under {CFG}'
        elif any(p == r or p.startswith(r + '/') for r in REFUSE) or os.path.basename(p) == '.credentials.json':
            err = 'protected path'
        elif not os.path.lexists(p):
            err = 'missing'
        elif time.time() - os.path.getmtime(p) < 2 * 3600:
            err = 'changed under 2 hours ago'
        elif cited(p):
            err = 'still cited in the vault: ' + cited(p)
        if err:
            bad += 1
            print(f'SKIP row {n}: {p}: {err}')
            continue
        if agent is None:
            print(f'ok   row {n}: {p}')
            continue
        t = TRASH + p
        os.makedirs(os.path.dirname(t), exist_ok=True)
        shutil.move(p, t)
        with open(os.path.join(HOME, 'claude_migration/agents', agent, 'log.md'), 'a') as f:
            f.write(f'trash {p}: {reason}\n')
        print(f'done row {n}: {p}')
    print(f'{bad} skipped')
    return bad


if __name__ == '__main__':
    if len(sys.argv) < 3 or sys.argv[1] not in ('check', 'apply'):
        sys.exit(__doc__)
    if sys.argv[1] == 'apply':
        if '--agent' not in sys.argv:
            sys.exit('apply needs --agent NAME')
        agent = sys.argv[sys.argv.index('--agent') + 1]
        os.makedirs(os.path.join(HOME, 'claude_migration/agents', agent), exist_ok=True)
        sys.exit(1 if run(sys.argv[2], agent) else 0)
    sys.exit(1 if run(sys.argv[2]) else 0)
