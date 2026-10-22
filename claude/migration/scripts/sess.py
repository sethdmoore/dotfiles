#!/usr/bin/env python3
"""Session moves for the migration. Run with python3 -I.

  sess.py check  <manifest.tsv>                 dry run: every row valid, nothing changed
  sess.py apply  <manifest.tsv> --agent NAME    run every row, log each change
  sess.py verify <manifest.tsv>                 after apply: every row landed

Manifest rows, tab separated, '#' lines ignored:
  mv     <src-folder> <session-id> <dst-folder>
  title  <folder>     <session-id> <title text>
  trash  <folder>     <session-id> <reason>
  trashmem <folder>   memory       <reason>     move <folder>/memory/ to trash
  trashfolder <folder> -           <reason>     move <folder> to trash, only when it holds no .jsonl and no session dir

A row names the folder the session is in when the row runs, so a title row
that follows an mv row names the dst folder.
"""
import json, os, sys, time, shutil

HOME = os.path.expanduser('~')
CFG = os.environ.get('CLAUDE_CONFIG_DIR') or os.path.join(HOME, '.claude')
P = os.environ.get('SESS_PROJECTS') or os.path.join(CFG, 'projects')
SESS = os.path.join(CFG, 'sessions')
MIG = os.environ.get('SESS_MIG') or os.path.join(HOME, 'claude_migration')
# The metawork session runs in the config dir. Claude Code names a session folder after its start dir, every non-alphanumeric character as '-'.
LIVE_FOLDER = ''.join(c if c.isalnum() else '-' for c in os.path.realpath(CFG))
MIN_AGE_H = 2.0


def live_ids():
    ids = set()
    for f in os.listdir(SESS):
        if f.endswith('.json'):
            try:
                ids.add(json.load(open(os.path.join(SESS, f))).get('sessionId'))
            except Exception:
                pass
    return ids


def where(sid):
    return [d for d in os.listdir(P) if os.path.exists(os.path.join(P, d, sid + '.jsonl'))]


def rows(path):
    out = []
    for n, line in enumerate(open(path), 1):
        line = line.rstrip('\n')
        if not line.strip() or line.startswith('#'):
            continue
        f = line.split('\t')
        if len(f) != 4 or f[0] not in ('mv', 'title', 'trash', 'trashmem', 'trashfolder'):
            sys.exit(f'{path}:{n}: bad row: {line!r}')
        out.append((n, *f))
    return out


def guard(folder, sid, live):
    fp = os.path.join(P, folder, sid + '.jsonl')
    if folder == LIVE_FOLDER:
        return f'{folder} is the live metawork folder'
    if sid in live:
        return f'{sid} is a running session'
    if not os.path.exists(fp):
        return f'{fp} missing'
    age = (time.time() - os.path.getmtime(fp)) / 3600
    if age < MIN_AGE_H:
        return f'{fp} changed {age:.1f}h ago'
    return None


def log(agent, text):
    d = os.path.join(MIG, 'agents', agent)
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, 'log.md'), 'a') as f:
        f.write(text + '\n')


