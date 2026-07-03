# Skill: Jira story to PR — read, evaluate, implement (TDD), and open draft PR

This skill describes how to take a Jira story (or task), critically evaluate it, verify it against the codebase, move it to In Progress, implement it in a TDD style, and open a draft PR with an appropriate title and description—giving the user the PR link. It covers both **git** and **jujutsu (jj)** workflows and uses branch/bookmark naming `rasheedja/$STORY_KEY/short-description`.

**Prerequisites:** **skill-jira-acli.md** (Jira via `acli`), **skill-commits-and-pre-commit-checks.md** (conventional commits, pre-commit checks), **skill-jujutsu.md** (if using jj), and **skill-pr-title-and-description.md** (PR title/body). For opening a PR you need `gh` (GitHub CLI) or equivalent.

---

## 1. Read the story from Jira

- **Get the story key** from the user (e.g. `PP12PB-599`) or from a board/search.
- **Fetch full details** so you can evaluate and implement:

```bash
acli jira workitem view <STORY_KEY> --fields "key,summary,status,description,comment,issuetype,assignee" --json
```

Or human-readable:

```bash
acli jira workitem view <STORY_KEY> --fields "key,summary,status,description,comment"
```

- Extract: **summary**, **description** (requirements, acceptance criteria), **status**, **comments** (for clarification or constraints). If the project uses custom fields for acceptance criteria, include them via `--fields` or `--fields "*navigable"`.

---

## 2. Critically evaluate the story

Before touching the codebase, decide whether the story is **actionable**.

- **Clarity:** Are requirements and acceptance criteria specific enough to implement and test? If vague or contradictory, note what’s missing and either ask the user or add a short evaluation in your reply.
- **Scope:** Is it a single logical change (one PR), or should it be split? Prefer one story → one PR unless the story explicitly spans multiple deliverables.
- **Dependencies:** Does the story reference blockers, other tickets, or external systems? If blocked or blocked-by is set, check **skill-jira-acli.md** for `acli jira workitem link list --key <KEY>` and assess whether you can still proceed.
- **Status:** If the workflow requires a specific status (e.g. “Ready for Dev” or “In Development”) before coding, note it. You will move the issue to “In Progress” (or equivalent) only after you’ve confirmed it’s workable.

**Output for the user:** A short summary: “Story KEY: Summary. Requirements: … Acceptance criteria: … Assessment: [ready / blocked / needs clarification — …].”

---

## 3. Check requirements against the codebase

- **Map story to code:** Search the repo for the areas that the story affects (modules, APIs, config, tests). Confirm where new or changed behaviour should live and that you’re not duplicating or contradicting existing behaviour.
- **Feasibility:** Decide whether the change can be implemented with the current architecture and tests. If not, report back (e.g. “Story requires X which doesn’t exist; suggest spike or follow-up story”).
- **Definition of “can be worked on”:** You can proceed only if: (1) requirements are clear enough, (2) the story is not blocked, (3) the codebase has a clear place for the change, and (4) you have (or can create) a way to run tests and checks.

If any of these fail, **stop** and return a concise report to the user with next steps (e.g. clarify acceptance criteria, resolve blocker, or refactor first).

---

## 4. Move the story to In Progress (or equivalent)

Once you’ve decided to implement:

- **Transition name** varies by project (e.g. “In Progress”, “In Development”). Use the status name your board uses. If unsure, open the issue in the Jira UI and check available transitions, or try common names.

```bash
acli jira workitem transition <STORY_KEY> --transition "In Progress"
```

If that fails (wrong name), try alternatives such as `"In Development"` or check Jira for the exact transition label. Optionally **assign** the issue to the current user: `acli jira workitem assign <STORY_KEY> --assignee @me`.

---

## 5. Workspace and branch/bookmark

- **Workspace / worktree:** If the user wants an isolated workspace, use a **git worktree** so the main clone stays on its branch:

```bash
git worktree add ../<REPO>-<STORY_KEY> -b <BRANCH_NAME>
cd ../<REPO>-<STORY_KEY>
```

Otherwise work in the existing clone and create the branch there.

- **Branch (git)** or **bookmark (jj)** name — **the repo's own convention takes precedence** (its `CLAUDE.md` / `AGENTS.md`, or a user instruction; e.g. realfi uses `feature/<jira-ticket>-<name>`). See **skill-jujutsu.md**. Only when the repo states none, use the personal default:

  **`rasheedja/$STORY_KEY/short-description`**

  - `short-description`: lowercase, hyphenated, few words (e.g. `store-hashmap-owners`, `add-login-rate-limit`).

**Git:**

```bash
git fetch origin
git checkout -b rasheedja/<STORY_KEY>/<short-description> origin/main
# or origin/develop / default branch as appropriate
```

