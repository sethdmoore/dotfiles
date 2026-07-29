---
name: ste
description: ASD-STE100 Issue 9 Simplified Technical English. The 53 writing rules, the dictionary, and a word index. Load this to check whether a word or a construction is approved, to rewrite a text into STE, or to answer a question about Simplified Technical English.
---

# ASD-STE100 Issue 9

Issue 9 is dated 2025-01-15. Part 1 has 9 sections and 53 rules. Part 2 is a
dictionary of about 900 approved words.

This file holds no text of the standard. The wording is copyrighted, so the
build generates it into `references/`, which git ignores.

## The reference files

| File | Content | In git |
|---|---|---|
| `references/rules.md` | The 53 rule statements and the recurring errors | no |
| `references/word-index.tsv` | 1889 words. 582 approved | no |
| `references/ASD-STE100_ISSUE9.txt` | Full text. Authoritative | no |
| `references/ASD-STE100_ISSUE9.pdf` | The original, 434 pages | no |

Read `references/rules.md` first. It answers most questions.

If the directory holds only `README.md` and `MANIFEST.sha256`, the build has not
run. Tell the user to do these steps. Do not state a rule or a word from memory.

1. Request a free copy of Issue 9 at <https://www.asd-ste100.org/STE_downloads.html>.
2. Save the PDF as `references/ASD-STE100_ISSUE9.pdf`.
3. Run `python3 scripts/build-references.py`.

## How to look up a word

Column 3 of the index is `Y` for an approved word:

```
grep -iP '^<word>\t' references/word-index.tsv
```

The four columns are the word, the part of speech, `Y` or `N` for approved, and
the approved meaning or the approved alternatives.

For the full entry with its examples, grep the text:

```
grep -n -A12 '^<word> (v)' references/ASD-STE100_ISSUE9.txt
```

The index is derived and its meaning column truncates. If the two files
disagree, the text file is correct. Do not guess an alternative for a word that
the index does not list.

## Where each subject is

Use this to find the rule, then read its wording in `references/rules.md`.

| Subject | Rule |
|---|---|
| Approved words, technical nouns, technical verbs | 1.1, 1.5, 1.6, 1.12 |
| Part of speech, approved meaning | 1.2, 1.3, 9.2 |
| Forms of verbs and adjectives | 1.4, 3.1, 3.2 |
| A technical noun as a verb, a technical verb as a noun | 1.7, 1.13 |
| Company or subject field terminology | 1.8, 1.9, 1.11 |
| Regional words, slang, jargon | 1.10 |
| American English spelling | 1.14 |
| Multi-word nouns, hyphens | 2.1, 2.2, 8.2, 8.7 |
| The past participle as an adjective | 3.3 |
| Auxiliary verbs, complex constructions | 3.4 |
| The `-ing` form | 3.5 |
| Active voice and passive voice | 3.6 |
| A verb for an action | 3.7 |
| Short sentences | 4.1, 5.1, 6.3 |
| Omitted words and contractions | 4.2 |
| Vertical lists | 4.3, 8.4 |
| Connecting words | 4.4, 6.2 |
| Articles and demonstrative adjectives | 4.5 |
| One instruction in each sentence | 5.2 |
| The imperative form | 5.3 |
| A condition before a command | 5.4 |
| Notes | 5.5 |
| Paragraphs and topics | 6.1, 6.4, 6.5, 6.6 |
| Warnings and cautions | 7.1, 7.2, 7.3 |
| Punctuation, the semicolon, parentheses | 8.1, 8.3 |
| Word count | 8.5, 8.6, 8.7 |
| A different sentence construction | 9.1 |
| Phrasal verbs | 9.3 |
| Consistent style | 9.4 |

Section titles: 1 Words. 2 Multi-word nouns. 3 Verbs. 4 Sentences.
5 Procedural writing. 6 Descriptive writing. 7 Safety instructions.
8 Punctuation and word count. 9 Writing practices.

General recommendations: GR-1 `that`. GR-2 `with`. GR-3 pronouns. GR-4 `this`.
GR-5 false friends. GR-6 Latin abbreviations. GR-7 inclusive language. GR-8 the
possessive form. GR-7 and GR-8 are new in Issue 9. Read them in the PDF,
section 9.

## Application to code

This section applies the standard to software text. It is not a rule of the
standard.

Rules 1.1, 1.6, and 1.12 let you use a word that the dictionary does not
approve, when the word is a technical noun or a technical verb of a subject
field. Rule 1.12 includes computer processes and applications. Therefore write
these unchanged:

- An identifier, a function name, a class name, and a variable name.
- A file path, a command, a flag, and an environment variable.
- An error string, a log line, and quoted output.
- A standard term of the language, the library, or the protocol.

Rules 8.5, 8.6, and 8.7 count each of these as one word. The sentence limits
stay practical for code.

## The build

`scripts/build-references.py` makes every generated file, and renders
`templates/CLAUDE.md.in` to `~/.claude/CLAUDE.md`. It records each hash in
`references/MANIFEST.sha256` and checks them on the next run.

The build is deterministic for one source PDF and one poppler version.
