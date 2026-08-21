#!/usr/bin/env python3
"""Build the STE reference files from the ASD-STE100 Issue 9 PDF.

The PDF is copyrighted and is not in this repository. Request a free copy at
https://www.asd-ste100.org/STE_downloads.html and put it here:

    references/ASD-STE100_ISSUE9.pdf

Then run:

    python3 scripts/build-references.py

The script writes two files that the `ste` skill reads:

    references/ASD-STE100_ISSUE9.txt   full text
    references/word-index.tsv          word, pos, approved,
                                       meaning_or_alternatives,
                                       ste_example, non_ste_example

It then compares every hash against references/MANIFEST.sha256 and reports the
result. Use --write-manifest to create or update that file.

The output is deterministic for one input PDF and one poppler version. A
different poppler version can change the text layout, and thus the hashes.
"""

import argparse
import hashlib
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REF = HERE.parent / 'references'
PDF = REF / 'ASD-STE100_ISSUE9.pdf'
TXT = REF / 'ASD-STE100_ISSUE9.txt'
TSV = REF / 'word-index.tsv'
RULES = REF / 'rules.md'
MANIFEST = REF / 'MANIFEST.sha256'
TEMPLATES = HERE.parent / 'templates'
CLAUDE_MD = Path.home() / '.claude' / 'CLAUDE.md'

POS = r'n|v|adj|adv|prep|conj|pron|art|prefix|TN|TV'
NOISE = re.compile(
    r'ASD.?STE100|Part 2 - Dictionary|^\s*Issue 9|^\s*Page 2-1-|2025-01-15|'
    r'^Word\b|^\(part of speech\)|Blank Page')
HDR = re.compile(
    r'^\(part of speech\)\s+ALTERNATIVES\s+STE EXAMPLE\s+Non-STE example\s*$')
POSRX = re.compile(r'\((%s)\)' % POS)
NOTE = re.compile(r'\s*\bFor\b[^.|]*\buse:$')
LOWER = re.compile(r'[a-z]')
CAPTOK = re.compile(r'[A-Z]{2}')
SENT = re.compile(r'^[“"(]?[A-Z][a-z]')
ABBR = re.compile(r'^(No|Fig|Nr)[.\d]')


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def poppler_version():
    try:
        out = subprocess.run(['pdftotext', '-v'],
                             capture_output=True, text=True)
    except OSError:
        return 'unknown'
    text = (out.stderr or '') + (out.stdout or '')
    m = re.search(r'pdftotext version (\S+)', text)
    return m.group(1) if m else 'unknown'


def manifest_version():
    """Return the poppler version that the manifest records, or None."""
    if not MANIFEST.exists():
        return None
    m = re.search(r'# poppler (\S+)',
                  MANIFEST.read_text(encoding='utf-8'))
    return m.group(1) if m else None


def extract_text():
    """Run pdftotext when the txt file is absent. Normalize the line endings.

    An existing txt file is reused, so that its recorded hash stays valid.
    Return True when the text was extracted again.
    """
    if TXT.exists():
        return False
    subprocess.run(
        ['pdftotext', '-layout', '-enc', 'UTF-8', str(PDF), str(TXT)],
        check=True)
    raw = TXT.read_bytes().decode('utf-8', 'replace')
    TXT.write_text(raw.replace('\r\n', '\n').replace('\r', '\n'),
                   encoding='utf-8')
    return True


# The dictionary of part 2 is a table with four columns: word with part of
# speech, approved meaning or alternatives, STE example, and non-STE example.
# Cells wrap across lines, and the column x-offsets differ from page to page.
# The parser reads the offsets from the column header of each page, groups
# the lines into entries and sub-rows, and finds the cell boundaries from the
# vertical gaps of each sub-row.

def letters(t):
    return re.sub(r'[^A-Za-z]', '', t)


