---
name: delegated-implementation-review
description: "Delegate implementation to a user-selected agent while an orchestrator plans, reviews, returns corrections, verifies, and delivers a draft PR from an isolated workspace."
---

# Skill: Delegated implementation — isolated workspace, orchestrator review, draft PR

Use this workflow when the user wants one agent to orchestrate and review while a separately selected implementor makes the changes. It supports a Jira ticket or another concrete implementation task. For Jira intake and role selection, use [jira-to-pr-review](../jira-to-pr-review/SKILL.md).

## 1. Role contract

The **orchestrator** plans, coordinates, reads diffs, evaluates tests, handles VCS and PR operations, and decides whether the work meets the task. The **implementor** authors all product changes and corrections. Honor the model and reasoning setting specified for each role throughout the task. If none is supplied for the implementor and none is established in the conversation, ask before delegation. If unavailable, report it instead of falling back silently.

Use the runtime's supported delegation tools and actual model identifiers. This skill does not prescribe a particular provider, model, foreground/background mechanism, or permission-bypass flag. Tool descriptions and higher-priority execution constraints still apply.

## 2. Dedicated workspace and plan

Use a dedicated git worktree by default, including in colocated git/jj repositories. Fetch the remote first and branch from the current upstream default branch; use an explicit feature parent for a stacked PR. Follow the repository's branch convention unless the user supplies a name. Verify the repository, branch, base, and clean starting state. Do not switch or overwrite the user's original checkout. Reuse a worktree only when continuing this same task and after inspecting its state.

For example, after resolving the actual names and paths:

```bash
git fetch origin
git worktree add -b <branch> <dedicated-path> origin/<base>
```

Use jj only when the user/project calls for it; then consult [jujutsu](../jujutsu/SKILL.md). Do not mix git and jj mutations during one workflow.

Record a concrete plan in a scratch location excluded from the product commit. Include the objective, current behavior, intended changes, compatibility and rollout considerations, implementation ownership, out-of-scope work, and appropriate verification commands. Clarify consequential ambiguity; make routine implementation decisions without another permission round. Keep the user informed of material findings and progress.

## 3. Dispatch implementation

Give each implementor a self-contained brief with:

- Goal, requirements, accepted decisions, and plan location/content.
- Absolute workspace path and precise file/subsystem ownership; protect other checkouts and agents' work.
- The selected model/reasoning settings, applied in the actual dispatch configuration.
- Verification expectations and permission to inspect relevant callers and repository instructions.
- No commits, pushes, PR creation, branch switching, or destructive VCS operations. Read-only inspection such as `git diff` is allowed. The orchestrator handles integration and VCS.
- A completion report listing changes, checks run with results, deviations, unresolved issues, and environmental blockers.

Use multiple implementors of the selected model when useful for independent work. Assign each file to one owner; coordinate shared interfaces before conflicting edits. Serialize dependent work. Preserve the chosen role/model settings when continuing or replacing an implementor, and pass prior findings to a replacement.

## 4. Review → feedback → review

Read the changed code and tests directly; do not accept the implementor's summary as proof. Review the integrated changes as well as each owned part:

- Does the change fix the demonstrated behavior without introducing regressions or exceeding scope?
- Are all affected callers, duplicate implementations, interfaces, and generated files consistent?
- Do tests exercise the intended behavior, including real boundary/error cases? Check fixtures and assertions for false positives, rather than judging coverage by test count.
- Are compatibility, access control, operational behavior, and deployment order handled where relevant?

Classify findings as actionable and in scope, already addressed, incorrect, or outside scope. Send only justified changes back to the responsible implementor with the location, failure mode, expected behavior, and needed verification. **Do not fix implementation defects yourself or switch to a cheaper/different model for small edits.** The same ownership applies to tests, formatting fixes, and generated files.

Review the revised diff, verify that each finding is resolved, and check for new regressions. Continue this loop until no actionable in-scope findings remain. Use the same implementor session when available. If a correction repeatedly fails, improve the brief or evidence; if progress requires missing user input/access, report that blocker instead of endlessly retrying or silently changing the role contract.

## 5. Verification and blockers

Discover relevant checks from repository instructions, scripts, and CI. Run focused behavior tests and required checks; broaden verification when integration risk or changes justify it. The orchestrator independently verifies decisive evidence rather than relying solely on reported success.

Resolve routine setup problems within the authorized scope (for example, dependencies, writable caches, or approved local test access). If an implementor cannot run a command, the orchestrator may run that command and return its results; that does not transfer implementation ownership. Never bypass an actual approval denial or disable required checks to manufacture success.

