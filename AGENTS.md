# Instructions for agents: using and maintaining this skills repo

This repo (**agent-skills**) holds skill documents that agents should use when handling user tasks. Agents are also allowed and encouraged to **improve** these skills: add content, create new skills, and fix or remove incorrect or outdated content. This file explains how to **find** information in skills and how to **update** them (including commit and branch rules).

**When making changes in any git/jj repo** (including this one), use **skill-commits-and-pre-commit-checks.md**: conventional commits, small logical commits, and running the project’s checks (Makefile, npm scripts, CI, etc.) before committing.

**Path to this repo:** `~/Documents/personal/git/agent-skills/` (full path: `/Users/junaid/Documents/personal/git/agent-skills/`).

---

## 1. Finding information in skills

When a task could benefit from a skill (e.g. GitHub PRs, Jira, jujutsu, code reviews), discover and read the relevant skill files as follows.

### 1.1 List available skills

- Skill files are named **`skill-<topic>.md`** (e.g. `skill-jujutsu.md`, `skill-gh-pr-review-comments.md`).
- **List files:** List the repo directory or search for filenames matching `skill-*.md` to see all skills.
- Use the **first line** of each file as a catalog: skills start with `# Skill: <Name> — <short description>`. Scanning titles helps you pick the right file.

### 1.2 Find skills by topic

- **By title:** Search for topic keywords in the first line or in `# Skill:` lines (e.g. grep for "jira", "PR", "review", "jujutsu"). That narrows down which file to open.
- **By content:** Search inside the repo for phrases or concepts (e.g. grep for "jj new", "review comment", "bookmark set"). Prefer starting with a title/keyword search to get candidate files, then open those files or grep within them for the exact detail.
- **Cross-references:** Many skills link to others (e.g. "see skill-gh-pr-review-comments.md"). Follow those links when a skill points you elsewhere.

### 1.3 Suggested workflow

1. List or search **titles** to find candidate skills.
2. **Open** the most likely file(s) and read the relevant sections.
3. If you need a specific phrase or command, **grep** (or semantic search) in the repo for that phrase to find the right file and section.
4. Use **in-file links** (e.g. "see skill-foo.md") to jump to related skills when the doc says so.

---

## 2. Updating skills

Agents may add to, create, correct, or remove content in this repo. Every such change must be committed with jujutsu (see §3). Never push to the `master` branch; use a separate branch (bookmark) for your changes (see §4).

### 2.1 Add content to existing skills

- When you learn something new that belongs in an existing skill (e.g. a new command, a caveat, a better example), **add** it in the right place: new section, new bullet, or extended example.
- Keep the same style and structure as the rest of the file (numbered sections, code blocks, clear headings).
- Prefer **minimal, focused** additions rather than long digressions.

### 2.2 Create new skill files

- For a new topic that doesn’t fit an existing skill, create **`skill-<topic>.md`** (e.g. `skill-docker-build.md`).
- Use the same structure as existing skills: a first line `# Skill: <Name> — <short description>`, optional "Prerequisites" or "Scope", then numbered sections (e.g. `## 1. …`, `## 2. …`) with code blocks and examples where useful.
- Cross-reference related skills by filename (e.g. "For PR comment mechanics, see **skill-gh-pr-review-comments.md**.").

### 2.3 Correct or clarify existing content

- Fix **errors** (wrong commands, outdated flags, incorrect explanations).
- **Clarify** wording that is ambiguous or confusing.
- Prefer small, targeted edits so the change is easy to review.

### 2.4 Remove incorrect or irrelevant content

- **Delete** or rewrite content that is wrong or no longer relevant.
- If a whole section is obsolete, remove it; if only a sentence is wrong, fix or delete that sentence.
- Avoid leaving broken cross-references: if you remove a section that other text refers to, update or remove the reference.

---

## 3. Commits: conventional commits and body (Jujutsu)

- **Every** change to this repo (new file, edit, or delete) must result in a **jujutsu commit**. Use the workflow in **skill-jujutsu.md** (`jj new`, edit files, `jj bookmark set`, and when pushing, `jj git push --branch <bookmark>`).
- **One commit per logical change:**
  - One **new skill** → one commit.
  - One **update** to a skill (e.g. "add section on X") → one commit.
  - **Multiple edits in one commit** are fine when they are part of the same logical change (e.g. "fix typos in skill-jira-acli.md" touching several lines, or "update Jira skill: add daily-summary and fix acli examples").
- **Use conventional commits.** Format: **`<type>(<scope>): <short description>`**
  - **Type:** Use `docs` for skill docs (new skill, add/change/remove content), `fix` for corrections, `refactor` for restructuring without changing meaning. For this repo, `docs` will be most common.
  - **Scope:** Use `skills` (e.g. `docs(skills): ...`). Optionally add the skill name: `docs(skills/jira-acli): ...`.
  - **Subject:** Short, imperative summary (e.g. "add section on X", "new skill for Docker builds", "fix jj push example").
- **Use bullet points in the commit body for details.** Put the conventional subject on the first line; add a blank line, then bullet points describing what changed and why (if useful).
  - Example:
    ```
    docs(skills): add conventional-commit instructions to AGENTS.md

    - Require type(scope): subject and body with bullets
    - Add examples for docs/fix types and scope "skills"
    ```
  - Another example:
    ```
    docs(skills): new skill for Jira daily summary

    - Add skill-jira-daily-summary.md with acli commands and output format
    - Cross-reference skill-jira-acli.md for auth
    ```

---

## 4. Branches: never push to master

- **Do not push to the `master` branch.** Treat `master` as protected; all agent edits go on other branches.
- Agents may **create and push to other branches**. In jujutsu terms: create a **bookmark** for your branch (e.g. `agent-skills/update-review-skill` or `agent-skills/new-skill-docker`), make your change and commit, move the bookmark to your new change, then **push that bookmark** with `jj git push --branch <bookmark>`.
- Use a **descriptive branch/bookmark name** so it’s clear what the change is (e.g. `agent-skills/fix-jira-acli`, `agent-skills/add-pr-checklist`). The human can then merge via PR or locally.

---

## 5. Quick reference

| Goal | Action |
|------|--------|
| Commits in any git/jj repo | Use **skill-commits-and-pre-commit-checks.md**: conventional commits, small commits, run project checks before committing. |
| Find a skill | List `skill-*.md`; search titles or grep for topic/phrase; follow in-file links. |
| Add to a skill | Edit the file; add section or example; commit with jj (one commit per logical change). |
| New skill | Create `skill-<topic>.md` with same structure as others; commit. |
| Fix/remove content | Edit or delete; keep references consistent; commit. |
| Commit | Conventional commit: `type(scope): subject`; body with bullet points for details. Use **skill-jujutsu.md**: `jj new <parent> -m "message"`, edit, `jj bookmark set <bookmark> -r @`. |
| Push | `jj git push --branch <bookmark>` — **never** push to `master`; use a separate bookmark. |
| Subagent review → main agent address | Use **skill-subagent-review-main-agent-address.md**: subagent reviews, main agent triages and makes changes, loop until no further comments; do not commit review files. |

---

## 6. Cross-reference: Jujutsu workflow

For the full jujutsu workflow (new change, bookmark, push, commit hash), see **skill-jujutsu.md**. Use that skill whenever you are making commits or pushes in this repo (or in any jj repo).