def col0_split(line):
    """Take the word-column fragment from the start of the line.

    Stop at the first gap of two or more spaces, at a change of letter case,
    or after a parenthesized group. Return the fragment and its end offset.
    """
    frag_end = 0
    cls = None
    depth = 0
    for m in re.finditer(r'\S+', line):
        if m.start() >= 2 and line[m.start() - 2:m.start()] == '  ':
            break
        t = m.group()
        if depth == 0 and not t.startswith('('):
            lt = letters(t)
            if lt:
                tc = 'u' if lt.isupper() else ('l' if lt.islower() else 'm')
                if cls is None:
                    if tc == 'm':
                        break
                    cls = tc
                elif tc != cls:
                    break
        depth += t.count('(') - t.count(')')
        frag_end = m.end()
    return line[:frag_end].strip(), frag_end


def white_intervals(lines, lo, hi):
    """Return the maximal x-ranges in [lo, hi) that are blank in every line."""
    blank = [x for x in range(lo, hi)
             if all(x >= len(l) or l[x] == ' ' for l in lines)]
    out = []
    for x in blank:
        if out and out[-1][1] == x - 1:
            out[-1][1] = x
        else:
            out.append([x, x])
    return out


def right_is_caps(lines, cut):
    """True when the first text after the cut looks like an STE example."""
    for l in lines:
        seg = l[cut:cut + 14].strip()
        if not seg:
            continue
        lead = next((t for t in seg.split() if letters(t)), '')
        if lead:
            return not LOWER.search(lead)
    return True


def pick_cut(lines, o, lo, hi, caps_right=False):
    """Select a cut column near offset o from the vertical gaps of a block."""
    iv = white_intervals(lines, max(lo, 1), hi)
    if caps_right:
        iv = [i for i in iv if right_is_caps(lines, i[1] + 1)]
    if not iv:
        return None

    def score(i):
        contains = i[0] - 1 <= o <= i[1] + 1
        dist = 0 if contains else min(abs(o - i[0]), abs(o - i[1]))
        return (not contains, i[1] - i[0] < 1, dist)
    best = min(iv, key=score)
    return best[1] + 1


def word_starts(line):
    return [m.start() for m in re.finditer(r'\S+', line)]


def line_cut2(line, anchor):
    """Per-line cut between the meaning column and the STE example."""
    if len(line) <= anchor - 2:
        return len(line)
    near = [x for x in word_starts(line) if anchor - 5 <= x <= anchor + 2]
    if near:
        cut = min(near, key=lambda x: abs(x - anchor))
    elif all(x >= len(line) or line[x] == ' ' for x in (anchor - 1, anchor)):
        m = re.compile(r'\S').search(line, anchor)
        cut = m.start() if m else len(line)
    else:
        cut = anchor
    first = len(line) - len(line.lstrip())
    if first < anchor - 2 and cut < len(line) and not CAPTOK.search(line[cut:]):
        # Guidance text in italics can go across the boundary. When no
        # uppercase text follows the cut, the full line is guidance.
        return len(line)
    return cut


def line_cut3(line, c2, o3, first=False):
    """Per-line cut between the STE example and the non-STE example.

    The STE example is in uppercase. On the first line of a sub-row, the
    non-STE example starts with a sentence-case word.
    """
    if first:
        toks = list(re.finditer(r'\S+', line[c2:]))
        for i, m in enumerate(toks):
            if SENT.match(m.group()) and not ABBR.match(m.group()):
                nxt = next((letters(t.group()) for t in toks[i + 1:]
                            if letters(t.group())), '')
                if not nxt or LOWER.search(nxt):
                    return c2 + m.start()
    if len(line) <= o3 - 2:
        return len(line)
    if all(x >= len(line) or line[x] == ' ' for x in (o3 - 1, o3)):
        m = re.compile(r'\S').search(line, o3)
        return m.start() if m else len(line)
    for m in re.finditer(r'\S+', line[c2:]):
        if LOWER.search(m.group()):
            return c2 + m.start()
    return len(line)


def join_word(frags):
    """Join the word-cell fragments. Remove a hyphen made by a line wrap."""
    out = ''
    for f in frags:
        if out.endswith('-') and f[:1].isalpha():
            out = out[:-1] + f
        else:
            out = (out + ' ' + f).strip()
    return re.sub(r'\s+', ' ', out)


