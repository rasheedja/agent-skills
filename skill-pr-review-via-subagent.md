# Skill: PR review via a dispatched subagent — spin up a reviewer with the right brief

This skill is for the **orchestrating agent** that wants a thorough, independent review of a pull
request and chooses to offload it to a **subagent**. Offloading keeps the review independent (a cold
reader catches what the author rationalised away) and keeps the large diff and review reasoning out
of the main context. Use it after a PR exists — e.g. one you just opened via
**skill-jira-to-pr-via-subagent.md**, or any PR the user points you at.

This skill covers **how to dispatch the reviewer and what to put in its prompt**. It deliberately
does not re-list review criteria — for the substance of a review pass (correctness, idiomatic style,
test coverage), the reviewer should apply **skill-conducting-code-review.md**. For the **iterative
loop** (subagent reviews → main agent triages and fixes → repeat until clean), see
**skill-subagent-review-main-agent-address.md** — this skill is the "spin up the reviewer" half of
that loop. For **posting** the findings as GitHub comments (only if asked), see
**skill-gh-pr-review-comments.md**.

---

## 1. When to use

- The user says "review this PR", "check that PR-123 does what the ticket asked", "give it a careful
  review before I merge", or you've just produced a PR and want a second pair of eyes before handing
  it back.
- Skip the subagent for a tiny diff you can review inline in a few seconds — just review it directly.
  Dispatch a subagent when the diff is non-trivial, when you want an independent verdict, or when you
  want to protect your context.

---

## 2. Gather the review brief first

The subagent starts cold — it has none of your conversation. Collect everything it needs **before**
spawning, because a vague brief produces a shallow review. Gather:

- **The PR identity:** number, repo, branch, and the **base** it merges into. Get the diff command
  the reviewer will run, e.g. `gh pr diff <N> --repo <owner/repo>` or `git diff <base>...<head>`.
- **The intended task:** the ticket / issue / request the PR is meant to implement, **with its
  acceptance criteria**. Paste the actual text — don't make the reviewer guess what "done" means.
  Without this, the reviewer can only check code quality, not whether the right thing was built.
- **Convention sources:** where this repo documents its conventions — `CLAUDE.md` / `AGENTS.md`,
  lint/format configs (eslint, prettier, ruff, golangci-lint…), and the style of neighbouring code.
  Tell the reviewer to read these, not invent its own standards.
- **How to verify:** the build / test / lint commands, and whether the reviewer has the environment
  and credentials to run them. If it can't run them, say so and ask it to reason about coverage
  instead.

---

## 3. Choose the agent and settings

- **Agent type:** use a dedicated review agent if one is registered (e.g. `code-reviewer`); otherwise
  `general-purpose`. A read-only explore agent can read code but typically can't run build/tests, so
  prefer general-purpose when verification matters.
- **Model by difficulty** (the user cares about matching cost to the work):
  - **haiku** — tiny/mechanical diffs, or a pure convention/lint check.
  - **sonnet** — the default for a typical feature/bugfix PR.
  - **opus** — large, subtle, security-sensitive, or high-blast-radius changes (migrations,
    auth, money/on-chain logic, infra/alarms) where a missed bug is expensive.
- **Read-only and side-effect-free:** the reviewer **must not** edit files, run any `jj`/`git` write
  commands, or post comments to GitHub. It reads, reasons, runs read-only checks, and reports.
- **Foreground** by default — you need the verdict before you can triage. Run in background only if
  you have genuinely independent work to do meanwhile.
- **One reviewer, usually.** For a large multi-area PR, dispatch **parallel reviewers** each scoped
  to one area (e.g. backend / frontend / infra) or one **dimension** (correctness, security,
  test-coverage, conventions). Send them in a single message so they run concurrently, and tell each
  what the others cover so they don't all review the same lines.

---

## 4. The reviewer prompt

The prompt must be **self-contained**. Include the brief from §2, the constraints from §3, and an
explicit checklist of what to evaluate. Require the reviewer to:

1. **Confirm the task is actually implemented.** Walk **each acceptance criterion** and map it to the
   code that satisfies it. Call out any criterion that is unmet, partially met, or only *claimed* met
   in the PR description but absent from the diff.
2. **Check correctness.** Bugs, wrong logic, unhandled edge cases, error/empty/failure paths, race
   conditions, off-by-ones — apply **skill-conducting-code-review.md**.
3. **Check best practices & idioms** for the language/framework — not personal taste, but established
   norms (naming, immutability, resource cleanup, async handling, etc.).
