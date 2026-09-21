# Skill: Delegated implementation — isolated workspace, orchestrator review, draft PR

Use this workflow when the user wants one agent to orchestrate and review while a separately selected implementor makes the changes. It supports a Jira ticket or another concrete implementation task. For Jira intake and role selection, use [skill-jira-to-pr-via-subagent.md](skill-jira-to-pr-via-subagent.md).

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

Use jj only when the user/project calls for it; then consult [skill-jujutsu.md](skill-jujutsu.md). Do not mix git and jj mutations during one workflow.

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

Distinguish code/test failures from unavailable infrastructure, credentials, or established baseline failures. Fix regressions before delivery. A draft PR may document an unavoidable environment-related validation gap when the code review and available checks support the change; state exactly what ran, what did not, and what must be validated before merge. Stop if the missing evidence prevents a responsible assessment of the change. Follow [skill-commits-and-pre-commit-checks.md](skill-commits-and-pre-commit-checks.md).

## 6. Commit and deliver the draft PR

Once review passes, inspect the final diff and working tree. Exclude scratch plans, review reports, dependencies, and unrelated changes. Commit with the repository's conventions. Respect hooks; inspect any hook-generated changes and return product-file changes to the implementor for review and any needed corrections before publishing. Repeat verification if the changes affect its conclusions.

Push only the feature branch. Create the draft PR against the actual base (the parent branch for a stack), with a description of the problem, resulting behavior, verification, compatibility, and material limitations. Prefer a body file or structured tool argument to preserve Markdown accurately:

```bash
gh pr create --draft --repo <owner/repo> --base <base> --head <branch> \
  --title '<title>' --body-file <scratch-pr-body-path>
```

Verify the resulting PR URL, draft status, base branch, and head commit against the reviewed work. Confirm the worktree is clean and preserve it for follow-up. Return the PR link, ticket link when applicable, and concise verification status. Do not merge, deploy, request extra external reviews, or post unrelated messages as part of this workflow.
