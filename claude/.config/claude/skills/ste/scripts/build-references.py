#!/usr/bin/env python3
"""Build the STE reference files from the ASD-STE100 Issue 9 PDF.

The PDF is copyrighted and is not in this repository. Request a free copy at
https://www.asd-ste100.org/STE_downloads.html and put it here:

    references/ASD-STE100_ISSUE9.pdf

Then run:

    python3 scripts/build-references.py

The script writes two files that the `ste` skill reads:

    references/ASD-STE100_ISSUE9.txt   full text
    references/word-index.tsv          word, part of speech, approved, meaning

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

POS = r'n|v|adj|adv|prep|conj|pron|art|TN'
NOISE = re.compile(
    r'ASD.?STE100|Part 2 - Dictionary|^\s*Issue 9|^\s*Page 2-1-|2025-01-15|'
    r'^Word\b|^\(part of speech\)|Blank Page')
HEAD = re.compile(r'^(\S.*?)\s*\((%s)\)\s*(?:\s{2,}(.*))?$' % POS)
ALT = re.compile(r'\b([A-Z][A-Z\-]*(?: [A-Z][A-Z\-]*){0,2})\s+\((%s)\)' % POS)


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(1 << 20), b''):
            h.update(block)
    return h.hexdigest()


def poppler_version():
    out = subprocess.run(['pdftotext', '-v'], capture_output=True, text=True)
    text = (out.stderr or '') + (out.stdout or '')
    m = re.search(r'pdftotext version (\S+)', text)
    return m.group(1) if m else 'unknown'


def extract_text():
    """Run pdftotext with the layout preserved. Normalize the line endings."""
    subprocess.run(
        ['pdftotext', '-layout', '-enc', 'UTF-8', str(PDF), str(TXT)],
        check=True)
    raw = TXT.read_bytes().decode('utf-8', 'replace')
    TXT.write_text(raw.replace('\r\n', '\n').replace('\r', '\n'),
                   encoding='utf-8')


def build_index():
    """Parse the alphabetical word list of part 2 into a TSV index."""
    lines = TXT.read_text(encoding='utf-8').split('\n')
    try:
        start = next(i for i, l in enumerate(lines) if 'Page 2-1-A1' in l)
    except StopIteration:
        sys.exit('error: the word list marker "Page 2-1-A1" was not found. '
                 'Check that the PDF is ASD-STE100 Issue 9.')

    entries, cur = [], None
    for raw in lines[start:]:
        if NOISE.search(raw) or not raw.strip():
            continue
        if not raw[:1].isspace():
            m = HEAD.match(raw.rstrip())
            if m:
                cur = {'w': m.group(1).strip(), 'p': m.group(2), 'body': []}
                entries.append(cur)
                if m.group(3):
                    cur['body'].append(m.group(3))
                continue
        if cur is not None:
            cur['body'].append(raw.strip())

    rows = []
    for e in entries:
        block = ' '.join(e['body'])
        approved = e['w'].isupper()
        if approved:
            head = re.split(r'\s{2,}', block.strip())[0]
            detail = head[:70] if head and not head.isupper() else ''
        else:
            alts, seen = [], set()
            for m in ALT.finditer(block):
                term = m.group(1).strip()
                if term == e['w'] or term in seen or len(term) < 2:
                    continue
                seen.add(term)
                alts.append('%s (%s)' % (term, m.group(2)))
            detail = ', '.join(alts[:6])
        rows.append((e['w'], e['p'], 'Y' if approved else 'N', detail))

    with open(TSV, 'w', encoding='utf-8', newline='\n') as f:
        f.write('word\tpos\tapproved\tmeaning_or_alternatives\n')
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

    version = poppler_version()
    print('poppler        %s' % version)
    print('source PDF     %s' % sha256(PDF))

    extract_text()
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
