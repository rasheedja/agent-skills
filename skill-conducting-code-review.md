# Skill: Conducting a code / PR review pass

This skill describes how to perform a **critical review** of a PR: evaluate correctness, idiomatic style, and test coverage. For **replying to** existing review comments and resolving threads, use **[skill-performing-reviews.md](skill-performing-reviews.md)** and **[skill-gh-pr-review-comments.md](skill-gh-pr-review-comments.md)**.

---

## 1. Scope and output

When asked to "review the PR", "do a review pass", or "critically evaluate the changes":

- **Read the changed code** (diff or current files for the PR branch).
- **Evaluate** correctness, idiomatic style, error handling, and test coverage.
- **Report** findings in a structured way: what looks good, what could be improved, and any bugs or gaps (with file/line or function names where helpful).
- **Do not** post review comments to GitHub unless the user asks you to; the default is to output the review in chat (or in a document they can paste).

If the user wants you to **post** the review as GitHub PR comments, say so and use the gh CLI or API (see skill-gh-pr-review-comments.md) to create a review with comments.

---

## 2. What to evaluate

### 2.1 Correctness and behavior

- **Logic**: Do the changes do what the PR description says? Are edge cases handled (nil, empty, invalid input)?
- **API contract**: Do the API (OpenAPI) and implementation match? Are error messages and status codes consistent?
- **Invariants**: Are there any obvious invariants or preconditions that could be violated (e.g. "exactly one of A or B" actually enforced in code and tests)?

### 2.2 Idiomatic style and structure

- **Language / framework**: Is the code idiomatic for the language and frameworks in use (e.g. Go: error handling, naming, package layout; HTTP: status codes, response bodies)?
- **Duplication**: Is there unnecessary duplication that could be a shared helper or constant?
- **Comments and docs**: Do comments match the current behavior? Are public APIs and parameters documented where it matters?
- **Naming**: Are names clear and consistent with the rest of the codebase?

### 2.3 Error handling

- **Errors**: Are errors wrapped with context where useful? Are sentinel or well-known errors used consistently (e.g. `errors.Is`)?
- **Validation**: Is input validated at the right layer (e.g. handler vs. service)? Are validation error messages safe to return to the client?

### 2.4 Tests

- **Unit tests**: Are new/affected functions covered by unit tests? For each branch or important case (success, validation failure, empty input, invalid input), is there a test?
- **Handler/integration tests**: For API changes, are the new params and error paths (400, etc.) covered by handler or integration tests?
- **Table-driven tests**: Where there are many similar cases, would a table-driven test (e.g. in Go) reduce duplication and make gaps obvious?
- **Assertions**: Do tests assert the right thing (e.g. error message content, response body, status code) and avoid flakiness?

---

## 3. Structure of the review output

Organize the review so the author can act on it easily:

1. **Summary** (1–2 sentences): Overall assessment (e.g. "Looks good; a few small doc and test suggestions.")
2. **What looks good**: Positive points (design, clarity, test coverage, etc.).
3. **Suggestions / improvements**: Non-blocking improvements (comments, naming, small refactors, extra tests).
4. **Issues / must-fix**: Bugs, contract violations, or missing tests that should be fixed before merge.
5. **Optional**: Checklist (e.g. "Consider adding a test for X", "Update comment Y to match behavior").

Keep the tone neutral and factual; avoid "obviously" or "you should have". Prefer "Consider …" or "The comment says X but the code does Y; suggest updating the comment."

---

## 4. When to apply this skill

- User asks for a "review", "review pass", "critical evaluation", or "does this look good?" of a PR or set of changes.
- User asks whether changes are "idiomatic", "adequately tested", or if "unit tests cover all cases".
- Before merging: "review this PR and list any issues."

Do **not** use this skill when the user only wants to **address existing** review comments (use skill-performing-reviews.md and skill-gh-pr-review-comments.md).