**Run the repository's CI locally before any PR exists** (the "local CI gate"). Read the PR workflows (`.github/workflows/*`, the jobs that trigger on `pull_request`) and run their equivalents locally: lint, type checks, every unit-test entry point the CI uses (including isolated or "solo" suites), builds, bundle-size budgets, the end-to-end projects the PR jobs run (the whole project in one local run, in the background), and the secret scanner with the repository's config. Report each with real counts. A failure here costs nothing; the same failure after the PR is open costs a full CI run.

Distinguish code/test failures from unavailable infrastructure, credentials, or established baseline failures. Fix regressions before delivery. A draft PR may document an unavoidable environment-related validation gap when the code review and available checks support the change; state exactly what ran, what did not, and what must be validated before merge. Stop if the missing evidence prevents a responsible assessment of the change. Follow [commits-and-pre-commit-checks](../commits-and-pre-commit-checks/SKILL.md).

## 6. Commit and deliver the draft PR

**Open the PR only when the work is ready for human review.** Check what the repository's CI triggers on: where PR workflows run on `pull_request` only, pushing a branch without a PR costs no CI minutes, while every push to an open PR re-runs everything (often with a preview deploy). So:

- review rounds, fix rounds and the local CI gate (section 5) all happen before the PR is opened, on local commits;
- open the PR once, wait for its CI, and then request the human review;
- if a known flaky job fails, re-run only that job (`gh run rerun <run> --failed`), never the whole run, and never push an empty commit to restart CI unless the provider lost the event;
- don't open stacked PRs while either branch is still changing; keep the dependent branch local and open it after its base merges, because every merge into a stacked branch re-runs its CI;
- batch pushes: one push per meaningful change, not one per review round.

If screenshots need a running deployment, prefer running the app locally against a shared test backend; use the preview the PR deploys only when local can't reproduce the state.

Once review passes, inspect the final diff and working tree. Exclude scratch plans, review reports, dependencies, and unrelated changes. Commit with the repository's conventions. Respect hooks; inspect any hook-generated changes and return product-file changes to the implementor for review and any needed corrections before publishing. Repeat verification if the changes affect its conclusions.

Push only the feature branch. Create the draft PR against the actual base (the parent branch for a stack), with a description of the problem, resulting behavior, verification, compatibility, and material limitations. Prefer a body file or structured tool argument to preserve Markdown accurately:

```bash
gh pr create --draft --repo <owner/repo> --base <base> --head <branch> \
  --title '<title>' --body-file <scratch-pr-body-path>
```

Verify the resulting PR URL, draft status, base branch, and head commit against the reviewed work. Confirm the worktree is clean and preserve it for follow-up. Return the PR link, ticket link when applicable, and concise verification status. Do not merge, deploy, request extra external reviews, or post unrelated messages as part of this workflow.

## 7. Running many tickets: files, reviewer agents, and rounds

These practices held up across a run of 20+ tickets with pane-hosted implementor and reviewer agents (mechanics: [herdr-agent-orchestration](../herdr-agent-orchestration/SKILL.md)).

- **Everything on disk, per ticket.** Keep `<scratch>/<ticket>/brief.md`, `report.md`, `review-brief.md`, `review.md`, `commit.txt` and `pr.md`. Generate briefs from one template, with shared hard rules and per-ticket decisions, so every agent gets the same rules. Write the reviewer's brief **before** launching the reviewer; a reviewer launched early sat idle for an hour asking where its brief was.
- **Hard rules in every implementor brief:**
  - no git writes;
  - its own Postgres or port if it runs DB tests, stopped afterwards;
  - no real-cloud writes, keys or `.env`;
  - the report must give real numbers for every check, with the type check run **last**;
  - list deviations and open concerns, and **every behaviour change outside the ticket's scope**. A report once called a shared page "unchanged" after a refactor that changed one of its messages; the reviewer caught it, the report didn't.