def check(path, agent=None, apply=False):
    live = live_ids()
    bad = 0
    for n, op, folder, sid, arg in rows(path):
        if op in ('trashmem', 'trashfolder'):
            src = os.path.join(P, folder, 'memory') if op == 'trashmem' else os.path.join(P, folder)
            err = None
            if folder == LIVE_FOLDER:
                err = 'live folder'
            elif not os.path.isdir(src):
                err = f'{src} missing'
            elif op == 'trashfolder' and [e for e in os.listdir(src) if e not in ('memory', '.DS_Store')]:
                err = f'{src} not empty: {sorted(os.listdir(src))[:5]}'
            elif op == 'trashfolder' and os.path.isdir(os.path.join(src, 'memory')) and os.listdir(os.path.join(src, 'memory')):
                err = f'{src}/memory not empty'
            if err:
                bad += 1
                print(f'SKIP row {n}: {op} {folder}: {err}')
                continue
            if apply:
                t = os.path.join(MIG, 'trash') + src
                os.makedirs(os.path.dirname(t), exist_ok=True)
                shutil.move(src, t)
                log(agent, f'trash {src}: {arg}')
                print(f'done row {n}: {op} {folder}')
            else:
                print(f'ok   row {n}: {op} {folder}')
            continue
        err = guard(folder, sid, live)
        if op == 'mv' and not err:
            if arg == LIVE_FOLDER:
                err = 'dst is the live folder'
            elif os.path.exists(os.path.join(P, arg, sid + '.jsonl')):
                err = f'{sid} already in {arg}'
            elif not arg.startswith('-') or any(not (c.isalnum() or c == '-') for c in arg):
                err = f'bad dst folder name {arg}'
        if err:
            bad += 1
            print(f'SKIP row {n}: {op} {sid}: {err}')
            continue
        if not apply:
            print(f'ok   row {n}: {op} {folder}/{sid} {arg}')
            continue
        src = os.path.join(P, folder, sid)
        if op == 'mv':
            dst = os.path.join(P, arg, sid)
            os.makedirs(os.path.join(P, arg), exist_ok=True)
            shutil.move(src + '.jsonl', dst + '.jsonl')
            log(agent, f'mv {src}.jsonl {dst}.jsonl')
            if os.path.isdir(src):
                shutil.move(src, dst)
                log(agent, f'mv {src} {dst}')
        elif op == 'title':
            fp = src + '.jsonl'
            st = os.stat(fp)
            with open(fp, 'rb') as f:
                f.seek(-1, 2)
                ends_nl = f.read(1) == b'\n'
            with open(fp, 'a') as f:
                if not ends_nl:
                    f.write('\n')
                f.write(json.dumps({'type': 'custom-title', 'customTitle': arg, 'sessionId': sid},
                                   separators=(',', ':'), ensure_ascii=False) + '\n')
            os.makedirs(src, exist_ok=True)
            with open(os.path.join(src, 'custom-title.json'), 'w') as f:
                json.dump({'customTitle': arg}, f, separators=(',', ':'), ensure_ascii=False)
            os.utime(fp, (st.st_atime, st.st_mtime))
            log(agent, f'edit {fp}: append custom-title "{arg}", mtime kept')
        elif op == 'trash':
            for s in (src + '.jsonl', src):
                if os.path.exists(s):
                    t = os.path.join(MIG, 'trash') + s
                    os.makedirs(os.path.dirname(t), exist_ok=True)
                    shutil.move(s, t)
                    log(agent, f'trash {s}: {arg}')
        print(f'done row {n}: {op} {sid}')
    print(f'{bad} skipped')
    return bad


def verify(path):
    bad = 0
    state = {}
    for n, op, folder, sid, arg in rows(path):
        if op in ('trashmem', 'trashfolder'):
            src = os.path.join(P, folder, 'memory') if op == 'trashmem' else os.path.join(P, folder)
            ok = not os.path.exists(src) and os.path.exists(os.path.join(MIG, 'trash') + src)
            bad += not ok
            print(('PASS ' if ok else 'FAIL ') + f'{op} {folder}')
            continue
        state.setdefault(sid, {'folder': folder})
        if op == 'mv':
            state[sid]['folder'] = arg
        elif op == 'title':
            state[sid]['title'] = arg
        elif op == 'trash':
            state[sid]['trash'] = os.path.join(MIG, 'trash') + os.path.join(P, folder, sid + '.jsonl')
    for sid, s in state.items():
        found = where(sid)
        if 'trash' in s:
            ok = not found and os.path.exists(s['trash'])
            msg = f'in trash' if ok else f'expected in trash, found in {found}'
        else:
            ok = found == [s['folder']]
            msg = f'in {found}'
            if ok:
                fp = os.path.join(P, s['folder'], sid + '.jsonl')
                for i, line in enumerate(open(fp, errors='replace'), 1):
                    try:
                        json.loads(line)
                    except Exception:
                        ok, msg = False, f'line {i} is not JSON'
                        break
                if ok and 'title' in s:
                    last = [l for l in open(fp, errors='replace') if '"type":"custom-title"' in l]
                    ok = bool(last) and json.loads(last[-1]).get('customTitle') == s['title']
                    msg += ' title ok' if ok else ' title missing'
        bad += not ok
        print(('PASS ' if ok else 'FAIL ') + sid + ' ' + msg)
    print(f'{bad} failed')
    return bad


if __name__ == '__main__':
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    cmd, man = sys.argv[1], sys.argv[2]
    if cmd == 'check':
        sys.exit(1 if check(man) else 0)
    if cmd == 'apply':
        if '--agent' not in sys.argv:
            sys.exit('apply needs --agent NAME')
        sys.exit(1 if check(man, sys.argv[sys.argv.index('--agent') + 1], True) else 0)
    if cmd == 'verify':
        sys.exit(1 if verify(man) else 0)
    sys.exit(__doc__)
