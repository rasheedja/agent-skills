# Skill: Jujutsu (jj) — commits, bookmarks, and push for PR workflows

This skill covers the **jj** (Jujutsu) CLI commands used in a typical “one commit per PR comment” workflow: creating a new change, moving the branch bookmark, pushing, and getting the commit hash for a PR reply. It covers **`jj squash`** for folding fixes into an existing change without `jj edit`, and **resolving merge/rebase conflicts** (§12). It does not cover other advanced jj concepts (e.g. evolutions).

For **commit message format** (conventional commits, body with bullets) and **running project checks before committing** (Makefile, npm scripts, CI, etc.), see **skill-commits-and-pre-commit-checks.md**.

**Prerequisites:** Repo is a jj repository (`jj log` works). For pushing, a git remote and `jj git push` (or equivalent) must be configured.

---

## 1. Basic concepts

- **Working copy** — The current change you’re editing; shown as `@` in `jj log`.
- **Parent** — The change that your current change is based on; often written as `@-` (e.g. “parent of @”).
- **Bookmark** — A named reference (e.g. a branch name like `rasheedja/PP12PB-599/store-hashmap-owners`) that points at a specific change. Use **`jj bookmark`** (not `jj book`).
- **Commit / change** — In jj, each “change” has an id; when you push, it corresponds to a git commit. The **commit_id** from jj is the git commit hash (40-char hex) once exported.

---

## 2. Agent preferences: empty working copy; prefer `jj new` and `jj squash` over `jj edit`

**Problem:** A human or agent does follow-up work without checking `jj log` or `jj status`. If the working copy (`@`) still sits on a **real commit** (not an empty child on top), the next file edits can **amend or mix into that commit**—producing history or content nobody intended.

**Default habits:**

1. **Finish routine work on an empty change.** After you have described the change you care about and moved the branch bookmark, leave `@` on a **new empty child** on top of the branch tip (`jj new @` or `jj new <bookmark>`—see §9b). Treat “empty `@` on top of the bookmark” as the normal resting state between tasks.

2. **Prefer `jj new` + `jj squash` instead of `jj edit` for changing an existing revision.** To adjust a commit `R` without checking out `R` as the working copy:
   ```bash
   jj new R
   # @ is now an empty child of R; edit files
   jj squash
   ```
   With no extra arguments, `jj squash` moves changes from `@` into its parent (`R`), folding your edits into `R`. (If `R` has multiple parents—a merge—plain `jj squash` may fail; use `jj squash --help` and `--from` / `--into` for those cases.)

3. **When `jj edit` is still appropriate:** Resolving merge/rebase conflicts (§12) often requires **`jj edit <rev>`** so the working tree matches the conflicted revision. That is an intentional exception—not the default for “fix an older commit” or “add another commit on the branch.”

---

## 3. List bookmarks and find the branch

```bash
jj bookmark list
```

- Shows each bookmark name and the change (short id + description) it points at.
- Use the **branch bookmark** (e.g. the PR’s head branch) as the parent when creating the next fix so your new commit is on the same branch.

**Example output:**
```
main: poytkyww a3f6d3dd fix: separate env keys...
rasheedja/PP12PB-599/store-hashmap-owners: mtuktqyt f11176e0 docs: align plan to owner_value...
```

---

## 4. Create a new change (one commit per fix)

```bash
jj new <PARENT> -m "descriptive message"
```

- `<PARENT>` is a revset: usually `@` (current change) when you’re already on the branch tip, or the **bookmark name** (e.g. `rasheedja/PP12PB-599/store-hashmap-owners`) to branch from the current branch tip. Using the bookmark ensures you’re on top of the latest pushed commit.
- Creates a new empty change with the given message; the working copy moves to it (`@` is now this new change).
- Then **edit files** in the working copy; the change will contain those edits.

**Example:**
```bash
jj new rasheedja/PP12PB-599/store-hashmap-owners -m "fix: restrict owner_map env_prefixes to ONCHAIN_EVENTS_OWNER_MAP only"
# then edit files; @ now has your edits
```

---

## 5. Move the branch bookmark to your new change

After you’ve made the edit and want this change to be the new branch tip:

```bash
jj bookmark set <BOOKMARK_NAME> -r @
```

- `<BOOKMARK_NAME>` is the branch name (e.g. `rasheedja/PP12PB-599/store-hashmap-owners`).
- `-r @` means “point the bookmark at the current change.”
- Result: the branch now points at your new commit so the next push will update the remote branch.

