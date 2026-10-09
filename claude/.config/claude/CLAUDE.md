# Punctuation

Never write an em dash, in any output: a chat reply, a code comment, a commit
message, a README, or a string in code. Treat the en dash the same way. Write a
period, a comma, parentheses, or a vertical list.

Do not write a semicolon in prose. A semicolon joins two independent clauses,
which is to say two simple sentences. An em dash between two clauses does that
same job. The character differs. The function is the same, and the same ban
applies. A semicolon inside code is syntax, not prose, so it stays.

Two more reasons:

- A Latin ISO keyboard has no em dash key. Outside editorial and scientific text
  the mark is rare, so it reads as a signal of generated text.
- A pair of em dashes cuts a sentence in half and puts an aside in the gap, which
  muddles the point of the sentence. Keep sentences short and clear. Write the
  aside as its own sentence, or delete it.

# Comments and commit messages

Volume hides the signal, and a duplicated note drifts.

Write a comment only for one of these three:

- Behavior that surprises the reader.
- Syntax that looks wrong until something explains it.
- A caveat, or a manual step.

Follow these rules from Stack Overflow's guide to code comments
(https://stackoverflow.blog/2021/12/23/best-practices-for-writing-code-comments/):

- Comments should not duplicate the code.
- Good comments do not excuse unclear code.
- If you cannot write a clear comment, there may be a problem with the code.
- Comments should dispel confusion, not cause it.
- Explain unidiomatic code in comments.
- Provide links to the original source of copied code.
- Include links to external references where they will be most helpful.
- Add comments when you fix a bug.
- Use comments to mark incomplete implementations.

Keep the reason why you selected one combination of technology, but keep it
short. Delete every other comment. A comment that repeats what the next line
does is slop.

Keep a README minimal and high level. Give each fact one home. Do not put the
same caveat in a comment and in two READMEs. Do not write jargon. Write the
behavior instead, for example "the route serves traffic with no authentication".

Write bullets and sub-bullets, and not paragraphs, in a commit body and in a
README.

To write a commit message, invoke the `git-commit` skill with the Skill tool.
The skill runs in a forked agent on a cheap model. That agent reads the diff
itself and returns the finished message, so the full rule set is loaded on
every run. Pass it the repository path and a short note on the purpose of the
change, and the word `amend` or `squash` when that is the mode.

- Do not write the message yourself, and do not paraphrase the one returned.
- Append the attribution trailer when you commit. The skill leaves it out.
- The skill ends its reply with a note on which pull request template
  sections the change touches. Use that note for the template check below.

# Commit every change

Commit each completed and verified change. Do not wait to be asked, and do not
end a session with verified work uncommitted. Never push. Commit only if the
two conditions are true:

- Write the message with the `git-commit` skill, as the section above describes.
- Check each pull request template in the repository against the change.
  Confirm that you filled out every applicable section.

If a condition fails, tell the user which one, and do not commit.

When several commits on a branch are one change, or the history of a branch
reads as steps toward one result, squash them into one commit and write the
message for the whole. Keep two commits apart when each stands as a change a
reader would revert alone.

The user knows that your `gh` access is read-only. Do not say so before a
commit. Say it only when it blocks an action the user asked for, for example a
push or a PR comment.

# Where to put drafted GitHub content

Your `gh` access is read-only. When you draft a pull request body, a review
reply, or another piece of GitHub content that you cannot write through `gh`,
save it to a file. Do not leave it only in chat text, and do not put it only
under the session scratchpad below `/tmp`. That path is often not reachable
outside the container.

Put the file in one of these two places instead:

- Inside the repository, for example under a `resources/` directory.
- Under a path that Docker bind-mounts to the host, for example `~/.claude`.

Tell the user the file path once you save it.

Write only the content itself into the file: the exact pull request body,
the exact review reply, nothing else. Do not add a note inside the file
about how to use it, for example "paste this over the current description"
or "replace lines X to Y". The user pastes the whole file into GitHub, so a
note like that pastes too. Put any instructions for the user in chat, not
in the file.
