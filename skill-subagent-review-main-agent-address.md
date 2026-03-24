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

3. **Main agent makes only the changes** that are justified (correct, in scope for this branch). Use **small, logical commits** and **conventional commit format**; follow **skill-jujutsu.md** (e.g. `jj new`, **`jj new @`** after a commit, **`jj new` + `jj squash`** instead of **`jj edit`** when amending past revisions, `jj split` if splitting one change into multiple commits) and **skill-commits-and-pre-commit-checks.md** (run project checks before committing).

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

## 6. Variant: haiku for mechanical edits, main agent reviews

The loop in §3 has the main agent make all changes. A useful variant for simple, well-scoped edits is to delegate the *implementation* to a **haiku subagent** while the main agent handles review and triage.

**When to use this variant:**
- The change is mechanical and well-defined: adding entries to a list, copying a pattern from one file to another, adding variable declarations following a known naming convention.
- The main agent has already identified exactly what needs to change (from its own review or from user instructions).
- Speed and cost matter — haiku is faster and cheaper for straightforward edits.

**The loop:**

1. **Main agent reviews** the current state and identifies all changes needed.
2. **Spawn a haiku subagent** with precise instructions: exact file paths, exactly what to add/change, where to put it, and which convention to follow (e.g. "follow the naming style of the existing variables in this file"). Explicitly tell it: do NOT run jj/git commands, do NOT commit.
3. **Main agent reviews the result** — read the changed files directly; do not rely on the subagent's summary alone. Check for correctness, consistency with repo conventions, placement, and alignment.
4. If issues found: give a **targeted haiku task** to fix only the specific problems. Triage as in §4.
5. Repeat from step 3 until review passes.

**Key — be precise in haiku instructions.** Vague instructions ("make it consistent") produce inconsistent results. Specific instructions ("add these two variables after the last stage URL variable, following the exact format of the existing ones") work reliably.

**After all haiku edits:** remember that haiku's file edits land in the current jj working copy (`@`). Run `jj squash` to fold them into the bookmark commit before pushing. See **skill-jujutsu.md §13**.

---

## 7. Background agents and Bash permissions

When running a subagent with `run_in_background: true`, it may get blocked if the user's permission settings require approval for Bash commands. Background agents cannot prompt for approval interactively and will stall.

**Signs of blockage:** the agent output shows `Permission to use Bash has been denied` and subsequent tool calls are cancelled.

**Recovery:** the main agent should take over the blocked work directly — run the shell commands itself (jj, git, etc.) rather than re-spawning the background agent. Any file edits the agent completed before the block may still be usable; check the output file for what was done.

---

## 8. Running multiple subagents in parallel

Spawning multiple haiku subagents simultaneously speeds up independent tasks. The main agent must enforce one hard rule before dispatching them:

**No two subagents may edit the same file.**

If two subagents both write to the same file, the second write overwrites the first — silently losing changes. jj/git cannot help here because both agents see the same working copy snapshot; there is no merge.

**How to partition work safely:**

- Assign each subagent a **disjoint set of files**. For example, when adding the same change to three environment accounts, give each subagent one account directory — they never touch the same file.
- If a logical change requires edits to a shared file (e.g. a module or a variables file used by multiple accounts), **handle that file in one subagent** (or in the main agent), not split across subagents.
- When in doubt, **serialise** — run subagents sequentially rather than risk a collision. The speed gain from parallelism is not worth lost edits.

**Checklist before spawning parallel subagents:**

1. List every file each subagent will touch.
2. Confirm the sets are disjoint.
3. If any file appears in more than one set, reassign it to a single subagent or handle it yourself.

**After parallel subagents complete:** run `jj diff --stat` to verify the total set of changed files looks correct, then `jj squash` to fold all edits into the bookmark commit (see **skill-jujutsu.md §13**).

---

## 9. Summary

| Step | Who | Action |
|------|-----|--------|
| Review | Subagent | Perform review; output report and recommendations. |
| Triage | Main agent | Evaluate each comment: accurate? in scope? future work? wrong? |
| Changes | Main agent (or haiku subagent — see §6) | Implement only justified changes; small commits, conventional format (skill-jujutsu, skill-commits-and-pre-commit-checks). |
| Review files | — | **Do not commit**; keep in PR/ticket or delete. |
| Re-review | Subagent | Same scope; confirm no further comments or list remaining issues. |
| Loop | — | Repeat until subagent reports no further comments. |
