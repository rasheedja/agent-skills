# Skill: Opus-subagent workspace flow — isolated workspace, plan, delegate, review, draft PR

This skill describes the workflow for implementing a ticket by:

1. Creating an **isolated workspace** in a sibling directory — a **jj workspace** (if the repo uses jj) or a **git worktree** (if it's a plain git repo).
2. Branching a bookmark/branch either on top of **`main`** (standalone) or on top of an **existing feature bookmark/branch** (stacked PR).
3. Writing a **plan file** (`PLAN-<TICKET>.md`) inside the workspace.
4. Delegating implementation to an **Opus subagent** constrained to that workspace (no VCS operations, no pushing).
5. Reviewing the subagent's edits.
6. Moving the plan file **out of the workspace** before committing, so it does not land in the commit.
7. Committing, setting the bookmark/branch, pushing, and opening a **draft PR** (with `--base` for stacked PRs).
8. Leaving the workspace in a clean state for the next edit.

**Which VCS?** Detect at the start: if `.jj/` exists in the repo, use the jj path. If only `.git/` exists, use the git path. If neither, the repo is not version-controlled and this skill does not apply. When both are present (jj is a git backend), **prefer jj** — it gives you workspaces, and bypassing it with raw `git` commands can desync the snapshot.

**Prerequisites:** **skill-jujutsu.md** (jj change/bookmark/push mechanics — only when using jj), **skill-jira-story-to-pr-workflow.md** (ticket reading, evaluation, transition, naming conventions), **skill-commits-and-pre-commit-checks.md** (conventional commits, running checks), **skill-subagent-review-main-agent-address.md** (review loop after the subagent finishes).

**When to use this flow vs. implement directly:**

- Use this flow when the user says things like *"start on TICKET like usual, separate workspace, write a plan, monitor opus subagent, review, open draft pr"* — or has established this pattern for a repo.
- Skip it for trivial edits (one-liner fixes) or when the user explicitly wants the main agent to implement directly.

**Naming conventions:**

- **Workspace directory:** `<repo>-<TICKET>` at the sibling level (e.g. `../myrepo-PROJ-123/`). Flat — one workspace per ticket; don't reuse workspaces for different tickets.
- **Bookmark / branch:** `<username>/<TICKET>/<short-description>`. Replace `<username>` with whatever prefix your repo uses (typically your GitHub handle). `<short-description>` is lowercase-hyphenated, a few words.

---

## 1. Create the isolated workspace

### jj (preferred when the repo has `.jj/`)

Sibling workspaces are the right tool: each has its own `@` and its own snapshot, so you can work on multiple tickets in parallel without `jj edit`-thrashing a single working copy. The main session's default workspace stays untouched, and jj sees all workspaces as the same repo — bookmarks, commits, and history are shared; only the working copy state is per-workspace.

```bash
cd /path/to/repo                          # the main clone
jj workspace add ../<repo>-<TICKET>       # jj creates the directory and checks out a new workspace
cd ../<repo>-<TICKET>
jj workspace list                         # verify the new workspace appears with a fresh workspace-id
```

After `jj workspace add`, the new workspace's `@` is typically an empty child of `main` (or of whichever revision was the tip when the workspace was created). Check with `jj log -n 3`.

### git (plain git repo, no jj)

Use `git worktree` to the same effect: a sibling directory with its own working tree and HEAD, sharing the underlying git object database with the main clone.

```bash
cd /path/to/repo                          # the main clone
git fetch origin
git worktree add -b <username>/<TICKET>/<short-description> ../<repo>-<TICKET> origin/main
cd ../<repo>-<TICKET>
git worktree list                         # verify the new worktree appears
```

The `-b` flag creates the branch at the same time as the worktree, starting from `origin/main`. Skip `-b` and substitute an existing ref if you want to check out an existing branch.

---

## 2. Bookmark/branch: standalone on `main`, or stacked on an existing feature branch

### jj — standalone PR (most common)

```bash
jj new main                                        # empty @ on top of main
jj bookmark create <username>/<TICKET>/<slug> -r @
```

### jj — stacked PR (this ticket depends on another in-flight PR)

The parent PR must already exist on the remote; this PR's `--base` will be the parent bookmark's branch name.

```bash
jj new <username>/<PARENT_TICKET>/<parent-slug>
jj bookmark create <username>/<TICKET>/<slug> -r @
```

### git — standalone PR

The `git worktree add -b ... origin/main` command in §1 already created the branch on top of main. Nothing else to do.

### git — stacked PR

Use the parent branch as the worktree's starting point instead of `origin/main`:

```bash
git fetch origin
git worktree add -b <username>/<TICKET>/<slug> ../<repo>-<TICKET> origin/<username>/<PARENT_TICKET>/<parent-slug>
```

When in doubt about whether to stack, ask the user.

---

## 3. Handle a stale workspace (jj only)

If you've been working in a jj workspace already and come back to it, it may be **stale** (the `@` recorded for that workspace-id is on an old revision because another workspace moved the bookmark under you). Symptoms: `jj status` complains "Concurrent modification detected" or "Working copy is stale".

```bash
jj workspace update-stale
```

**Caveat:** `update-stale` rolls the working copy forward to the latest `@` for this workspace-id — which may be a **different change** than you expect (e.g. the empty child jj created after a push). If the ticket's real work is on a feature bookmark, explicitly re-point `@` with `jj new <bookmark>` after `update-stale` so edits land on the right parent. Verify with `jj log -n 3` before doing anything else.

For git worktrees, there's no equivalent staleness — the worktree's HEAD moves only when you explicitly `git checkout` or `git pull`. If you come back and the worktree has diverged from `origin`, run `git pull --rebase` (or `git fetch && git rebase origin/main`) in the worktree to catch up.

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

Keep the plan concrete and file-path-level. Vague plans ("update the lambda config") produce vague PRs; specific plans ("edit `src/config.go:42` to replace `FetchSomething()` with the constant `SomethingConst`") produce reviewable ones.

---

## 5. Delegate to an Opus subagent

Spawn a subagent with `subagent_type: "general-purpose"` and **`model: "opus"`**. The prompt must be **self-contained** — the subagent has no memory of the current conversation.

**Prompt requirements:**

1. **Scope:** "You are implementing `<TICKET>`. The full plan is in `<workspace>/PLAN-<TICKET>.md` — read it first."
2. **Workspace lock:** "Only edit files under `<absolute path to workspace>`. Do not cd elsewhere. Do not touch the default workspace at `<path>`."
3. **No VCS:** "Do NOT run any `jj` or `git` commands. Do NOT commit, push, describe, or change bookmarks/branches. The main agent handles all VCS operations."
4. **No plan edits:** "Do not modify `PLAN-<TICKET>.md`. Treat it as read-only input."
5. **Report format:** "When done, output a summary: files changed, key decisions, any deviations from the plan, and commands you ran to verify."
6. **Verification:** Include the verification commands from the plan (build, tests, lint). The subagent should run them and report results.

**Foreground vs background:**

- **Foreground** by default — you need the results to review and push. The `Agent` tool blocks until the subagent returns, keeping your main context free until then.
- **Background** (`run_in_background: true`) is useful only if you have genuinely independent work to do in parallel (e.g. watching a long deploy). Be aware: background subagents cannot prompt for Bash permission approval and will stall silently (see **skill-subagent-review-main-agent-address.md §7**).

---

## 6. Review the subagent's work

When the subagent returns, **do not trust its summary alone.** Read the diff directly.

### jj

```bash
cd ../<repo>-<TICKET>
jj diff --stat                        # list changed files
jj diff <specific-path>               # read per-file diff
```

### git

```bash
cd ../<repo>-<TICKET>
git status                            # list changed files
git diff                              # read full unstaged diff
git diff <specific-path>              # read per-file diff
```

Apply the triage rules from **skill-subagent-review-main-agent-address.md §4**: accurate + in scope → keep; wrong → fix; out of scope → revert; already addressed → no change.

If targeted fixes are needed, either make them directly as the main agent, or dispatch a follow-up **haiku** subagent for mechanical fixes (see that skill, §6). Do not re-run Opus for small tweaks — it's overkill.

**Run project checks** before committing — build, tests, lint (see **skill-commits-and-pre-commit-checks.md**). Do this from the workspace directory, not the default one.

---

## 7. Move the plan file out before committing

The plan file must NOT land in the commit. Move it to a scratch location outside the repo **before** `jj describe` / `jj squash` (jj) or `git add` / `git commit` (git):

```bash
mkdir -p /tmp/claude/<TICKET>
mv PLAN-<TICKET>.md /tmp/claude/<TICKET>/
```

Then verify the diff no longer contains `PLAN-<TICKET>.md`:

```bash
# jj
jj diff --stat

# git
git status
```

(With jj: the subagent's file edits land in `@` as untracked changes — see **skill-jujutsu.md §13**. With git: they land as unstaged modifications. After moving the plan out, the diff contains only the real code changes.)

Keeping the plan is fine — just out of the workspace. You may want it later to reconstruct what was asked; `/tmp/claude/<TICKET>/` is a stable scratch path.

---

## 8. Commit, branch/bookmark, push, draft PR

Run these from inside the workspace directory. Any command that performs GPG signing (`jj describe`, `jj git push`, `git commit -S`, `git push` with signed pushes enabled) needs the host keychain — `dangerouslyDisableSandbox: true` is typically needed when these commands run via the Bash tool.

### jj

```bash
jj describe -m "<type>(<scope>): <subject> (<TICKET>)

- Bullet 1
- Bullet 2"

jj bookmark set <username>/<TICKET>/<slug> -r @
jj git push --bookmark <username>/<TICKET>/<slug> --allow-new
```

### git

```bash
git add -A                           # or stage specific paths
git commit -m "<type>(<scope>): <subject> (<TICKET>)

- Bullet 1
- Bullet 2"

git push -u origin <username>/<TICKET>/<slug>
```

### Open the draft PR (both)

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

**Stacked PR:** add `--base <username>/<PARENT_TICKET>/<parent-slug>` so GitHub treats it as a PR against the parent branch, not against `main`. The parent bookmark/branch must already exist on the remote.

```bash
gh pr create --draft \
  --base <username>/<PARENT_TICKET>/<parent-slug> \
  --title "<type>(<scope>): <subject> (<TICKET>)" \
  --body "..."
```

**Note on `gh` + jj workspaces:** `gh pr create` must run inside a directory that git recognises as a repo. jj workspaces are not git repos (they have no `.git`), so run `gh pr create` from the main clone (or any git worktree) and pass `--head <bookmark>` if needed. Git worktrees don't have this issue — they're real git repos.

Give the user the PR URL in your reply.

---

## 9. Leave the workspace clean

### jj

After the PR is open, leave `@` as an empty child on top of the bookmark so the next edit starts clean (see **skill-jujutsu.md §9b**):

```bash
jj new @
```

This also shields the workspace from accidental amends if the user reopens it later.

### git

No equivalent needed — the worktree's HEAD sits on the feature branch, and new commits naturally stack on top. If you want to leave a "nothing to amend" signal, just verify `git status` is clean; for the next round of work, either `git commit` on top of the branch or make a fresh commit for each review round.

---

## 10. Parallel tickets: one workspace per ticket

When running multiple Opus subagents in parallel, give each its own workspace:

```
../<repo>-<TICKET_A>/
../<repo>-<TICKET_B>/
../<repo>-<TICKET_C>/
```

Each subagent is workspace-isolated by prompt, so the "no two subagents edit the same file" rule from **skill-subagent-review-main-agent-address.md §8** is automatically satisfied — their workspaces don't overlap. With jj, different workspaces can even point at different bookmarks simultaneously because each workspace has an independent `@`. With git worktrees, each has its own HEAD, so the same property holds.

---

## 11. End-to-end checklist

1. Read the ticket, evaluate, transition to "In Development" (see **skill-jira-story-to-pr-workflow.md** §1–§4).
2. Detect VCS: jj if `.jj/` exists, else git.
3. Create the workspace:
   - jj: `jj workspace add ../<repo>-<TICKET>`; `cd` into it.
   - git: `git worktree add -b <username>/<TICKET>/<slug> ../<repo>-<TICKET> origin/main`; `cd` into it.
4. Position the bookmark/branch:
   - jj: `jj new main` (standalone) or `jj new <parent-bookmark>` (stacked); `jj bookmark create <username>/<TICKET>/<slug> -r @`.
   - git: already created in step 3 (use parent branch as the start point for stacked).
5. Write `PLAN-<TICKET>.md` in the workspace root.
6. Spawn an Opus subagent (foreground, model opus) with a self-contained prompt: scope, workspace lock, no VCS, plan path, report format.
7. Review the subagent's diff directly (`jj diff` or `git diff`); triage per **skill-subagent-review-main-agent-address.md §4**. Run project checks.
8. Move `PLAN-<TICKET>.md` out of the workspace to `/tmp/claude/<TICKET>/`.
9. Commit and push:
   - jj: `jj describe -m "..."`; `jj bookmark set ... -r @`; `jj git push --bookmark ... --allow-new`.
   - git: `git add -A`; `git commit -m "..."`; `git push -u origin <branch>`.
   (Sandbox off for GPG signing.)
10. `gh pr create --draft` with `--base` set for stacked PRs; post URL to the user.
11. jj only: `jj new @` to leave an empty working copy on top of the bookmark.

---

## References

| Topic | Skill |
|-------|-------|
| jj change/bookmark/push/squash | **skill-jujutsu.md** |
| Ticket read, evaluate, transition, naming | **skill-jira-story-to-pr-workflow.md** |
| Conventional commits, pre-commit checks | **skill-commits-and-pre-commit-checks.md** |
| Subagent review loop, parallel subagents, background-agent stall | **skill-subagent-review-main-agent-address.md** |
| PR title/description format | **skill-pr-title-and-description.md** |
