# Skill: Opus-subagent workspace flow — isolated workspace, plan, delegate, review, draft PR

This skill describes the workflow for implementing a ticket by:

1. Creating a **sibling jj workspace** isolated from the current workspace.
2. Branching a bookmark either on top of **`main`** (standalone) or on top of an **existing feature bookmark** (stacked PR).
3. Writing a **plan file** (`PLAN-<TICKET>.md`) inside the workspace.
4. Delegating implementation to an **Opus subagent** constrained to that workspace (no jj/git, no pushing).
5. Reviewing the subagent's edits.
6. Moving the plan file **out of the workspace** before describing, so it does not land in the commit.
7. Describing, setting the bookmark, pushing, and opening a **draft PR** (with `--base` for stacked PRs).
8. Ending on an empty `jj new @` on top of the bookmark.

This is the flow used for the realfi repo: jj, stacked-PR-aware, with multiple workspaces that each hold one ticket's work.

**Prerequisites:** **skill-jujutsu.md** (change/bookmark/push mechanics), **skill-jira-story-to-pr-workflow.md** (ticket reading, evaluation, transition, naming conventions), **skill-commits-and-pre-commit-checks.md** (conventional commits, running checks), **skill-subagent-review-main-agent-address.md** (review loop after the subagent finishes).

**When to use this flow vs. implement directly:**

- Use this flow when the user says things like *"start on TICKET like usual, separate workspace, write a plan, monitor opus subagent, review, open draft pr"* — or has established this pattern for a repo. The realfi repo uses this flow by default.
- Skip it for trivial edits (one-liner fixes) or when the user explicitly wants the main agent to implement directly.

---

## 1. Sibling jj workspaces, not git worktrees

**Why sibling workspaces rather than worktrees or branches:**

- Each workspace has its own `@` working copy and its own snapshot. You can work on several tickets in parallel without `jj edit`-thrashing a single working copy.
- The main session's default workspace stays untouched — no risk of an Opus subagent polluting the user's in-flight edits.
- jj sees all workspaces as the same repo — bookmarks, commits, and history are shared. Only the working copy state is per-workspace.

**Create the sibling workspace at the sibling directory** (e.g. `../<repo>-<TICKET>/`):

```bash
cd /path/to/repo                          # the main clone
jj workspace add ../<repo>-<TICKET>       # jj creates the directory and checks out a new workspace
cd ../<repo>-<TICKET>
jj workspace list                         # verify the new workspace appears with a fresh workspace-id
```

After `jj workspace add`, the new workspace's `@` is typically an empty child of `main` (or of whichever revision was the tip when the workspace was created). Check with `jj log -n 3`.

**Workspace naming:** `<repo>-<TICKET>` (e.g. `realfi-PP12PB-1014`). Keep it flat — one workspace per ticket; don't reuse workspaces for different tickets.

---

## 2. Bookmark: standalone on `main`, or stacked on an existing bookmark

**Standalone PR (most common):** The new bookmark points at a change on top of `main`.

```bash
cd ../<repo>-<TICKET>
jj new main                              # empty @ on top of main
jj bookmark create rasheedja/<TICKET>/<short-description> -r @
```

**Stacked PR:** The new bookmark points at a change on top of another feature bookmark (used when this ticket depends on another in-flight PR). The parent PR must exist on the remote; this PR's `--base` will be the parent bookmark's branch name.

```bash
jj new rasheedja/<PARENT_TICKET>/<parent-desc>
jj bookmark create rasheedja/<TICKET>/<short-description> -r @
```

When in doubt about whether to stack, ask the user.

---

## 3. Handle a stale workspace

If you've been working in a workspace already and come back to it, it may be **stale** (the `@` recorded for that workspace-id is on an old revision because another workspace moved the bookmark under you). Symptoms: `jj status` complains "Concurrent modification detected" or "Working copy is stale".

```bash
jj workspace update-stale
```

