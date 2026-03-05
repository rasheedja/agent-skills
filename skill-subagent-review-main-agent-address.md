# Skill: Subagent review → main agent address (review loop)

This skill describes the workflow where **one subagent performs a code/spec review** and the **main agent addresses the review** (triage and code changes). The loop runs until the subagent reports **no further comments**. Review output files are **not committed** as a general rule.

For **human PR review comments** (e.g. GitHub), see **skill-performing-reviews.md** and **skill-gh-pr-review-comments.md**. For **commit format and jj mechanics** when making changes, see **skill-commits-and-pre-commit-checks.md** and **skill-jujutsu.md**.

---

## 1. Why main agent addresses (not a second subagent)

- **Context:** The main agent has the full conversation: user preferences (“no future work,” “small commits”), branch scope, and what “this PR” is for. That context is needed to decide whether each review comment is accurate, in scope, or future work.
- **Critical evaluation:** The agent that **makes the changes** must triage each comment (see §4). A second subagent would lack user context and is more likely to over-implement (“optional” items) or mis-scope.
- **Single chain of reasoning:** Review → triage → changes stay in one place; the main agent can explain why something was or wasn’t done.

---

## 2. Do not commit review files

- **Review reports** (e.g. `*-review.md`, `*-second-pass-review.md`, or any file the subagent writes that only documents the review) **must not be committed** to the repo, on main or on the feature branch.
- Keep review conclusions in the **PR description**, ticket, or wiki instead. This keeps repo history about product/spec/tests, not process artifacts.
- If a subagent or tool writes a review file to the workspace, **do not** `jj describe` / `git add` that file; leave it untracked or delete it before committing.

---

## 3. The loop: subagent review → main agent address → repeat

Run the following until the **subagent reports no further comments** (or explicitly states the implementation is ready and no changes are required).

1. **Spawn a subagent** to perform the review.
   - Give it a clear scope: what to review (e.g. spec + implementation), and what to assess (completeness, comprehensiveness, correctness).
   - Ask for a **review report** and **actionable recommendations** (specific file/section + suggested change, or “no change”).
   - Optionally instruct the subagent to use **skill-commits-and-pre-commit-checks.md** and **skill-jujutsu.md** if it suggests edits (small commits, conventional format); often the main agent will make the edits instead, so this is optional.

2. **Main agent reads the review output** and triages each recommendation (see §4).

3. **Main agent makes only the changes** that are justified (correct, in scope for this branch). Use **small, logical commits** and **conventional commit format**; follow **skill-jujutsu.md** (e.g. `jj new`, `jj split` if splitting one change into multiple commits) and **skill-commits-and-pre-commit-checks.md** (run project checks before committing).

4. **Do not commit any review file** the subagent may have written (see §2).

5. **Spawn the subagent again** for a **re-review** of the updated code/spec (same scope and criteria). The subagent should confirm that the previous comments have been addressed and report any remaining issues.

6. **Repeat** from step 2 until the subagent’s report states there are **no further comments** or that the implementation is **ready**.

---

## 4. Main agent: critically evaluate each review comment

Before changing code, the main agent must **triage** every recommendation. Do not implement blindly.

- **Accurate and in scope** — The comment is correct and the fix belongs on this branch. **Address it:** make the minimal change, then commit (conventional message, small commit).
- **Inaccurate or wrong** — The reviewer misread the spec/code or the suggestion would worsen things. **Do not implement.** Optionally note in the PR or ticket that the comment was considered and rejected with reason.
- **Out of scope / future work** — The idea is valid but not for this branch (e.g. “add optional test,” “consider doing X later”). **Do not implement** on this branch; treat as backlog or follow-up. Do not commit code for it.
- **Already addressed** — The report might be from an earlier pass; the code was already fixed. **No change**; the next re-review will confirm.

When in doubt, prefer **not** implementing optional or “consider” items unless the user has explicitly asked for them on this branch.

---

## 5. Giving the subagent the right instructions

When spawning the review subagent, include:

- **Paths:** The spec and code paths to review (e.g. `rewards-engine/spec/PP12PB-600-*.md`, `rewards-engine/internal/owner_resolution/`, …).
- **Criteria:** What to check (e.g. completeness, correctness, spec/code alignment, edge cases).
- **Output:** Ask for a concise report and a list of actionable recommendations (with file/location and suggested change or “no change”).
- **Commit style (if the subagent might edit):** Reference **skill-commits-and-pre-commit-checks.md** and **skill-jujutsu.md** so any edits use conventional commits and small logical commits. If the main agent will do all edits, you can omit this.

Do **not** ask the subagent to commit review report files; the main agent enforces “review files not committed” (see §2).

---

## 6. Summary

| Step | Who | Action |
|------|-----|--------|
| Review | Subagent | Perform review; output report and recommendations. |
| Triage | Main agent | Evaluate each comment: accurate? in scope? future work? wrong? |
| Changes | Main agent | Implement only justified changes; small commits, conventional format (skill-jujutsu, skill-commits-and-pre-commit-checks). |
| Review files | — | **Do not commit**; keep in PR/ticket or delete. |
| Re-review | Subagent | Same scope; confirm no further comments or list remaining issues. |
| Loop | — | Repeat until subagent reports no further comments. |
