# STE reference files

The `ste` skill reads three files from this directory. None of them is in the
repository. Build them from the source PDF.

## Why they are absent

ASD-STE100 Issue 9 is copyrighted by ASD, Brussels. ASD gives a free copy to
anyone who asks, but it does not permit redistribution. The full text and the
word index both contain the text of the standard, so `.gitignore` excludes all
three files.

## How to build them

1. Download Issue 9 from ASD:

   ```
   curl -sSL -o references/ASD-STE100_ISSUE9.pdf \
     https://www.asd-ste100.org/assets/files/ASD-STE100_ISSUE9.pdf
   ```

   If that address stops working, request a free copy at
   <https://www.asd-ste100.org/STE_downloads.html> and save it to the same path.
2. Check the file against the `.pdf` line of `MANIFEST.sha256`.
3. Install poppler. On Arch Linux, run `sudo pacman -S poppler`.
4. Run the build:

```
python3 ste/scripts/build-references.py
```

The script writes `ASD-STE100_ISSUE9.txt` and `word-index.tsv`, then compares
every hash against `MANIFEST.sha256`.

## What you get

| File | Content |
|---|---|
| `ASD-STE100_ISSUE9.pdf` | The source. 434 pages. You supply this |
| `ASD-STE100_ISSUE9.txt` | Full text, with the layout preserved |
| `word-index.tsv` | 2196 rows. 879 approved. Columns: word, pos, approved, meaning or alternatives, STE example, non-STE example |
| `rules.md` | The 53 rule statements and the 39 recurring errors |

The build also renders `../templates/CLAUDE.md.in` to `~/.claude/CLAUDE.md`. That
file carries the wording of the rules, so exclude it from your dotfiles
repository. Add this line to the `.gitignore` at the root of that repository:

```
CLAUDE.md
```

To change the always-on instructions, edit the template and run the build again.
Do not edit `~/.claude/CLAUDE.md`, because the next build overwrites it.

## Determinism

The build is deterministic for one source PDF and one poppler version.
`MANIFEST.sha256` records the hash of the input and of each output, and the
poppler version that made them.

A different poppler version can change the text layout, and thus the hashes of
the two output files. The script reports this and tells you which file differs.
A hash mismatch on the two outputs, with a correct PDF hash, is not an error in
the data. It shows only that your poppler differs from the one in the manifest.

A mismatch on the PDF hash means that you have a different document. Check the
issue and the date.

## If the build fails

The script stops when it cannot find the marker `Page 2-1-A1`, which starts the
alphabetical word list. That marker is specific to Issue 9. A later issue needs
a change to `scripts/build-references.py`.

## A known inconsistency in the source

Each section of part 1 states every rule two times: once in the summary box on
the first page of the section, and again above the explanation of that rule. The
two do not always agree. Rule 4.3 is "Use a vertical list for complex texts" in
the summary and "Use a vertical list for complex text" in the body.

`build-references.py` takes the wording from the body, because the body does not
wrap a rule in the middle of a word. Expect small differences from the summary
pages.

## Accuracy

The word index is derived. The parser joins each cell from a fixed-width
layout, so a rare column mistake is possible. The text file is authoritative.
When the two disagree, use the text file.