**Caveat:** `update-stale` rolls the working copy forward to the latest `@` for this workspace-id — which may be a **different change** than you expect (e.g. the empty child jj created after a push). If the ticket's real work is on a feature bookmark, explicitly re-point `@` with `jj new <bookmark>` after `update-stale` so edits land on the right parent. Verify with `jj log -n 3` before doing anything else.

---

## 4. Write the plan file (`PLAN-<TICKET>.md`)

Inside the workspace, write a plan file the Opus subagent will follow. **Store it in the workspace root** during implementation so the subagent can read it, but move it out before committing (see §7).

Contents:

- **Goal:** one-line summary of what the ticket achieves.
- **Context:** what's already in place, what's missing, any constraints from the ticket description.
- **Files to create / edit:** absolute paths, with a note on the change for each.
- **Implementation steps:** ordered, specific enough that the subagent doesn't need to infer scope.
- **Out of scope:** what the subagent must NOT touch (prevents drift).
- **Verification:** how to confirm the change works (command to run, file to diff, etc.).

Keep the plan concrete and file-path-level. Vague plans ("update the lambda config") produce vague PRs; specific plans ("edit `backend/lambdas/track-chain/config.go:42` to replace `FetchEscrowHashes()` with the constant `EscrowHashesMainnet`") produce reviewable ones.

---

## 5. Delegate to an Opus subagent

Spawn a subagent with `subagent_type: "general-purpose"` and **`model: "opus"`**. The prompt must be **self-contained** — the subagent has no memory of the current conversation.

**Prompt requirements:**

1. **Scope:** "You are implementing `<TICKET>`. The full plan is in `<workspace>/PLAN-<TICKET>.md` — read it first."
2. **Workspace lock:** "Only edit files under `<absolute path to workspace>`. Do not cd elsewhere. Do not touch the default workspace at `<path>`."
3. **No VCS:** "Do NOT run any `jj` or `git` commands. Do NOT commit, push, describe, or change bookmarks. The main agent handles all VCS operations."
4. **No plan edits:** "Do not modify `PLAN-<TICKET>.md`. Treat it as read-only input."
5. **Report format:** "When done, output a summary: files changed, key decisions, any deviations from the plan, and commands you ran to verify."
6. **Verification:** Include the verification commands from the plan (build, tests, lint). The subagent should run them and report results.

**Foreground vs background:**

- **Foreground** by default — you need the results to review and push. The `Agent` tool blocks until the subagent returns, keeping your main context free until then.
- **Background** (`run_in_background: true`) is useful only if you have genuinely independent work to do in parallel (e.g. watching a long AWS deploy). Be aware: background subagents cannot prompt for Bash permission approval and will stall silently (see **skill-subagent-review-main-agent-address.md §7**).

---

## 6. Review the subagent's work

When the subagent returns, **do not trust its summary alone.** Read the diff directly.

```bash
cd ../<repo>-<TICKET>
jj diff --stat                        # list changed files
jj diff <specific-path>               # read per-file diff
```

Apply the triage rules from **skill-subagent-review-main-agent-address.md §4**: accurate + in scope → keep; wrong → fix; out of scope → revert; already addressed → no change.

If targeted fixes are needed, either make them directly as the main agent, or dispatch a follow-up **haiku** subagent for mechanical fixes (see that skill, §6). Do not re-run Opus for small tweaks — it's overkill.

**Run project checks** before committing — build, tests, lint (see **skill-commits-and-pre-commit-checks.md**). Do this from the workspace directory, not the default one.

---

## 7. Move the plan file out before describing

The plan file must NOT land in the commit. Move it to a scratch location outside the repo **before** `jj describe` / `jj squash`:

```bash
mkdir -p /tmp/claude/<TICKET>
mv PLAN-<TICKET>.md /tmp/claude/<TICKET>/
```

Then verify the diff no longer contains `PLAN-<TICKET>.md`:

```bash
jj diff --stat
```

