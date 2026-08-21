---
name: start-task
description: Start a new unit of work. Creates (or links) a Linear issue, cuts an isolated git worktree + branch using Linear's branch convention, and drops a plan stub. Use at the beginning of any task, before writing code. Invoke as /start-task <short description>.
---

# start-task

Front half of the plan → clear → implement loop. Goal: go from "I want to do X" to "isolated branch + tracked issue + empty plan file" with no manual GUI steps. Do NOT start implementing in this skill — it only sets up the workspace.

## Inputs
- The task description passed after the command (e.g. `/start-task fix token refresh race`). If none was given, ask for a one-line description before doing anything else.

## Steps

1. **Linear issue.** Ask whether this maps to an existing Linear issue or a new one.
   - Existing: ask for the identifier (e.g. `ENG-123`) or search Linear by keyword and confirm the match with me.
   - New: create a Linear issue via the Linear MCP tools. Title = the task description, cleaned up. Assign to me (seth.moore@p0.dev). Leave priority/project unset unless I specify. Report the new identifier back.
   - Capture the issue **identifier** (e.g. `ENG-123`) and Linear's suggested **git branch name** (Linear exposes one per issue, typically like `seth/eng-123-<slug>`). If the branch name isn't available from the API, construct `seth/<identifier-lowercased>-<kebab-slug-of-title>`.

2. **Worktree + branch.** Never `git checkout` in place — use a worktree so parallel tasks don't collide.
   - From the repo root, run: `git worktree add ../<repo>-<identifier> -b <branch-name> origin/HEAD` (base off the default branch's remote head; adjust `origin/HEAD` to the repo's actual default if that fails).
   - Confirm the worktree path and branch to me. Subsequent work happens in that worktree.

3. **Plan stub.** In the new worktree, create `plans/<identifier>.md` containing:
   - a `# <identifier>: <title>` heading,
   - a `## Context` section with the Linear issue URL and any links I gave,
   - an empty `## Plan` section and `## Notes` section.
   - This is the file the implement step will read after `/clear`, so the plan handoff is lossless.

4. **Report.** Print a compact summary: Linear identifier + URL, branch name, worktree path, plan file path. Then tell me: *"Ready. Enter plan mode (Shift+Tab), and when the plan is final I'll write it into `plans/<identifier>.md`. Then `/clear` and say: implement plans/<identifier>.md."*

## Guardrails
- Do not push, open a PR, or write any implementation code here.
- If `gh`/`git` auth fails, stop and report — do not attempt workarounds.
- If Linear isn't authenticated, say so (`/mcp` to auth) and offer to proceed branch-only, creating the issue later.
