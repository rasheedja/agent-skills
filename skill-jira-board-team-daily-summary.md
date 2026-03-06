# Skill: Team daily updates on a Jira board — by team member

This skill describes how to produce a **daily summary of work for the whole team** on a given Jira board: for each team member, list issues assigned to them that were updated today, plus issues created today on the board. Use when the user asks for "what the team did today" or "updates for each team member for the day" on a specific board.

**Prerequisites:** **[skill-jira-acli.md](skill-jira-acli.md)** — `acli` authenticated; **[skill-jira-daily-summary.md](skill-jira-daily-summary.md)** for the per-person presentation pattern (Done, In review/ready, In progress, New work).

---

## 1. Scope

- **Board** — Identify the board (e.g. by name). Boards are tied to a Jira **project**; you query by project key.
- **Today** — All dates use Jira’s clock: `startOfDay()` / `endOfDay()` (server timezone).
- **Output** — One section per assignee (and optionally "Unassigned"), each with work completed (Done), in review/ready, in progress, new work created today, and other updates.

---

## 2. Find the board and project key

To list or search boards and get the project key:

```bash
acli jira board search
acli jira board search "<board name or keyword>"
```

The table shows **Name** and **Link**. The Link column often includes the project key in parentheses; use that key in JQL as `project = <KEY>`.

---

## 3. Queries to run

Use **acli** from skill-jira-acli.md. Replace `<KEY>` with the target board’s project key.

**A. All issues on the board updated today (for grouping by assignee)**

```bash
acli jira workitem search --jql "project = <KEY> AND updated >= startOfDay() ORDER BY assignee, updated DESC" --limit 200 --csv
```

- Use `--json` if you need structured data (e.g. for scripting). CSV is convenient for grouping by Assignee.
- This is the main set: group results by **Assignee** (treat empty assignee as "Unassigned"), then within each assignee group by status as in skill-jira-daily-summary.

**B. All issues on the board created today**

```bash
acli jira workitem search --jql "project = <KEY> AND created >= startOfDay() ORDER BY created DESC" --limit 50 --csv
```

- Use this to mark which issues were **created today** when presenting each assignee’s list (e.g. "Created today" or "created and updated today").
- If an issue appears in both (A) and (B), note that the user both created and had it updated today.

---

## 4. How to present the summary

For **each assignee** (and **Unassigned**):

1. **Work completed (Done)** — From (A), issues assigned to that person with status **Done**.
2. **In review / ready** — From (A), issues in Dev Review, Dev Ready, or similar "ready" states.
3. **In progress** — From (A), issues in In Development, In Progress, etc.
4. **New work** — From (B), issues that assignee **reported** (reporter = that user) created today. If also in (A), say "created and updated today".
5. **Other updates** — Any remaining issues from (A) for that assignee (e.g. Backlog, To Do).

Use a short heading per person (e.g. display name or email). Keep each line to: **KEY — Summary** and optionally status or "(created today)".

At the end, add a one-line wrap-up: total issues updated today, how many in Done, how many created today, and that it’s grouped by team member.

---

## 5. Checklist

1. **Auth:** `acli auth status`; if needed, `acli auth login`.
2. **Board:** Resolve board name to project key (e.g. `acli jira board search "…"`).
3. **Activity:** Run JQL `project = <KEY> AND updated >= startOfDay()` with `--limit` and `--csv` (or `--json`).
4. **Created today:** Run JQL `project = <KEY> AND created >= startOfDay()`.
5. **Group by assignee:** Split (A) by Assignee; use (B) to tag "created today".
6. **Per assignee:** For each group, order by status (Done → In review/ready → In progress → Other) as in skill-jira-daily-summary.
7. **Output:** Write a scannable summary and a one-line wrap-up.

---

## 6. Limitations

- **“Updated”** means the issue was updated today; the change might have been made by someone other than the assignee (e.g. status moved to Done by a reviewer).
- **Timezone** — "Today" is Jira server time; it may not match the user’s local day.

For JQL and acli usage, see **[skill-jira-acli.md](skill-jira-acli.md)**. For the per-person status grouping pattern, see **[skill-jira-daily-summary.md](skill-jira-daily-summary.md)**.