4. **Check repo conventions.** Read `CLAUDE.md`/`AGENTS.md` and the lint/format config and
   neighbouring code; flag deviations (structure, naming, import order, error patterns, comment
   style). If the repo requires **evergreen** docs/comments (no "now/previously/rather than"), verify
   that.
5. **Check completeness — "if X changed, what else must change?"** This is the most commonly missed
   class. Did the PR update every part that should move together: tests, docs/README, type
   definitions, config / IaC, dashboards & alarms, **all call sites** of a changed signature,
   DB migrations, changelog, feature flags, generated code? Name anything that should have been
   touched but wasn't.
6. **Check scope & hygiene.** Unrelated changes, leftover debug/console statements, commented-out
   code, TODOs, committed secrets or credentials.
7. **Security basics** where relevant: injection, authz/authn, unsafe deserialization, secrets in
   logs.
8. **Verify.** Run the build/test/lint commands if able and report exactly what passed/failed;
   distinguish **pre-existing** failures from ones this PR introduces. If it can't run them, say so
   explicitly rather than implying success.

Also embed: absolute repo path, the diff command, "do not edit/commit/push/post", and the output
contract from §5.

**Prompt skeleton:**

```
Review PR #<N> in <owner/repo> (branch <head> → <base>). Repo is at <abs path>.

It is meant to implement <TICKET>: <paste summary + acceptance criteria>.

Get the diff with: <diff command>. Read CLAUDE.md/AGENTS.md and the lint config for
conventions. Verify with: <build/test/lint commands> (report what you ran and the result;
separate pre-existing failures from new ones).

Evaluate, in order: (1) does it satisfy each acceptance criterion — map each to code;
(2) correctness/bugs/edge cases; (3) best practices; (4) repo conventions; (5) completeness —
everything that should change together (tests, docs, config/IaC, call sites, migrations…);
(6) scope/hygiene/secrets; (7) security where relevant.

You are READ-ONLY: do not edit files, run any git/jj write commands, or post to GitHub.

Output: <the §5 contract>.
```

---

## 5. Output contract

Require a structured report so you can triage fast:

- **Verdict:** one of `ready to merge` / `changes needed` / `blocked`, plus one sentence why.
- **Acceptance-criteria coverage:** each criterion → `met` / `partial` / `missing`, with the
  file:line that satisfies it (or the gap).
- **Findings, grouped by severity:**
  - **Blocker** — bug, broken/missing requirement, security issue, failing check.
  - **Should-fix** — convention violation, missing test/doc, poor pattern.
  - **Nit** — style/optional.
  Each finding: `file:line`, what's wrong, **why**, and a concrete suggested fix.
- **Missing updates:** parts that should have changed together but didn't (§4.5).
- **Verification results:** commands run and pass/fail, with pre-existing vs new called out.

Severity tagging lets you act on blockers and ignore nits per the user's preferences.

---

## 6. After the review: triage, don't auto-apply

Do **not** blindly apply the reviewer's findings. The **main agent (you)** has the full context —
user preferences, scope, what's deliberately out of scope — so you triage each finding: accurate +
in scope → fix; wrong → discard; out of scope / future work → note but skip. Follow
**skill-subagent-review-main-agent-address.md** for the triage rules and the review→address→re-review
loop. Make the fixes yourself (or via a small follow-up agent for mechanical changes), then re-review
if the changes were substantial. Don't re-run a heavy reviewer for a one-line tweak.

Only post findings to GitHub if the user asked for that — then use
**skill-gh-pr-review-comments.md**.

---

## 7. End-to-end checklist

1. Confirm a PR exists; decide subagent vs inline (§1).
2. Gather the brief: PR id + base, diff command, ticket + acceptance criteria, convention sources,
   verify commands (§2).
3. Pick agent type + model-by-difficulty; read-only; foreground; one reviewer or parallel-by-area
   (§3).
4. Write the self-contained prompt with the evaluation checklist and output contract (§4–§5).
5. Read the report; triage with full context; fix what matters; loop if needed
   (§6, **skill-subagent-review-main-agent-address.md**).

---

## References

| Topic | Skill |
|-------|-------|
| What a review pass evaluates (criteria) | **skill-conducting-code-review.md** |
| Review → triage → fix → re-review loop | **skill-subagent-review-main-agent-address.md** |
| Producing the PR a reviewer then checks | **skill-jira-to-pr-via-subagent.md** |
| Posting findings as PR comments | **skill-gh-pr-review-comments.md** |
| Replying to existing review comments | **skill-performing-reviews.md** |
