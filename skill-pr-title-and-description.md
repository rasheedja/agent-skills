# Skill: Update PR title and description from the changeset

This skill describes how to **examine a PR’s changeset** and then **set the PR title and description** so they accurately summarize the work. Use this when a PR has a placeholder or branch-name-style title and an empty or outdated description, and you want a conventional-commit title plus a clear bullet-point description.

**When to use:** After a feature or fix is done on a PR; before merge or when asked to “summarise the changes” or “update the title and description.”

---

## 1. Examine the changeset

Gather what the PR actually changes so you can summarise it.

**List changed files (and optionally stats):**
```bash
gh pr view <PR_NUMBER> --repo <OWNER/REPO> --json files --jq '.files[] | "\(.path) +\(.additions)/-\(.deletions)"'
```
Or just names:
```bash
gh pr diff <PR_NUMBER> --repo <OWNER/REPO> --name-only
```

**Inspect commit history (headlines and bodies):**
```bash
gh pr view <PR_NUMBER> --repo <OWNER/REPO> --json commits --jq '.commits[] | "\(.messageHeadline)\n\(.messageBody)"'
```

**Optional — full diff for specific areas:**
```bash
gh pr diff <PR_NUMBER> --repo <OWNER/REPO>
```

From this you can identify: new vs modified vs removed files, main themes (e.g. “owner resolution”, “Admin API”, “Cardano address”), and any breaking or notable behaviour.

---

## 2. Choose a conventional-commit style title

- **Format:** `type(scope): short description` (e.g. `feat(rewards-engine): support owner hashes for points (PP12PB-600)`).
- **Type:** Prefer `feat` for new behaviour, `fix` for bug fixes, `refactor` for structural changes, `chore` for tooling/docs/tidy, `docs` for documentation-only.
- **Scope:** Optional; use the main area (repo name, package, or feature) if it helps.
- **Description:** One short line (≈50–72 chars); no period at the end. Include ticket/issue id if the team uses them (e.g. `PP12PB-600`).
- Derive the title from the **overall change**, not every single commit. If the PR is one cohesive feature, one `feat(...)` title is usually enough.

---

## 3. Write the description as bullet points

- **Structure:** A short intro line is optional; then **bullets** that each describe one logical area of change.
- **Content:** Focus on **what** changed and **why** it matters for reviewers (config, API contract, behaviour, errors, tests), not line-by-line diff.
- Use **bold** for terms you want to scan (e.g. **Admin API**, **owner resolution**, **ResolvingDatastore**).
- Mention breaking or subtle behaviour (e.g. “at least one of `walletAddress` or `owner` required”, “fail fast when cutover set but invalid”).

**Example shape:**
```markdown
## Summary

- **Area one:** What was added/changed and how it behaves (e.g. resolution, config, errors).
- **Area two:** API or contract changes; required vs optional params; backward compatibility.
- **Area three:** New packages or deps; validation or security (e.g. max length, HRP check).
- **Spec & tests:** Docs and test coverage added or updated.
```

---

## 4. Apply title and description

```bash
gh pr edit <PR_NUMBER> --repo <OWNER/REPO> --title "type(scope): short description" --body "## Summary

- **Point one:** ...
- **Point two:** ...
"
```

- For multi-line `--body`, use a single string (e.g. in the shell, one quoted block with `\n` for newlines), or pass the body from a file: `gh pr edit ... --body-file pr-body.md`.
- **Check:** Open the PR in the browser or run `gh pr view <PR_NUMBER> --repo <OWNER/REPO>` to confirm the title and description render correctly.

---

## 5. Checklist

1. **Examine:** `gh pr view` (files, commits) and optionally `gh pr diff` to understand the changeset.
2. **Summarise:** One conventional-commit title and 4–8 bullet points that cover the main areas.
3. **Edit:** `gh pr edit <PR_NUMBER> --repo <OWNER/REPO> --title "..." --body "..."`.
4. **Verify:** `gh pr view` or open the PR to confirm.

---

## References

- **Conventional Commits:** [conventionalcommits.org](https://www.conventionalcommits.org/) (types, scope, description).
- **PR commands:** `gh pr view`, `gh pr edit`, `gh pr diff` in the [GitHub CLI manual](https://cli.github.com/manual/gh_pr).
