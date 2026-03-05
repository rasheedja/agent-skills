# Skill: Conventional commits and pre-commit checks (any git/jj repo)

When you make changes in a **git or jujutsu (jj) repository**, use **conventional commits** and **small, logical commits**. Before each commit, **discover and run** the project’s checks and tests (Makefile, npm scripts, CI config, etc.). This applies to all work you do in version-controlled repos, not only the agent-skills repo.

For **jj-specific mechanics** (creating a change, moving bookmarks, pushing), see **skill-jujutsu.md**. This skill covers **message format**, **commit granularity**, and **what to run before committing**.

---

## 1. Conventional commit format

Use the **conventional commit** format for every commit you create:

- **Subject (first line):** `<type>(<scope>): <short description>`
  - **Type:** `feat` (new feature), `fix` (bug fix), `docs` (documentation), `refactor` (restructure without changing behavior), `test` (tests only), `chore` (tooling, config, no code/docs change). Use lowercase.
  - **Scope:** Optional; the area of the codebase (e.g. `api`, `auth`, `frontend`). Omit if not useful.
  - **Description:** Short, imperative summary (e.g. "add login validation", "fix null deref in parser"). No period at the end.
- **Body (optional but recommended):** After a blank line, add bullet points describing what changed and why, when it helps reviewers.

**Example:**

```
feat(auth): add login rate limiting

- Cap failed attempts per IP in a 5m window
- Return 429 with Retry-After when over limit
```

**Another example:**

```
fix(parser): handle empty input without crash

- Guard on empty string before calling parse()
- Add unit test for empty input
```

---

## 2. Small, logical commits

- **One logical change per commit.** One fix, one feature, one refactor, one docs update. Avoid mixing unrelated edits.
- **Multiple files in one commit** are fine when they belong to the same change (e.g. implementation + test, or rename + all references).
- **Multiple related edits** (e.g. "fix all typos in README") can be one commit; unrelated fixes should be separate commits so history stays clear and revertible.

---

## 3. Before committing: discover and run project checks

Before you create a commit, **examine the repo** to find what checks, tests, or builds the project expects, then **run the relevant ones**. Only commit if they pass (or you have an explicit reason to skip, e.g. known flake; prefer fixing first).

### 3.1 Where to look

Check these (and similar) locations for test/check/lint/build commands:

| Location | What to look for |
|----------|-------------------|
| **Makefile** | Targets such as `test`, `check`, `lint`, `verify`, `build`, `ci`. Run the ones that apply (e.g. `make test`, `make lint`). |
| **package.json** (npm/yarn/pnpm) | `scripts` (e.g. `test`, `lint`, `build`, `typecheck`, `validate`). Run via `npm run test`, `npm run lint`, etc. |
| **.github/workflows/** | YAML workflow files: look for jobs that run tests, linters, or build. Run the same commands locally if possible (e.g. `npm ci && npm run test`). |
| **Cabal** (Haskell) | `cabal test`, `cabal build`, or project-specific targets in a Makefile that wraps cabal. |
| **Cargo** (Rust) | `cargo test`, `cargo clippy`, `cargo fmt -- --check`. |
| **Poetry / pip / pyproject.toml** (Python) | `pytest`, `tox`, `ruff`, `mypy`, or scripts in `[tool.poetry.scripts]` / `scripts` in config. |
| **go.mod** (Go) | `go test ./...`, `go build ./...`, or Makefile targets. |
| **Other** | `docker-compose` test services, `justfile`, `Taskfile`, `scripts/` directories, or README/contributing docs that say "before committing run X". |

### 3.2 How to discover

1. **List likely files:** Look for `Makefile`, `makefile`, `package.json`, `pyproject.toml`, `Cargo.toml`, `*.cabal`, `go.mod`, and directories like `.github/workflows`, `scripts/`.
2. **Read the config:** Open the relevant file and find script names or commands (e.g. `npm run test`, `make test`, steps in a GitHub Actions job).
3. **Run the commands** that match your change (e.g. full test suite, linter, formatter check). If the project has a single "check everything" target (e.g. `make ci` or `npm run ci`), prefer that when in doubt.

### 3.3 If nothing obvious exists

- Look for a **CONTRIBUTING.md** or **README** section that says what to run before submitting.
- If you truly find no tests or lint config, you can commit without running checks, but prefer adding a note in the commit body (e.g. "No project test/lint config found").

---

## 4. Workflow summary

1. **Make your code/docs changes.**
2. **Discover checks:** Inspect Makefile, package.json, .github/workflows, cabal, etc., and identify test/lint/build commands.
3. **Run the relevant checks** and fix failures before committing.
4. **Commit** with a conventional-commit message (subject + optional body with bullets). One logical change per commit.
5. In a **jj** repo: use **skill-jujutsu.md** for `jj new`, `jj bookmark set`, and `jj git push`. In a **git** repo: use `git add` and `git commit` (and optionally `git push` when appropriate).

---

## 5. Quick reference

| Step | Action |
|------|--------|
| Message format | `type(scope): short imperative subject`; optional body with bullet points. |
| Commit size | One logical change per commit; multiple files OK if they belong together. |
| Before commit | Find and run project checks (Makefile, npm scripts, CI, cabal, cargo, etc.). |
| Discover commands | Check Makefile, package.json, .github/workflows, cabal, Cargo.toml, pyproject, README/CONTRIBUTING. |
| jj mechanics | See **skill-jujutsu.md** for creating changes, bookmarks, and push. |
