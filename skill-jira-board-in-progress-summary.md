# Skill: In-progress work on a Jira board — by team member

This skill describes how to produce a summary of **all work currently in progress** on a Jira board: issues that are neither Done nor Dev Ready (and optionally excluding Backlog and To Do), **grouped by assignee**. Use when the user asks for "in progress work on the board" or "what’s in progress, by team member" (optionally "without backlog").

**Prerequisites:** **[skill-jira-acli.md](skill-jira-acli.md)** — `acli` authenticated and JQL search.

---

## 1. Scope

- **Board** — Identified by Jira **project** key. Use `acli jira board search` to find the board and its project key (see **[skill-jira-board-team-daily-summary.md](skill-jira-board-team-daily-summary.md)** §2).
- **In progress** — Issues whose status is **not** Done and **not** Dev Ready. Optionally also exclude Backlog, To Do, and Archived so the summary focuses on active work (Dev Review, In Development, In Progress, Product Delivery, Analysis, Experiment, Testing/QA, Ready for Testing, Ready to Build, Research, etc.).
- **Output** — One section per assignee (and "Unassigned"), with issues grouped by status within each.

---

## 2. Find the board and project key

```bash
acli jira board search
acli jira board search "<board name or keyword>"
```

From the **Link** column, take the project key and use it in JQL as `project = <KEY>`.

---

## 3. Query: in progress only (exclude Done and Dev Ready)

Replace `<KEY>` with the board’s project key.

**All in-progress issues (including Backlog and To Do):**

```bash
acli jira workitem search --jql 'project = <KEY> AND status != Done AND status != "Dev Ready" ORDER BY assignee, status' --limit 500 --csv
```

**Active in-progress only (exclude Backlog, To Do, Archived):**

```bash
acli jira workitem search --jql 'project = <KEY> AND status != Done AND status != "Dev Ready" AND status != Archived AND status != Backlog AND status != "To Do" ORDER BY assignee, status' --limit 500 --csv
```

- Use `--json` if you need to parse programmatically. CSV is easy to group by Assignee and Status.
- Treat empty Assignee as **Unassigned**.

---

## 4. How to present the summary

- **Group by assignee** — One subsection per assignee (and Unassigned), sorted e.g. alphabetically with Unassigned last.
- **Within each assignee** — Group by **status**. Order statuses in a sensible flow, for example:
  - Dev Review → In Development → In Progress → Product Delivery → Analysis in Review → Analysis in Progress → Experiment → Testing / QA → Ready for Testing → Ready to Build → Research
- **Each line** — `KEY — Summary` (optionally with status in the heading for that group).
- For long lists, you can cap the number of items per status and add "... and N more" if needed.

---

## 5. Checklist

1. **Auth:** `acli auth status` (and `acli auth login` if needed).
2. **Board:** Resolve board name to project key via `acli jira board search`.
3. **JQL:** Use `project = <KEY> AND status != Done AND status != "Dev Ready"`; add `AND status != Backlog AND status != "To Do" AND status != Archived` for "active only".
4. **Run search** with `--limit` (e.g. 500) and `--csv` or `--json`.
5. **Group by assignee**, then by status; format as sections and bullet lists.
6. **Output:** Clear headings per person, status subheadings, and key — summary per issue.

---

## 6. Optional: status list for filtering

If your board uses different status names, adjust the JQL. Typical "in progress" statuses (not Done, not Dev Ready) include:

- Dev Review, In Development, In Progress  
- Product Delivery, Analysis in Review, Analysis in Progress  
- Experiment, Testing / QA, Ready for Testing, Ready to Build  
- Research  
- Backlog, To Do (exclude these for "active only")  
- Archived (often excluded so the summary is only active work)

For acli and JQL details, see **[skill-jira-acli.md](skill-jira-acli.md)**. For daily team updates on the same board, see **[skill-jira-board-team-daily-summary.md](skill-jira-board-team-daily-summary.md)**.
