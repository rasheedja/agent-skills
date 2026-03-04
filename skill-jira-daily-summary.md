# Skill: Summarize my Jira work for the day

This skill describes the **workflow** to produce a daily summary of what the user did in Jira: work completed (moved to Done), status changes, issues created, and optionally important comments. Use this when the user asks for "what I did today" or "my work summary for the day".

**Prerequisites:** **[skill-jira-acli.md](skill-jira-acli.md)** — you need `acli` authenticated and the JQL/search/view commands from that skill.

---

## 1. What to gather

Aim to report:

- **Work completed** — Issues moved to Done (or equivalent “done” status) that the user is assigned to and that were updated today.
- **Status / progress** — Other issues assigned to the user that were updated today (e.g. In Development, Dev Review, Dev Ready), so the summary reflects progress, not only “Done”.
- **New work** — Issues the user **created** today (reporter = currentUser(), created today).
- **Comments (optional)** — Comments the user added today; requires listing comments on relevant issues and filtering by author/date, since JQL does not have “commented by me today”.

All “today” is relative to Jira’s clock (`startOfDay()` / `endOfDay()`).

---

## 2. Queries to run

Use **acli** from skill-jira-acli.md.

**A. Issues assigned to me, updated today (main activity set)**

```bash
acli jira workitem search --jql "assignee = currentUser() AND updated >= startOfDay() ORDER BY updated DESC" --limit 50 --csv
```

- Use `--json` if you need structured data (e.g. `key`, `summary`, `status`, `updated`).
- This set includes: status changes you made, issues you edited, and issues others updated (e.g. moved to Done after your work). Group by status when presenting.

**B. Issues I created today**

```bash
acli jira workitem search --jql "reporter = currentUser() AND created >= startOfDay() ORDER BY created DESC" --limit 20 --json
```

- Merge with (A): if an issue appears in both, note that the user both created and had it updated today.

---

## 3. How to present the summary

1. **Work completed**  
   From (A), list issues whose **current status** is Done (or your instance’s “done” category). Example: “Moved to Done: KEY-123 – Summary.”

2. **In review / ready**  
   From (A), list issues in review or “ready” states (e.g. Dev Review, Dev Ready, QA). Example: “In Dev Review: KEY-456 – Summary.”

3. **In progress**  
   From (A), list issues in “in progress” states (e.g. In Development). Example: “In progress: KEY-789 – Summary.”

4. **New work**  
   From (B), list issues created today. If one also appears in (A), you can say “Created and updated today: KEY-674 – Summary.”

5. **Other updates**  
   Any remaining issues from (A) (e.g. Backlog, To Do) can be a short “Other updates” or “Also updated” line so the day is complete.

6. **Optional: Comments**  
   Standard JQL cannot filter “issues where I commented today.” To include “comments I left”:
   - Take the issue keys from (A) and (B).
   - For each key, run: `acli jira workitem comment list <KEY>` (or view with `--fields "comment"`).
   - Filter comments by current user and today’s date; report brief “Commented on KEY-X: …” if useful.

Keep the summary concise: issue key, summary, and status (or “Created” / “Commented”) are usually enough.

---

## 4. Example summary structure

After running the two queries and optionally comment lists:

```text
## Work completed (Done)
- KEY-634 – ETL Supply Pipeline: Decide on Snowflake Schema
- KEY-593 – Submit Multisig mint transactions using cardano-cli

## In review / ready
- KEY-599 – Tech Debt: Store hash of owners… — Dev Review
- KEY-635 – ETL Supply Pipeline: Send Events to S3 — Dev Review
- KEY-674 – ETL Supply Pipeline: Monitor assets with Dagster — Dev Ready (created today)
- KEY-637 – ETL Supply Pipeline: Transform Raw Snowflake Table — Dev Ready
- KEY-600 – Tech Debt: Points Engine: … — Dev Ready

## In progress
- KEY-633 – Commit Scripts/Instructions for Multisig Mint TX — In Development

## Other updates
- KEY-522 – Tech Debt: DynamoDB timestamps — Backlog
```

Then add a one-line wrap-up (e.g. “9 issues updated today; 2 moved to Done; 1 new issue created.”).

---

## 5. Checklist

1. **Auth:** `acli auth status` — if unauthorized, user must run `acli auth login`.
2. **Activity set:** Run JQL for `assignee = currentUser() AND updated >= startOfDay()` (with limit and `--csv` or `--json`).
3. **Created today:** Run JQL for `reporter = currentUser() AND created >= startOfDay()`.
4. **Group by status:** Done → “Work completed”; review/ready → “In review / ready”; in progress → “In progress”; rest → “Other updates.”
5. **New work:** Add “Created today” for issues from the reporter query; note if same issue was also updated.
6. **Optional:** For “comments I left today,” list comments on those issue keys and filter by user + date.
7. **Output:** Write a short, scannable summary (keys, summaries, statuses) and a one-line wrap-up.

---

## 6. Limitations

- **“Updated” includes any change** — You see issues that were updated today, but not necessarily *by* the user (e.g. someone else moved their issue to Done). The summary is “work on my assigned issues today,” not “changes I personally made.” To get true “changes by me” you’d need Jira’s changelog/activity API and filter by author; acli search does not expose that in the basic response.
- **Comments** — Only way to get “comments I added today” is to list comments per issue and filter by author and date.
- **Time zone** — “Today” is Jira server time (often instance timezone). If the user is in a different timezone, startOfDay() may not match their local “today.”

For the mechanics of acli (JQL, view, comment list), always use **[skill-jira-acli.md](skill-jira-acli.md)**.