**Jujutsu:** Create a new change from the desired parent (e.g. `main`) and set the bookmark:

```bash
jj new main -m "feat(scope): <short description>"
# Edit files as needed, then:
jj bookmark set rasheedja/<STORY_KEY>/<short-description> -r @
```

See **skill-jujutsu.md** for the full sequence (e.g. creating the change, moving the bookmark, leaving working copy on a new empty change after commits).

---

## 6. Implement in TDD style (tests first)

- **Red–green–refactor:** Write or update **unit tests** (and integration tests if relevant) that define the desired behaviour and fail. Then implement the minimum code to make them pass. Refactor as needed while keeping tests green.
- **Coverage:** Focus on thorough unit tests for the behaviour described in the story and acceptance criteria. Add edge cases and error paths that the story implies.
- **Run tests and project checks** before every commit. Follow **skill-commits-and-pre-commit-checks.md**: discover and run the project’s test/lint/build commands (Makefile, `npm run test`, `cargo test`, etc.) and fix failures before committing.

---

## 7. Commits (conventional) and VCS

- **Conventional commits:** Every commit must follow `<type>(<scope>): <short description>`. Use `feat` for new behaviour, `fix` for bug fixes, `test` for test-only changes. Add a body with bullet points when it helps. See **skill-commits-and-pre-commit-checks.md**.
- **Git:** `git add` and `git commit -m "type(scope): description"` (and optional `-m "body"`). Prefer small, logical commits.
- **Jujutsu:** Use `jj new`, edit, then `jj describe -m "..."` and `jj bookmark set rasheedja/<STORY_KEY>/<short-description> -r @` so the bookmark stays at the tip; then **`jj new @`** so `@` is an empty change on top (avoids accidental amends). To adjust an older revision, prefer **`jj new <rev>`** + **`jj squash`** over **`jj edit`**. Use `jj split` when one change becomes multiple commits. See **skill-jujutsu.md** §2, §9b.

---

## 8. Push and open a draft PR

- **Push:**

  **Git:**

  ```bash
  git push -u origin rasheedja/<STORY_KEY>/<short-description>
  ```

  **Jujutsu:**

  ```bash
  jj git push --branch rasheedja/<STORY_KEY>/<short-description>
  ```

- **Draft PR:** Prefer opening as **draft** so the user can review before marking ready.

  **GitHub CLI:**

  ```bash
  gh pr create --draft --title "<conventional-commit style title>" --body "<description>"
  ```

  Title should follow the same style as commits (e.g. `feat(scope): short description (STORY_KEY)`). For the body, use **skill-pr-title-and-description.md**: bullet points summarizing what changed and why, and reference the Jira key.

  **Example:**

  ```bash
  gh pr create --draft \
    --title "feat(rewards): support owner hashes for points (PP12PB-600)" \
    --body "## Summary

  - **Owner resolution:** ...
  - **Tests:** ...
  - Fixes PP12PB-600"
  ```

  If the repo is not the current `gh` default, add `--repo <OWNER/REPO>`.

- **Get the PR link:** After `gh pr create`, the CLI prints the PR URL. You can also run:

  ```bash
  gh pr view --web
  ```

  or:

  ```bash
  gh pr view --json url -q '.url'
  ```

  **Give the user the link** in your reply (e.g. “Draft PR: https://github.com/owner/repo/pull/123”).

---

## 9. End-to-end checklist

1. **Read:** `acli jira workitem view <STORY_KEY>`; capture summary, description, acceptance criteria, status.
2. **Evaluate:** Clear? Unblocked? Single PR scope? If not, report back and stop.
3. **Codebase:** Map requirements to code; confirm feasibility and where to implement.
4. **Decision:** If not workable, report back. If workable, proceed.
5. **Transition:** `acli jira workitem transition <STORY_KEY> --transition "In Progress"` (or equivalent).
6. **Workspace (optional):** `git worktree add ...` if desired; otherwise use existing clone.
7. **Branch/bookmark:** Create `rasheedja/<STORY_KEY>/<short-description>` (git branch or jj bookmark).
8. **TDD:** Write/update tests first, then implement; run project checks before each commit.
9. **Commit:** Conventional commits; small logical commits; follow **skill-commits-and-pre-commit-checks.md** and **skill-jujutsu.md** if using jj.
10. **Push:** `git push` or `jj git push --branch <bookmark>`.
11. **Draft PR:** `gh pr create --draft --title "..." --body "..."`; get URL and **give the user the PR link**.

---

## References

| Topic | Skill / doc |
|-------|-------------|
| Jira (view, transition, links) | **skill-jira-acli.md** |
| Conventional commits, pre-commit checks | **skill-commits-and-pre-commit-checks.md** |
| Jujutsu (change, bookmark, push) | **skill-jujutsu.md** |
| PR title and description | **skill-pr-title-and-description.md** |
