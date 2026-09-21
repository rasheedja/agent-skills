---
name: jira-to-pr-review
description: "Take a Jira ticket through investigation, planning, delegated implementation, orchestrator review and corrections, verification, and draft PR delivery. Honor user-selected orchestrator and implementor models and reasoning settings."
---

# Skill: Jira-to-PR review — orchestrate implementation, review, and deliver a draft PR

Use this skill for “Jira to PR review”, “Jira GitHub to PR review”, or “jira-to-pr-review”: take a Jira ticket through investigation, a remediation plan, delegated implementation, orchestrator review, corrections, verification, and a draft PR. The ticket key or URL and the implementor selection are enough; the user need not repeat the workflow.

Example: **“Use $jira-to-pr-review for WTB-2274 with you as the orchestrator and Luna High as the implementor.”** The roles are configurable; this example does not establish a default model.

For direct implementation without a separate implementor, use [jira-story-to-pr-workflow](../jira-story-to-pr-workflow/SKILL.md). This workflow does not use the reverse arrangement in which a subagent reviews and the main agent makes the fixes.

## 1. Resolve roles and scope

- **Orchestrator:** the current agent unless the user specifies another available agent. Owns investigation, planning, delegation, direct review, verification, VCS operations, and PR delivery. If another agent is named, actually hand orchestration to that agent using the available runtime; do not merely relabel the current agent.
- **Implementor:** the agent/model and reasoning level selected by the user, or already established for this task. Makes all implementation changes, including tests, documentation, generated files, and review corrections. Do not silently switch models or make product-code fixes as the orchestrator.
- Resolve shorthand such as “Luna High” against the runtime's available model identifiers and reasoning settings, and explicitly apply both when creating an implementor session or its replacement. Continue correction rounds in that configured session when the runtime preserves its settings; a continuation tool need not expose model fields. Verify the session choice rather than assuming inherited defaults are right. Ask a concise question if the implementor is unspecified, unavailable, or ambiguous; investigate independently while awaiting the answer, but do not dispatch to a substitute.
- Use native subagents or equivalent delegated execution, not unrelated user-visible tasks. If the requested roles cannot be supported, explain the limitation and ask for an alternative.
- Invocation requests the whole workflow through a draft PR. Do not insert routine approval checkpoints for planning, worktree creation, corrections, committing, pushing, or draft creation. Ask only for material unresolved intent, unavailable role choices, or an actual permission requirement. Honor Plan mode or other execution restrictions: a skill cannot override them.

## 2. Read the ticket and investigate current code

Fetch the summary, description, acceptance criteria, status, comments, and relevant linked issues. Prefer the connected Jira tools; use [jira-acli](../jira-acli/SKILL.md) only when CLI mechanics are needed.

Locate the repository, read its instructions, and compare the ticket against current upstream code before designing the change. An audit's historical description may no longer match the implementation. Trace affected callers, duplicated clients, data access, generated bindings, and relevant tests. Resolve discoverable facts through inspection; ask about product decisions that cannot be inferred safely.

Produce a concise assessment of the issue, present behavior, intended outcome, scope, and meaningful compatibility risks. Check whether linked blockers really prevent progress; do not abandon independent work just because an issue has a blocked label. When proceeding, transition the ticket to its actual in-progress equivalent if needed, using the available transition list. Leave an already-in-progress ticket alone; do not assign it or post comments unless requested.

## 3. Plan and execute the delegated workflow

Follow [delegated-implementation-review](../delegated-implementation-review/SKILL.md). In particular:

1. Create a dedicated worktree from freshly fetched upstream (or the explicit parent for a stacked PR), preserving the original checkout.
2. Plan the behavior change, compatibility, ownership, and verification before implementation. Retain the plan as scratch material outside the product commit.
3. Delegate bounded implementation tasks to the chosen implementor. Parallelize only independent work with disjoint file ownership.
4. Review the actual diff and verification evidence. Return actionable findings to the responsible implementor, then review the corrections. Repeat until no actionable in-scope findings remain.
5. Run the relevant final checks, resolve fixable environment problems, and distinguish passing checks from blocked checks.
6. Commit and push the reviewed branch; create and verify a draft PR. Do not merge or deploy as part of this skill.

Read [commits-and-pre-commit-checks](../commits-and-pre-commit-checks/SKILL.md) for repository checks/commits and [pr-title-and-description](../pr-title-and-description/SKILL.md) for PR presentation. Load only references needed for the current step. Their general guidance does not change the role ownership defined here.

## 4. Deliver

Return the **Jira link and draft PR URL first**, followed by a brief description of the change and verification status. Disclose material blocked checks, compatibility changes, or remaining external dependencies; never describe unrun tests as passing. Preserve the worktree for follow-up and confirm it is clean.

If a genuine blocker prevents safe completion, report the concrete blocker, completed work, and smallest missing input or access. Do not claim the review is complete while actionable findings remain.