---

## 6. Push the branch

```bash
jj git push --branch <BOOKMARK_NAME>
```

- Pushes the change that the bookmark points at to the remote (e.g. `origin`). Use the same name as in §5.
- If you see “Changes to push… Move forward bookmark…”, the push will update the remote branch to your new commit.

---

## 7. Get the commit hash for a PR reply

After pushing, you need the **git commit hash** (40-char hex) to paste in your PR reply:

```bash
jj log -r @ -T 'commit_id' -n 1
```

- `@` is the current change (your just-pushed commit).
- Output is the full commit id (e.g. `2b15096ad64c83dd51d191431e6dcc88082ff017`). Use this in the reply body (e.g. “Commit: 2b15096a…”).

---

## 8. Abandoning a change (no code change for a comment)

If you decide not to make a code change for a comment (reply only), you may have created an empty change by mistake. To discard it and return to the previous state:

```bash
jj abandon @
```

- The working copy will move to another change (e.g. the parent). You can then reply in the PR without pushing a new commit.

---

## 9. Quick reference: “one commit per comment” sequence

1. `jj new <branch_bookmark> -m "fix: ..."`   — create new change from branch tip  
2. Edit files (working copy is `@`)  
3. `jj bookmark set <branch_bookmark> -r @`    — point branch at new change  
4. **Ensure working copy is a new empty commit** — see §9b.  
5. `jj git push --branch <branch_bookmark>`   — push to remote  
6. `jj log -r <bookmark> -T 'commit_id' -n 1`  — get commit hash for PR reply (use bookmark, since `@` may be the empty child)  
7. Reply in PR thread with commit hash, then resolve thread (see skill-gh-pr-review-comments.md, skill-pr-review-loop.md).

---

## 9b. After committing: leave working copy on a new empty change

Once an agent has finished making a commit (e.g. described the change and moved the branch bookmark to it), they **must** ensure the current jj state is a **new, empty change** on top of the commit they just made. That way the next edit starts from a clean slate and does not amend the last commit by mistake. **Rationale:** see §2.

- **Normal case (you just described and bookmarked a change):** Create a new empty child so the working copy moves there:
  ```bash
  jj new @
  ```
  After this, `@` is the new empty change (no description); the bookmark still points at the commit you just finished. Future edits go into this empty change.

- **After folding a fix into an older commit with `jj new R` + `jj squash`:** Run `jj new <branch_bookmark>` (or `jj new @` if `@` is already the branch tip) so `@` is again an empty child on top of the branch tip before you stop.

- **When it's unreasonable:** If the workflow explicitly requires staying on the same change (e.g. you are about to run a command that expects `@` to be the commit you just made), you may skip creating the empty child. In that case, note in the reply that the working copy was left on the last commit intentionally.

**Summary:** Unless there's a good reason not to, always end with `jj new @` (or `jj new <bookmark>` after squash/rebase) so the working copy is a new empty commit on top of the branch, with no description.

---

## 10. Splitting one change into multiple commits

When you have a single change that you want to turn into **several conventional commits** (e.g. one per package or layer):

1. **Describe the whole change first** so the “remaining” part keeps a message you can overwrite:
   ```bash
   jj describe -m "feat(scope): overall summary

   - Bullet one
   - Bullet two"
   ```

2. **Split by fileset** — the **selected** paths stay in the original commit; the **remaining** edits go into a new child. Use `-m` for the **first** (selected) commit’s message:
   ```bash
   jj split path/to/first/part/ -m "feat(first): first logical commit message"
   ```
   After this, `@` is the **remaining** change (the new child). The parent is the commit that now contains only the selected paths.

3. **Re-describe the remaining change** with its own conventional message:
   ```bash
   jj describe -m "feat(second): second logical commit message"
   ```

4. **Repeat** if you want more commits: run `jj split <next_paths> -m "..."` on the current `@`, then describe the new remaining change.

**Example:** One big feature change split into three commits: (1) a new internal package, (2) config and DB layer, (3) service + app + cmd wiring. First split with the new package path; then split again with config and db paths; finally describe the remaining change (service, app, cmd).

---

## 11. Revsets (for reference)

- `@` — current working copy change  
- `@-` — parent of `@`  
- `<bookmark_name>` — the change the bookmark points at (e.g. `rasheedja/PP12PB-599/store-hashmap-owners`)  
- `jj log -n 5` — show last 5 changes (graph)