def word_done(wjoin):
    """True when the word cell can end here."""
    if not wjoin or wjoin.endswith((',', '-')):
        return False
    return wjoin.count('(') == wjoin.count(')')


def is_inflection(frag, wjoin):
    """True when the fragment lists inflected forms of an approved verb."""
    if not frag or '(' in frag or frag.endswith('-'):
        return False
    if not re.search(r'\(v\)', wjoin):
        return False
    if not re.search(r'(?:S|ED|D)[,.]?$', frag.split()[0], re.I):
        return False
    head = letters(wjoin.split()[0]) if wjoin else ''
    tok = letters(frag.split()[0])
    if not head or not tok or head.isupper() != tok.isupper():
        return False
    n = 0
    for a, b in zip(head.upper(), tok.upper()):
        if a != b:
            break
        n += 1
    return n >= 3 and n >= min(len(head), len(tok)) - 3


def alpha_key(w):
    return re.sub(r'[^a-z0-9 ]', '', w.lower()).strip()


def entry_word(e):
    wcell = join_word([f for f, in e['w']])
    m = POSRX.search(wcell)
    return wcell[:m.start()].rstrip(' ,') if m else wcell


def merge_wrapped(entries):
    """Merge a false entry made from the tail of a wrapped headword.

    A headword can wrap with the part of speech on the second line, for
    example "DOWNSTREAM" then "OF (prep)". The tail then looks like an
    entry, but the entry that follows it breaks the alphabetical order.
    """
    out = []
    for i, e in enumerate(entries):
        if (out and i + 1 < len(entries)
                and not POSRX.search(join_word([f for f, in out[-1]['w']]))
                and POSRX.search(join_word([f for f, in e['w']]))
                and alpha_key(entry_word(entries[i + 1]))
                < alpha_key(entry_word(e))):
            prev = out[-1]
            prev['w'].extend(e['w'])
            prev['subs'][-1].extend(e['subs'][0])
            prev['subs'].extend(e['subs'][1:])
        else:
            out.append(e)
    return out


def parse_entries(pages):
    """Group the dictionary lines into entries and sub-rows.

    A sub-row is one meaning or one alternative together with its examples.
    A new sub-row starts where the meaning column gets text again after a
    vertical gap, or after a blank line.
    """
    entries = []
    cur = None
    prev_edge = False
    for page in pages:
        lines = page.split('\n')
        hi = next((i for i, l in enumerate(lines) if HDR.match(l)), None)
        if hi is None:
            continue
        h = lines[hi]
        off = (h.index('ALTERNATIVES'), h.index('STE EXAMPLE'),
               h.index('Non-STE example'))
        o1 = off[0]
        for raw in lines[hi + 1:]:
            line = raw.rstrip()
            if not line:
                prev_edge = False
                if cur is not None and cur['subs'][-1]:
                    cur['subs'].append([])
                continue
            if NOISE.search(line):
                continue
            indent = len(line) - len(line.lstrip())
            if 3 <= indent < o1 - 6:
                # A note below the word column, for example "No other verb
                # forms." Remove that first segment and keep the rest.
                m = re.search(r'  +', line[indent:])
                if not m:
                    continue
                line = ' ' * (indent + m.end()) + line[indent + m.end():]
                indent = len(line) - len(line.lstrip())
                if not line.strip():
                    continue
            frag, frag_end = ('', 0)
            if indent < 3:
                frag, frag_end = col0_split(line)
            if frag:
                wjoin = join_word([f for f, in cur['w']]) if cur else ''
                cont = cur is not None and (
                    not word_done(wjoin)
                    or frag.startswith('(')
                    or (not POSRX.search(frag) and is_inflection(frag, wjoin)))
                if not cont:
                    cur = {'w': [], 'subs': [[]], 'first': True}
                    entries.append(cur)
                elif cur['subs'][-1] == [] and len(cur['subs']) > 1:
                    cur['subs'].pop()
                cur['w'].append((frag,))
            if cur is None:
                continue
            body = ' ' * frag_end + line[frag_end:]
            m = re.compile(r'\S').search(body)
            bstart = m.start() if m else None
            edge = bstart is not None and bstart <= o1 + 4
            if edge and not prev_edge and not cur['first'] and not frag:
                cur['subs'].append([])
            cur['subs'][-1].append((body, off))
            cur['first'] = False
            prev_edge = edge
    return merge_wrapped(entries)