- **Refactors that share code between pages: move it, don't copy it.** Say so in the brief: extract the logic into one module both callers use, keep caller-specific parts as options or slots, require the existing tests of the original caller to pass with their assertions unedited, and tell the implementor to stop and report if a clean move isn't possible rather than duplicate it. Ask the reviewer to compare the moved code line by line with `git show origin/main:<original file>`; that comparison is what finds the small regressions.
- **A separate reviewer worktree.** Detach it at the commit under review, install dependencies, and make it read-only for the reviewer. Before a PR exists that is a **local** commit: create it from the implementor's branch in the same repository (`git worktree add --detach <path> <branch>`), so no push is needed. Before each re-review, move it to the new commit (`git checkout --detach <branch>`, or `origin/<branch>` once pushed).
- **Move the worktree, then prompt.** Never send the reviewer's prompt in the same parallel batch as the command that moves its worktree or writes its brief; it reads before the move lands and stops, or reviews the old commit.
- **The first line of every review is the reviewed commit** (`git log -1 --format=%h`). Reviewers have reviewed stale heads; reject a review whose first line doesn't match the pushed head.
- **Re-review only after the new commit is in place.** Before a PR, that is the local commit; after, check `git ls-remote origin refs/heads/<branch>` matches the local head first. In the re-review prompt, name the new head, the previous head, and what the delta is meant to fix, and ask the reviewer to confirm no test was weakened.
- **Judge each finding yourself**, including whether a fix introduces a new problem. Two examples:
  - A fix that made one of two complementary figures update live left the other frozen, so they stopped adding up.
  - A fix that hid rows "already handled elsewhere" also hid real rows whenever the data source lagged. The right test was by row id and data freshness (block or version), not by a derived status. Send corrections as numbered items with the expected behaviour and the test that proves it.
- **Ship mechanics:** commit with the repo's hooks on. After the push, update the PR description with a **Review** section (each round: commit, verdict, findings fixed, nits left and why) and the agent sign-off footer. With the local gate, the PR should open with the review already done and CI as the last check; request the human review once CI is green.
- **Watch for drift in long sessions.** Copy durable scripts out of temp folders. Don't change the operator's own checkout: read other branches with `git show origin/main:<path>` or a scratch worktree. If you do switch it by mistake, restore the original branch at once and say so.

## 8. CI failures: read the log before calling it a flake

1. **Find the failing step**, e.g. `gh api repos/<o>/<r>/actions/jobs/<job>/logs`. `gh run view --log-failed` refuses until the whole run completes; the jobs API works as soon as the job ends. Pass `--allow-escape-sequences` and strip ANSI codes.
2. **Count failures and read the first one.** One unhandled error can cascade into hundreds of unrelated failures.
3. **Compare with other branches' recent runs of the same job.** For each branch, record pass/fail and the failure's signature, such as the number of `403`s. A signature that also fails branches that don't touch the code, and is absent from every green run, is environmental.
4. **To exonerate the PR, run the same suite locally on the PR head and on main**, with network access to the external service cut (e.g. a dead `HTTPS_PROXY`). If both pass with no live calls, the PR isn't the cause.
5. **Re-run failed jobs** (`gh run rerun <run> --failed`) a bounded number of times: two is enough. Then ask the operator.
6. **Secret-scan false positives:** rename the identifier that trips the rule. In repos that use commit-pinned fingerprints, also add a commit-pinned `.gitleaksignore` entry for the already-pushed commit; never add a path-wide allowlist.
   - The scanner's log is redacted, so get the findings from its report artifact: `gh api repos/<o>/<r>/actions/runs/<run>/artifacts`, then `gh run download <run> -n <report-name>` into a scratch folder, and read the SARIF (`ruleId`, `artifactLocation.uri`, `region.startLine`, `partialFingerprints.commitSha`).
   - Build each entry (`<sha>:<path>:<rule>:<line>`) from those fields, never from a SHA typed by hand: an abbreviated SHA expanded from memory looks right and silently matches nothing. Check with `git rev-parse <short>` that it's the full SHA.

## 9. Merge and close out (only when the operator says)

1. **Check the head before merging.** Someone else may have pushed (for example the approver adding a fix). Read the new commits and the review that approved them; merging an unread head is not merging what was reviewed.
2. **Merge pinned to that head:** `gh pr merge <n> --squash --match-head-commit <sha>`. Then confirm `state=MERGED` and the merge commit.
   - **Stacked PRs** (a child PR based on its parent's branch): merge the parent first, then retarget the child (`gh pr edit <child> --base main`). After a **squash** merge the child conflicts, because main has the parent as one new commit while the child carries the parent's original commits.
   - Resolve it by merging `origin/main` into the child. For each conflicted file, check whether main's copy is exactly the parent's final copy (`git diff --quiet origin/main origin/<parent-branch> -- <file>`). Where it is, the child's side is the parent plus the child's own changes, so take it (`git checkout --ours <file>`). Where it isn't, someone else changed main: resolve by hand. Rerun the type check and the affected tests, push, and confirm `git diff --stat origin/main HEAD` now shows only the child's changes.
   - Retargeting can clear the child's approval on GitHub. Check `reviewDecision` and the merge state again after CI, and if the repo needs a fresh approval, ask rather than work around it.
3. **Move the ticket only after the merge is confirmed**, to the state the operator uses (e.g. "Ready for Testing").
4. **Clean up** as in the herdr skill: check panes, worktrees and local branches, then remove them. Keep evidence branches that PR descriptions link to.
