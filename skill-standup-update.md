# Skill: Write a daily standup update from today's GitHub + Jira activity

Use this when the user asks for a standup update ("write me today's standup", "standup update based on my jira and github"). The output is a terse, copy-pasteable summary of what the user actually did today, grouped by project, with `Next` and `Blockers` sections. The user will usually hand you a prior standup as a style reference — match it exactly.

**Prerequisites:**
- **[skill-jira-daily-summary.md](skill-jira-daily-summary.md)** — the JQL queries for "my activity today" live there; don't duplicate them.
- `gh` CLI authenticated as the user (`gh auth status`).
- The user's GitHub username (`gh api user --jq .login`).

---

## 1. Ground rules

- **Match the user's sample style exactly.** If they paste a prior standup, mirror its:
  - bullet / sub-bullet structure,
  - ticket URL format (full `https://<org>.atlassian.net/browse/KEY-123` vs. bare `KEY-123`),
  - PR reference format (`#737` vs. `owner/repo#737` vs. full URL),
  - section headings (`Next`, `Blockers`, `Up next`, etc.),
  - verb tense (past-tense work vs. PR-state verbs like "merged / moved to Dev Review / closed").
- **No fluff.** No "I worked on...", no filler, no commentary, no unasked-for detail. Each bullet names the ticket/PR and the state transition — nothing more.
- **Only today's signal.** A bullet belongs in the `Done` section only if something actually changed today (Jira status transition, PR created / merged / moved out of draft, commit pushed). Ongoing work without a transition today belongs in `Next`, not `Done`.
- **Verify Jira first; flag before writing.** If tickets look out of date vs. the PRs you see, surface it **before** writing the update. Do not silently "correct" the ticket state — flag, let the user decide.

---

## 2. Gather today's activity

Run the queries in parallel — they're independent.

### 2.1 Jira — my activity today

Use **skill-jira-daily-summary.md** §2 (JQL A + B):

- **A:** `assignee = currentUser() AND updated >= startOfDay() ORDER BY updated DESC` — items moved / edited today.
- **B:** `reporter = currentUser() AND created >= startOfDay() ORDER BY created DESC` — items the user created today.

If using the Atlassian MCP instead of acli:

```
mcp__…__searchJiraIssuesUsingJql
  cloudId: <site cloudId>
  jql: assignee = currentUser() AND updated >= startOfDay() ORDER BY updated DESC
  fields: ["summary","status","updated","issuetype"]
  responseContentFormat: markdown
```

### 2.2 GitHub — my PR activity today

```bash
gh search prs --author=<gh-username> --updated=">=YYYY-MM-DD" \
  --json number,title,state,isDraft,repository,updatedAt,createdAt,url --limit 30
```

Replace `YYYY-MM-DD` with today (UTC). Interpret fields:

- `state: "merged"` + `updatedAt` today → merged today.
- `state: "open"`, `isDraft: false`, `createdAt` today → opened today.
- `state: "open"`, `isDraft: false`, `createdAt` earlier → possibly "moved out of draft today" (confirm via `gh pr view <N> --json isDraft,updatedAt`, or check review/event timeline — the search snapshot doesn't tell you *when* a draft flipped).
- `isDraft: true` → WIP; include only if relevant to the day's story.

### 2.3 GitHub — commits today (optional)

Useful if the user pushes to repos that don't surface via PR search, or commits without opening a PR same-day:

```bash
gh search commits --author=<gh-username> --committer-date=">=YYYY-MM-DD" \
  --json sha,repository,commit,url --limit 50
```

### 2.4 GitHub — issue activity today (optional)

```bash
gh search issues --author=<gh-username> --updated=">=YYYY-MM-DD" \
  --json number,title,state,repository,updatedAt,url --limit 30
```

---

## 3. Cross-check for staleness — flag *before* writing

Compare Jira ticket states against the GitHub picture. Typical mismatches worth flagging to the user:

- **PR merged, ticket still `In Development` / `Dev Review`** → ticket should be `Done`.
- **Ticket marked `Done`, but the PR is still open / draft** → one of them is wrong.
- **Ticket `In Development`, but the deliverable has shipped elsewhere** (doc published, Confluence page live, manifest deployed) → status is stale.
- **Yesterday's standup mentioned a ticket; today no movement on it** → genuine no-op, or the user forgot to update.
- **PR titled with a ticket key, but that ticket doesn't appear in today's Jira activity** → ticket may not be linked or not assigned to the user.

Surface these as a short bullet list **before** the standup draft, so the user can fix Jira (or tell you to ignore) before you finalise the update.

---

## 4. Write the update

Mirror the user's sample. A common shape:

```
Standup Update
- <project / initiative>
  - <one line per item, with ticket URL and PR #>
- <another project>
  - <...>

Next
- <concrete next action>
- <...>

Blockers
- <blocker + who/what is owed>
```

Guidelines:

- **Group by project / initiative**, not by ticket type or by Jira epic key. Reuse the bucket names from the prior standup when the work continues; invent new ones only for genuinely new threads.
- **One ticket per bullet** unless two tickets describe a single shippable piece of work (e.g. phase-1 + phase-2 of the same test matrix).
- **State-transition verbs:** "merged", "moved to Dev Review", "closed", "opened", "published", "moved out of draft" — not "worked on", "made progress on".
- **Attach artefacts:** include the ticket URL and the PR number/URL. If the user's sample embeds both (e.g. "#760 for https://…/KEY-123"), do the same.
- **Next:** carry over anything from yesterday's `Next` that didn't land today, **plus** new items surfaced today. Don't silently drop yesterday's carry-overs — the user notices.
- **Blockers:** carry over existing blockers unless the user has signalled they're resolved. Add new blockers that surfaced today. Name who's on the other side of each blocker.

---

## 5. Checklist

1. Read the user's sample standup (if provided). Note bullet style, URL format, section headings, depth.
2. `gh auth status` and pick up the GitHub username.
3. Run Jira JQL A + B (see **skill-jira-daily-summary.md**).
4. Run `gh search prs --author=<user> --updated=">=YYYY-MM-DD"`; run commit/issue searches if useful.
5. Cross-check Jira vs. GitHub and list staleness flags.
6. Wait for / invite the user's reaction to flags if they're non-trivial (optional — depends on signal).
7. Write the update in the user's style, grouped by project, terse. Include `Next` and `Blockers` if the sample has them.

---

## 6. Limitations

- **`updated` is "any change"** in both Jira and GitHub — label edits, comments, and reviewer assignments count. Prefer `state`, `mergedAt`, `createdAt` for real shipping signal.
- **Time zones:**
  - `updated >= startOfDay()` uses Jira server time (usually the instance TZ).
  - `gh search …--updated=">=YYYY-MM-DD"` is UTC.
  - If the user's "today" doesn't line up with either, early-morning or late-evening work may fall into the wrong day. When in doubt, ask.
- **Draft transitions:** `isDraft` in search results is a snapshot, not a transition. To claim "moved out of draft today" you may need `gh pr view <N> --json reviewDecision,isDraft,updatedAt` or to inspect events (`gh api repos/<owner>/<repo>/issues/<N>/events`).
- **Cross-repo commits:** `gh search commits` only surfaces commits in repos visible to the authenticated user. Private forks owned by others won't appear.
- **"Updated" in Jira includes changes made by others** (e.g. someone else moving the user's ticket). The summary is "my assigned tickets that saw activity today", not strictly "changes I personally made" — skill-jira-daily-summary.md §6 has the same caveat.