def entry_cells(e):
    """Split one entry into its four cells, sub-row by sub-row."""
    m1, m2, m3 = [], [], []
    for sub in e['subs']:
        if not sub or not any(b.strip() for b, _ in sub):
            continue
        block = [b for b, _ in sub]
        o1, o2, o3 = sub[0][1]
        c2x = []
        for b in block:
            if not b.strip():
                continue
            st = len(b) - len(b.lstrip())
            if not (o1 + 6 <= st < o3 - 6):
                continue
            lead = next((t for t in b.split() if letters(t)), '')
            if lead and not LOWER.search(lead):
                c2x.append(st)
        if c2x:
            # Continuation lines of the STE example give the most reliable
            # x-offset for the start of that column.
            counts = {}
            for x in c2x:
                counts[x] = counts.get(x, 0) + 1
            top = max(counts.values())
            anchor = min((x for x in counts if counts[x] == top),
                         key=lambda x: (abs(x - o2), x))
        else:
            anchor = pick_cut(block, o2, o2 - 9, o2 + 5, caps_right=True)
            if anchor is None:
                anchor = pick_cut(block, o2, o1 + 3, o3 - 4, caps_right=True)
        f1, f2, f3 = [], [], []
        first = True
        for body, off in sub:
            lc2 = line_cut2(body, anchor if anchor is not None else off[1])
            lc3 = line_cut3(body, lc2, off[2], first=first)
            first = False
            a, b, c = (body[:lc2].strip(), body[lc2:lc3].strip(),
                       body[lc3:].strip())
            if a:
                f1.append(a)
            if b:
                f2.append(b)
            if c:
                f3.append(c)
        t1 = NOTE.sub('', ' '.join(f1)).strip()
        t2, t3 = ' '.join(f2), ' '.join(f3)
        if t1 or t2 or t3:
            m1.append(t1)
            m2.append(t2)
            m3.append(t3)
    while m1 and not m1[-1] and not m2[-1] and not m3[-1]:
        m1.pop()
        m2.pop()
        m3.pop()
    return m1, m2, m3


def clean_cell(segments):
    v = list(segments)
    while v and not v[-1]:
        v.pop()
    text = ' | '.join(v)
    return re.sub(r'\s+', ' ', text.replace('\t', ' ')).strip()


def build_index():
    """Parse the dictionary of part 2 into a TSV index.

    One row for each word plus part of speech. Multiple meanings or
    alternatives, and their examples, are joined with " | ". Segment i of
    each example column belongs to segment i of the meaning column.
    """
    pages = TXT.read_text(encoding='utf-8').split('\f')
    entries = parse_entries(pages)
    if not entries:
        sys.exit('error: no dictionary entries were found. '
                 'Check that the PDF is ASD-STE100 Issue 9.')
    rows = []
    for e in entries:
        wcell = join_word([f for f, in e['w']])
        m = POSRX.search(wcell)
        if m:
            word = wcell[:m.start()].rstrip(' ,')
            pos = m.group(1)
        else:
            # A few headwords have no part of speech, for example
            # "FOR EXAMPLE" and "such as".
            word, pos = wcell, ''
        approved = letters(word.split()[0]).isupper()
        m1, m2, m3 = entry_cells(e)
        rows.append((word, pos, 'Y' if approved else 'N',
                     clean_cell(m1), clean_cell(m2), clean_cell(m3)))

    with open(TSV, 'w', encoding='utf-8', newline='\n') as f:
        f.write('word\tpos\tapproved\tmeaning_or_alternatives\t'
                'ste_example\tnon_ste_example\n')
        for r in rows:
            f.write('\t'.join(r) + '\n')
    return rows


