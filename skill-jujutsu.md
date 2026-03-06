# Skill: Jujutsu (jj) — commits, bookmarks, and push for PR workflows

This skill covers the **jj** (Jujutsu) CLI commands used in a typical “one commit per PR comment” workflow: creating a new change, moving the branch bookmark, pushing, and getting the commit hash for a PR reply. It also covers **resolving merge/rebase conflicts** (§11). It does not cover other advanced jj concepts (e.g. squash, evolutions).

For **commit message format** (conventional commits, body with bullets) and **running project checks before committing** (Makefile, npm scripts, CI, etc.), see **skill-commits-and-pre-commit-checks.md**.

**Prerequisites:** Repo is a jj repository (`jj log` works). For pushing, a git remote and `jj git push` (or equivalent) must be configured.

---

## 1. Basic concepts

- **Working copy** — The current change you’re editing; shown as `@` in `jj log`.
- **Parent** — The change that your current change is based on; often written as `@-` (e.g. “parent of @”).
- **Bookmark** — A named reference (e.g. a branch name like `rasheedja/PP12PB-599/store-hashmap-owners`) that points at a specific change. Use **`jj bookmark`** (not `jj book`).
- **Commit / change** — In jj, each “change” has an id; when you push, it corresponds to a git commit. The **commit_id** from jj is the git commit hash (40-char hex) once exported.

---

## 2. List bookmarks and find the branch

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

## 3. Create a new change (one commit per fix)

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

## 4. Move the branch bookmark to your new change

After you’ve made the edit and want this change to be the new branch tip:

```bash
jj bookmark set <BOOKMARK_NAME> -r @
```

- `<BOOKMARK_NAME>` is the branch name (e.g. `rasheedja/PP12PB-599/store-hashmap-owners`).
- `-r @` means “point the bookmark at the current change.”
- Result: the branch now points at your new commit so the next push will update the remote branch.

---

## 5. Push the branch

```bash
jj git push --branch <BOOKMARK_NAME>
```

- Pushes the change that the bookmark points at to the remote (e.g. `origin`). Use the same name as in §4.
- If you see “Changes to push… Move forward bookmark…”, the push will update the remote branch to your new commit.

---

## 6. Get the commit hash for a PR reply

After pushing, you need the **git commit hash** (40-char hex) to paste in your PR reply:

```bash
jj log -r @ -T 'commit_id' -n 1
```

- `@` is the current change (your just-pushed commit).
- Output is the full commit id (e.g. `2b15096ad64c83dd51d191431e6dcc88082ff017`). Use this in the reply body (e.g. “Commit: 2b15096a…”).

---

## 7. Abandoning a change (no code change for a comment)

If you decide not to make a code change for a comment (reply only), you may have created an empty change by mistake. To discard it and return to the previous state:

```bash
jj abandon @
```

- The working copy will move to another change (e.g. the parent). You can then reply in the PR without pushing a new commit.

---

## 8. Quick reference: “one commit per comment” sequence

1. `jj new <branch_bookmark> -m "fix: ..."`   — create new change from branch tip  
2. Edit files (working copy is `@`)  
3. `jj bookmark set <branch_bookmark> -r @`    — point branch at new change  
4. `jj git push --branch <branch_bookmark>`   — push to remote  
5. `jj log -r @ -T 'commit_id' -n 1`          — get commit hash for PR reply  
6. Reply in PR thread with commit hash, then resolve thread (see skill-gh-pr-review-comments.md, skill-pr-review-loop.md).

---

## 9. Splitting one change into multiple commits

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

## 10. Revsets (for reference)

- `@` — current working copy change  
- `@-` — parent of `@`  
- `<bookmark_name>` — the change the bookmark points at (e.g. `rasheedja/PP12PB-599/store-hashmap-owners`)  
- `jj log -n 5` — show last 5 changes (graph)

---

## 11. Resolving merge/rebase conflicts

After a rebase or merge, some revisions may be in conflict. Resolve them **from oldest to newest** so that fixing a parent allows jj to rebase descendants and sometimes clear their conflicts too.

### 11.1 Find which revisions have conflicts

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

### 11.2 Resolve conflicts one revision at a time

1. **Edit the oldest conflicting revision** (the one closest to the branch base):
   ```bash
   jj edit <SHORT_CHANGE_ID>
   ```
   The working copy is now that revision. You may see "Rebased N descendant commits onto updated working copy" when the parent was just fixed.

2. **Open the conflicted files** and remove conflict markers, keeping the desired content (see §11.3 for marker formats).

3. **Save and move to the next conflicting revision.** Run `jj log` again; some conflicts may already be gone after the rebase. Then `jj edit <NEXT_CONFLICTING_ID>` and fix any remaining markers in the working copy.

4. **Repeat** until `jj log` shows no `×` or `(conflict)`.

### 11.3 Conflict marker formats

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

### 11.4 What to keep when resolving

- Prefer the **rebase destination** or **consistent semantics** with the rest of the branch (e.g. same config shape: `cutoverPtr` vs `cutover`, same error semantics: "owner not found" vs "owner map lookup not configured").
- After editing, run `jj log -n 20` again; ensure no revision still shows `(conflict)` before considering the job done.
