---
name: git-commit
description: Write or revise a git commit message. Load this before you compose a message, amend one, squash a branch into one commit, or review a message that a person wrote. It gives the seven rules from Chris Beams' "How to Write a Git Commit Message", the imperative test, and the 50-character and 72-character limits.
---

# Git commit messages

Source: Chris Beams, "How to Write a Git Commit Message",
<https://cbea.ms/git-commit/>. The rule statements below are his words.

## The seven rules

Use this as the checklist. Read each line against your message.

| # | Rule | How to obey it |
|---|---|---|
| 1 | Separate subject from body with a blank line | Exactly one blank line. The body is optional |
| 2 | Limit the subject line to 50 characters | Keep to 50. Count 72 as the hard limit |
| 3 | Capitalize the subject line | Start with a capital letter |
| 4 | Do not end the subject line with a period | Remove the period. It gives no information |
| 5 | Use the imperative mood in the subject line | Do the test below |
| 6 | Wrap the body at 72 characters | Git does not wrap the text. Break the lines yourself |
| 7 | Use the body to explain what and why vs. how | Read the caution below |

## Why the blank line is necessary

Git reads the text before the first blank line as the commit title.
`git log --oneline`, `git shortlog`, and most other tools show only that title.
If the message has no blank line, those tools show the full text as one title.

A single line is sufficient when the change is simple and no context is
necessary. For example, `Fix typo in introduction to user guide` is complete
without a body. The reader can read the diff.

## The imperative test

Put the subject into this sentence:

> If applied, this commit will _<subject line>_

If the result is not correct English, write the subject again. Git itself uses
the imperative form for the messages that it makes, such as
`Merge branch 'myfeature'` and `Revert 'Add the thing with the stuff'`. Your
messages must match.

| Good | Bad |
|---|---|
| `Refactor subsystem X for readability` | `Fixed bug with Y` |
| `Update getting started documentation` | `Changing behavior of X` |
| `Remove deprecated methods` | `More fixes for broken stuff` |
| `Release version 1.0.0` | `Sweet new API methods` |

The bad subjects fail for two different causes. The first two use the wrong
verb form. The last two name no action.

## A good body

```
Redirect stale sessions to the login page

An expired token made the API return a 500, and the browser then showed
an empty page. Users read the empty page as an outage and opened support
tickets for it.

The auth middleware now finds the expiry and answers with a 302. The API
still returns a 401 to clients that are not browsers, because the CLI
depends on that code.
```

The body tells the previous behavior, the current behavior, and the cause of
the change. Each paragraph has one topic. A blank line divides them.

For a list in the body, use a hyphen or an asterisk, and put a blank line
between the items.

## Caution

The body must tell why the change is necessary. It must not tell how the code
works. The diff shows how, and the code is clear about how. A body that
repeats the diff gives the reader nothing.

## House structure

Prefer bullets and sub-bullets to paragraphs, in a commit body and in a README.
Use this layout:

```
Short subject, 72 characters or less

Feature one

- A detail of feature one
- Another detail
  - A caveat that refines the detail above

Feature two, and the reason for it

- A detail of feature two
```

- Give each feature its own line. A reason on that line is **optional**. Add one
  when the feature needs it. Leave the line bare when it does not. The example
  above shows both.
- Indent a sub-bullet two spaces.
- Wrap at 72 columns, which rule 6 asks for.
- Omit the blank line between items. The article says that "typically a hyphen
  or asterisk is used for the bullet, preceded by a single space, with blank
  lines in between, but conventions vary here", so a tight list is permitted.

**On the subject limit.** Rule 2 asks for 50 characters, and the article calls 50
"not a hard limit, just a rule of thumb". The article also says that GitHub
truncates a subject longer than 72 characters with an ellipsis. Use 72, the width
at which the text stays whole.
