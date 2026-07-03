# Skill: Jira ticket → draft PR, orchestrated via the subagent workspace flow

This skill is the end-to-end orchestration for "take a Jira ticket, hand it off to an Opus subagent, and come back with a draft PR." It doesn't describe the implementation mechanics itself — for that, it **delegates to skill-opus-subagent-workspace-flow.md**. Use this skill when the user asks something like *"pick up TICKET-123 and work on it in the background"* or *"spin up a subagent on TICKET-456 and open a draft PR"*.

If the user wants you to implement the ticket yourself (no subagent), use **skill-jira-story-to-pr-workflow.md** instead — that's the direct-implementation flow.

**Prerequisites:**

- **skill-jira-acli.md** or an equivalent Jira tool (MCP Atlassian tools, `acli`, etc.) — fetching the ticket, reading its status, transitioning it.
- **skill-opus-subagent-workspace-flow.md** — the core implementation flow this skill delegates to.
- **skill-jira-story-to-pr-workflow.md** §§1–4 — the "read, evaluate, transition" front half is the same; this skill reuses those steps.
- **skill-commits-and-pre-commit-checks.md** — conventional commits, project checks.
- **skill-pr-title-and-description.md** — PR title/body conventions.

**Output contract:** when the flow terminates, your reply to the user **must include both** the Jira ticket link and the draft PR URL.

---

## 1. Get the ticket

The user will give you a ticket key (e.g. `PROJ-123`) or a Jira URL. Fetch the ticket's:

- **Summary** and **description** (requirements, acceptance criteria).
- **Status** (so you know what transition is needed).
- **Comments** (often contain clarifying context or constraints).
- **Linked tickets** (blockers, parents — relevant if this is a stacked PR).

Use the project's Jira integration — MCP Atlassian tools if available, otherwise `acli jira workitem view` (see **skill-jira-acli.md**). For ADF-rich descriptions, request markdown or ADF as appropriate.

---

## 2. Understand and evaluate it

Before touching any code, decide whether the ticket is **actionable**.

- **Clarity:** requirements and acceptance criteria specific enough to implement? If vague or contradictory, either ask the user or note the gaps in your evaluation.
- **Scope:** one logical change (one PR), or should it be split? Prefer one ticket → one PR.
- **Dependencies:** any blockers? If the ticket depends on another in-flight PR, plan to stack (see **skill-opus-subagent-workspace-flow.md §2**). If it's truly blocked, stop and report to the user.
- **Feasibility:** quickly map the ticket to the codebase. Identify the files/modules the change should touch. If the target is unclear, grep/search before committing to a plan — a subagent can't compensate for a vague brief.

**Produce a short assessment** (one paragraph) you can either report to the user or paste into your plan file later. Include: the summary, the scope decision, any risks, and "ready to implement" or "needs clarification on X".

If the ticket isn't ready, **stop here and report back**. Don't spawn a subagent on ambiguous work.

---

## 3. Transition the ticket to In Progress

Once you've decided to proceed, move the ticket to the project's "in progress" equivalent (names vary: "In Progress", "In Development", "Dev in Progress"). Fetch the available transitions, pick the right one, apply it.

Optionally assign the ticket to the current user.

---

## 4. Hand off to the subagent workspace flow

From here, **follow skill-opus-subagent-workspace-flow.md end-to-end.** Don't re-describe those steps; execute them. In summary:

1. Choose VCS: a **git worktree by default** (incl. colocated jj repos); a jj workspace only if the project specifically uses jj.
2. Create the isolated workspace (`git worktree add` — or `jj workspace add` for jj-preferred projects).
3. Create the bookmark/branch (standalone on `main` or stacked on the parent).
4. Write `PLAN-<TICKET>.md` in the workspace root. The plan should:
   - Restate the goal (from your §2 assessment).
   - List the files to edit with absolute paths.
   - Break work into ordered steps.
   - Call out "Out of scope" items so the subagent doesn't drift.
   - Specify verification commands (build, tests, lint).
5. Spawn the Opus subagent with a self-contained prompt (scope, workspace lock, no VCS, plan path, report format).
6. On return: review the diff directly, triage, run project checks.
7. Move the plan out of the workspace to `/tmp/claude/<TICKET>/`.
8. Commit, push the bookmark/branch, and open the draft PR with `gh pr create --draft`.
9. Leave the workspace clean (`jj new @` for jj; nothing needed for git).

Refer to **skill-opus-subagent-workspace-flow.md** for the exact commands in each step.

---

## 5. Report to the user

Your final reply **must** contain, at minimum:

- **Ticket:** its key and URL (e.g. `PROJ-123: https://<site>.atlassian.net/browse/PROJ-123`).
- **Draft PR:** its URL (e.g. `https://github.com/<owner>/<repo>/pull/<num>`).
- **What the subagent did** (one or two bullets summarising the diff — files touched, key decisions).
- **Verification status** (did the build/tests pass? any known deviations from the plan?).

Keep it terse. The user wants the two links first; everything else is supporting detail.

**Example reply shape:**

```
Launched subagent on PROJ-123. Done.

- Ticket: https://acme.atlassian.net/browse/PROJ-123
- Draft PR: https://github.com/acme/widgets/pull/482

Subagent changes:
- Edited `src/foo.go` to add the new field; updated two call sites.
- Added a test in `src/foo_test.go` covering the new branch.

Verification: `go build ./...` and `go test ./...` both green.
```

---

## 6. End-to-end checklist

1. Fetch the ticket (summary, description, status, comments, links).
2. Evaluate: clear, unblocked, single-PR scope, feasible? If not, stop and report.
3. Transition to "In Progress" / "In Development" (or whatever your board calls it).
4. Delegate the rest to **skill-opus-subagent-workspace-flow.md**:
   - Workspace, branch/bookmark, plan, subagent, review, commit, push, draft PR.
5. Reply to the user with **both** the ticket link and the draft PR URL, plus a short summary.

---

## References

| Topic | Skill |
|-------|-------|
| Ticket fetch, transition, conventions | **skill-jira-acli.md**, **skill-jira-story-to-pr-workflow.md** |
| Workspace, subagent delegation, push, draft PR | **skill-opus-subagent-workspace-flow.md** |
| Conventional commits, pre-commit checks | **skill-commits-and-pre-commit-checks.md** |
| PR title/description format | **skill-pr-title-and-description.md** |
| Subagent review loop, parallel subagents, background-agent stall | **skill-subagent-review-main-agent-address.md** |