P1NOISE = re.compile(r'ASD.?STE100|Part 1 - Writing|^\s*Issue 9|Page 1-|2025-01-15')
SECTIONS = ['Words', 'Multi-word nouns', 'Verbs', 'Sentences',
            'Procedural writing', 'Descriptive writing', 'Safety instructions',
            'Punctuation and word count', 'Writing practices']


def extract_rules(lines):
    """Return [(number, statement)] for the 53 rules, in document order.

    The 9 summary blocks enumerate every rule number. The body of each section
    repeats the rule in a box, without a line wrap in the middle of a word.
    Take the numbers from the summaries and the wording from the body.
    """
    anchors = [i for i, l in enumerate(lines) if 'Summary of the rules' in l]
    if len(anchors) != 9:
        sys.exit('error: found %d summary blocks, expected 9.' % len(anchors))

    order = []
    for a in anchors:
        for l in lines[a + 1:a + 60]:
            if P1NOISE.search(l):
                continue
            m = re.match(r'^\s*Rule (\d+\.\d+)\s{2,}', l)
            if m and m.group(1) not in order:
                order.append(m.group(1))

    body_start = anchors[0]
    out = []
    for num in order:
        hits = [i for i, l in enumerate(lines)
                if i >= body_start
                and re.match(r'^\s*Rule %s\s{2,}' % re.escape(num), l)]
        buf = []
        for offset, l in enumerate(lines[hits[-1]:hits[-1] + 14]):
            if P1NOISE.search(l):
                continue
            if not l.strip():
                if buf:
                    break
                continue
            # The rule sits in a box, and every line of it is indented. The
            # explanatory text that follows starts at column 0.
            if offset and not l[:1].isspace():
                break
            buf.append(l.strip())

        text = ''
        for frag in buf:
            if not text:
                text = frag
            elif text.endswith('-'):
                text += frag       # the PDF broke a hyphenated word at the margin
            else:
                text += ' ' + frag
        text = re.sub(r'^Rule\s+%s\s+' % re.escape(num), '', text)
        out.append((num, re.sub(r'\s+', ' ', text).strip()))
    return out


def extract_recurring_errors(lines):
    """Return [(non_ste, ste)] from the table in the dictionary introduction."""
    try:
        a = next(i for i, l in enumerate(lines)
                 if l.strip() == 'List of recurring errors')
        b = next(i for i, l in enumerate(lines)
                 if i > a and l.strip() == 'List of approved verbs')
    except StopIteration:
        sys.exit('error: the list of recurring errors was not found.')
    rows, seen = [], set()
    for l in lines[a:b]:
        if NOISE.search(l) or not l.strip():
            continue
        m = re.match(r'^\s+(\S.*?\(\w+\))\s{2,}(\S.*\S)\s*$', l)
        if m and m.group(1) != 'Non-STE' and m.group(1) not in seen:
            seen.add(m.group(1))
            rows.append((m.group(1), m.group(2)))
    return rows


def write_rules_md(rules, errors, version):
    """Write the generated file that holds the wording of the standard."""
    n = 0
    parts = [
        '# ASD-STE100 Issue 9 — rule statements',
        '',
        'Generated by `scripts/build-references.py` from the source PDF.',
        'Do not edit. Do not commit. The wording belongs to ASD, Brussels.',
        '',
        'poppler %s' % version,
        '',
    ]
    for i, title in enumerate(SECTIONS, start=1):
        rows = [(num, txt) for num, txt in rules if num.startswith('%d.' % i)]
        if not rows:
            continue
        parts += ['## Section %d — %s' % (i, title), '',
                  '| Rule | Statement |', '|---|---|']
        for num, txt in rows:
            parts.append('| %s | %s |' % (num, txt.replace('|', r'\|')))
            n += 1
        parts.append('')
    parts += ['## List of recurring errors', '',
              'If a word is not approved in the dictionary, do not use it.', '',
              '| Non-STE | STE |', '|---|---|']
    for a, b in errors:
        parts.append('| %s | %s |' % (a, b.replace('|', r'\|')))
    parts.append('')
    RULES.write_text('\n'.join(parts), encoding='utf-8')
    return n