---

## 12. Resolving merge/rebase conflicts

After a rebase or merge, some revisions may be in conflict. Resolve them **from oldest to newest** so that fixing a parent allows jj to rebase descendants and sometimes clear their conflicts too.

**Note:** This section uses **`jj edit`** on purpose (see §2)—you need the working copy on the conflicted revision to resolve markers.

### 12.1 Find which revisions have conflicts

```bash
jj log -n 30
```

- Revisions with conflicts show **`×`** and **`(conflict)`** next to the change id and description.
- Clean revisions show **`○`**.

To see which **files** are conflicted in a given revision:

```bash
jj resolve --list -r <REVSET>
```

- `<REVSET>` can be the short change id (e.g. `xkopwonn`) or a bookmark. Example: `jj resolve --list -r npmmkmyz`.
- Output is the list of paths with "2-sided conflict" or "3-sided conflict".

### 12.2 Resolve conflicts one revision at a time

1. **Edit the oldest conflicting revision** (the one closest to the branch base):
   ```bash
   jj edit <SHORT_CHANGE_ID>
   ```
   The working copy is now that revision. You may see "Rebased N descendant commits onto updated working copy" when the parent was just fixed.

2. **Open the conflicted files** and remove conflict markers, keeping the desired content (see §12.3 for marker formats).

3. **Save and move to the next conflicting revision.** Run `jj log` again; some conflicts may already be gone after the rebase. Then `jj edit <NEXT_CONFLICTING_ID>` and fix any remaining markers in the working copy.

4. **Repeat** until `jj log` shows no `×` or `(conflict)`.

5. **When all conflicts are cleared:** Prefer **`jj new <branch_bookmark>`** (or `jj new @` if appropriate) so `@` rests on an empty change on top of the branch tip (§2, §9b).

### 12.3 Conflict marker formats

**2-sided conflict** (merge of two versions):

```
<<<<<<< <rev> "description" (rebase destination)
  our version
||||||| <rev> "description" (parents of rebased revision)
  base version
=======
  their version
>>>>>>> <rev> "description" (rebased revision)
```

- Choose one side (or combine). **"rebase destination"** is usually the branch you rebased onto; **"rebased revision"** is the incoming change. Delete the markers and all but the content you want to keep.

**3-sided conflict** (merge of three or more):

```
<<<<<<< conflict 1 of N
+++++++ <rev> "description" (rebase destination)
  version A
------- <rev> "description" (rebased revision)
  version B
+++++++ <rev> "description" (rebased revision)
  version C
>>>>>>> conflict 1 of N ends
```

- Pick one variant (or merge manually). Delete from `<<<<<<<` through `>>>>>>> conflict … ends` and leave only the resolved text.

**Tip:** Files may use **Unicode quotes** (“ ”) in the text. If string replacement fails, use a small script (e.g. Python) to find the conflict block by `<<<<<<<` / `>>>>>>>` and replace with the chosen content.

### 12.4 What to keep when resolving

- Prefer the **rebase destination** or **consistent semantics** with the rest of the branch (e.g. same config shape: `cutoverPtr` vs `cutover`, same error semantics: "owner not found" vs "owner map lookup not configured").
- After editing, run `jj log -n 20` again; ensure no revision still shows `(conflict)` before considering the job done.

---

## 13. Subagents editing files while `@` is an empty working copy

When the main agent leaves `@` on a new empty child (per §9b) and then spawns a subagent to make file edits, those edits land in `@` — **not** in the bookmark commit (`@-`). This is the normal jj snapshot behaviour: any file change in the working tree is attributed to the current `@`.

**Result:** after subagent edits, `jj diff -r <bookmark>` will show fewer files than expected; `jj diff` (working copy) will show all the subagent's changes.

**Fix — always run `jj squash` after subagent edits:**

```bash
jj diff --stat          # confirm subagent edits are in @
jj squash               # fold @ into parent (the bookmark commit)
jj diff -r <bookmark> --stat  # verify all expected files are now in the commit
```

After `jj squash`, `@` is again a new empty child on top of the bookmark, and the bookmark commit contains the full set of changes.

**When spawning multiple subagents in sequence:** each subagent's edits accumulate in `@`. A single `jj squash` at the end (after all subagents have finished) is sufficient — you do not need to squash between each one.
