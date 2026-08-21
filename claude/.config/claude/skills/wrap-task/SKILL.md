---
name: wrap-task
description: Finish a unit of work. Opens (or updates) a PR from the current branch, moves the linked Linear issue forward, and drafts a Slack status update for me to send. Use when implementation is done and reviewed. Invoke as /wrap-task.
---

# wrap-task

Back half of the loop. Turns a finished branch into a PR + updated tracker + drafted comms, with no manual GUI clicks. Never sends the Slack message itself — it drafts and waits for my go-ahead.

## Preconditions
- Assume the current directory is the task worktree. Determine the branch with `git branch --show-current` and the Linear identifier from the branch name / `plans/<identifier>.md` if present.
- If the working tree has uncommitted changes, list them and ask whether to commit (proposing a message) before proceeding. Do not auto-commit silently.

## Steps

1. **Push + PR.**
   - Push the branch (`git push -u origin <branch>`). Remember pushes go over SSH; `gh` API calls use the read-only token — this is expected.
   - Open a PR with `gh pr create`. Title from the Linear issue title. Body: a short summary of the change, a "Testing" line describing what was verified, and a `Closes <LINEAR-URL>` / issue-magic-word line so Linear auto-links. If a PR already exists for this branch, update its body instead of creating a duplicate.
   - Report the PR URL.

2. **Linear.** Move the linked issue to the appropriate status via Linear MCP:
   - default to **In Review** once the PR is open.
   - add a comment on the issue linking the PR.
   - Do NOT mark the issue Done/closed here — that happens on merge. If I ask to close it, confirm first.

3. **Slack draft.** Draft (do not send) a concise status update suitable for my team channel or a DM:
   - one line on what shipped, the PR link, and the Linear link.
   - Show me the draft and ask which channel/DM to post to. Only send after I confirm the target and the text.

4. **Report.** Summarize: PR URL, new Linear status, and the pending Slack draft awaiting my confirmation.

## Guardrails
- Never merge the PR.
- Never send Slack messages or close Linear issues without explicit confirmation.
- If any integration is unauthenticated, complete the parts you can and clearly list what I need to do manually.