(The subagent's file edits land in `@` as untracked changes — see **skill-jujutsu.md §13**. After moving the plan out, `@` still contains only the real code changes.)

Keeping the plan is fine — just out of the workspace. You may want it later to reconstruct what was asked; `/tmp/claude/<TICKET>/` is a stable scratch path.

---

## 8. Describe, bookmark, push, draft PR

Run these from inside the workspace directory. `jj describe` and `jj git push` sign commits via gpg, which requires the **host** keychain — `dangerouslyDisableSandbox: true` is typically needed when these commands run via the Bash tool.

```bash
jj describe -m "<type>(<scope>): <subject> (<TICKET>)

- Bullet 1
- Bullet 2"

jj bookmark set rasheedja/<TICKET>/<short-description> -r @
jj git push --bookmark rasheedja/<TICKET>/<short-description> --allow-new
```

Then open the draft PR.

**Standalone PR:**

```bash
gh pr create --draft \
  --title "<type>(<scope>): <subject> (<TICKET>)" \
  --body "$(cat <<'EOF'
## Summary

- Bullet 1
- Bullet 2

## Ticket

<TICKET>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

**Stacked PR:** add `--base rasheedja/<PARENT_TICKET>/<parent-desc>` so GitHub treats it as a PR against the parent branch, not against `main`. The parent bookmark must already exist on the remote.

```bash
gh pr create --draft \
  --base rasheedja/<PARENT_TICKET>/<parent-desc> \
  --title "<type>(<scope>): <subject> (<TICKET>)" \
  --body "..."
```

Give the user the PR URL in your reply.

---

## 9. End on an empty child

After the PR is open, leave `@` as an empty child on top of the bookmark so the next edit starts clean (see **skill-jujutsu.md §9b**):

```bash
jj new @
```

This also shields the workspace from accidental amends if the user reopens it later.

---

## 10. Parallel tickets: one workspace per ticket

When running multiple Opus subagents in parallel (e.g. five lambda migrations), give each its own workspace:

```
../realfi-PP12PB-1285/
../realfi-PP12PB-1286/
../realfi-PP12PB-1287/
```

Each subagent is workspace-isolated by prompt, so the "no two subagents edit the same file" rule from **skill-subagent-review-main-agent-address.md §8** is automatically satisfied — their workspaces don't overlap. Different workspaces can even point at different bookmarks simultaneously because each workspace has an independent `@`.

---

## 11. End-to-end checklist

1. Read the ticket, evaluate, transition to "In Development" (see **skill-jira-story-to-pr-workflow.md** §1–§4).
2. `jj workspace add ../<repo>-<TICKET>`; `cd` into it.
3. `jj new main` (standalone) or `jj new <parent-bookmark>` (stacked). `jj bookmark create rasheedja/<TICKET>/<slug> -r @`.
4. Write `PLAN-<TICKET>.md` in the workspace root.
5. Spawn an Opus subagent (foreground, model opus) with a self-contained prompt: scope, workspace lock, no VCS, plan path, report format.
6. Review the subagent's diff directly; triage per **skill-subagent-review-main-agent-address.md §4**. Run project checks.
7. Move `PLAN-<TICKET>.md` out of the workspace to `/tmp/claude/<TICKET>/`.
8. `jj describe -m "<conventional message>"`; `jj bookmark set ... -r @`; `jj git push --bookmark ... --allow-new` (sandbox off for gpg).
9. `gh pr create --draft` with `--base` set for stacked PRs; post URL to the user.
10. `jj new @` to leave an empty working copy on top of the bookmark.

---

## References

| Topic | Skill |
|-------|-------|
| jj change/bookmark/push/squash | **skill-jujutsu.md** |
| Ticket read, evaluate, transition, naming | **skill-jira-story-to-pr-workflow.md** |
| Conventional commits, pre-commit checks | **skill-commits-and-pre-commit-checks.md** |
| Subagent review loop, parallel subagents, background-agent stall | **skill-subagent-review-main-agent-address.md** |
| PR title/description format | **skill-pr-title-and-description.md** |