def render_templates(rules, errors):
    """Fill each template in templates/ and write it to its target."""
    written = []
    rule_lines = '\n'.join('- %s (%s)' % (t, n) for n, t in rules)
    err_lines = ' · '.join('%s → %s' % (a, b) for a, b in errors)
    src = TEMPLATES / 'CLAUDE.md.in'
    if src.exists():
        body = src.read_text(encoding='utf-8')
        body = body.replace('{{RULES}}', rule_lines)
        body = body.replace('{{RECURRING_ERRORS}}', err_lines)
        CLAUDE_MD.write_text(body, encoding='utf-8')
        written.append(CLAUDE_MD)
    return written


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--write-manifest', action='store_true',
                    help='write the hashes to MANIFEST.sha256')
    args = ap.parse_args()

    if not PDF.exists():
        sys.exit('error: %s is missing.\nRequest a free copy at '
                 'https://www.asd-ste100.org/STE_downloads.html' % PDF)

    extracted = extract_text()
    if extracted:
        version = poppler_version()
    else:
        # The txt file was reused, so record the version that made it.
        version = manifest_version() or poppler_version()
    print('poppler        %s' % version)
    print('source PDF     %s' % sha256(PDF))

    rows = build_index()
    approved = sum(1 for r in rows if r[2] == 'Y')

    all_lines = TXT.read_text(encoding='utf-8').split('\n')
    rules = extract_rules(all_lines)
    errors = extract_recurring_errors(all_lines)
    n = write_rules_md(rules, errors, version)
    if n != 53:
        sys.exit('error: wrote %d rules, expected 53.' % n)

    print('text           %s' % sha256(TXT))
    print('word index     %s  (%d words, %d approved)'
          % (sha256(TSV), len(rows), approved))
    print('rules          %s  (%d rules, %d recurring errors)'
          % (sha256(RULES), n, len(errors)))

    for target in render_templates(rules, errors):
        print('rendered       %s' % target)

    lines = ['# ASD-STE100 Issue 9 reference build',
             '# poppler %s' % version,
             '%s  ASD-STE100_ISSUE9.pdf' % sha256(PDF),
             '%s  ASD-STE100_ISSUE9.txt' % sha256(TXT),
             '%s  word-index.tsv' % sha256(TSV),
             '%s  rules.md' % sha256(RULES)]
    body = '\n'.join(lines) + '\n'

    if args.write_manifest:
        MANIFEST.write_text(body, encoding='utf-8')
        print('\nwrote %s' % MANIFEST)
        return

    if not MANIFEST.exists():
        sys.exit('\nerror: %s is missing. Run with --write-manifest.' % MANIFEST)

    expected = MANIFEST.read_text(encoding='utf-8')
    if expected.strip() == body.strip():
        print('\nOK: every hash matches MANIFEST.sha256')
        return
    print('\nMISMATCH against MANIFEST.sha256')
    exp = {l.split('  ')[1]: l.split('  ')[0]
           for l in expected.splitlines() if '  ' in l and not l.startswith('#')}
    got = {l.split('  ')[1]: l.split('  ')[0]
           for l in lines if '  ' in l and not l.startswith('#')}
    for name in ('ASD-STE100_ISSUE9.pdf', 'ASD-STE100_ISSUE9.txt',
                 'word-index.tsv', 'rules.md'):
        if exp.get(name) != got.get(name):
            print('  %-24s expected %s' % (name, exp.get(name, '(none)')))
            print('  %-24s got      %s' % ('', got.get(name, '(none)')))
    if exp.get('ASD-STE100_ISSUE9.pdf') != got.get('ASD-STE100_ISSUE9.pdf'):
        print('\nThe source PDF differs. You may have a different issue.')
    else:
        print('\nThe PDF matches, so the difference comes from poppler.')
        print('The manifest was built with poppler %s.'
              % re.search(r'# poppler (\S+)', expected).group(1)
              if '# poppler' in expected else '')
    sys.exit(1)


if __name__ == '__main__':
    main()
