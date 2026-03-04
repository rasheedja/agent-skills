# Skill: Talk to Jira via Atlassian CLI (acli)

This skill covers how to query and inspect Jira Cloud using the Atlassian CLI (`acli`): authentication, searching work items with JQL, viewing issue details, and listing comments. It does not cover Confluence or other Atlassian products—only Jira.

**Prerequisites:** `acli` installed (e.g. `brew install atlassian/tap/acli`). You must be logged in: `acli auth login` (OAuth). Check status with `acli auth status`.

---

## 1. Authentication

```bash
acli auth login      # Interactive OAuth; run if not authenticated
acli auth status     # Show whether you're logged in
acli auth logout     # Log out
acli auth switch     # Switch between accounts
```

- If `acli auth status` reports "unauthorized", run `acli auth login` and complete the browser flow before running Jira commands.

---

## 2. Jira command structure

```bash
acli jira --help
```

Main subcommands:

- **jira workitem** — Search, view, edit, transition, comment on issues.
- **jira project** — List/view projects (`acli jira project list`).
- **jira board** / **sprint** / **filter** — Boards, sprints, saved filters.

All Jira work is done under `acli jira workitem` for issues.

---

## 3. Search work items (JQL)

Searches use JQL (Jira Query Language). Results can be paginated, limited, or output as JSON/CSV.

```bash
acli jira workitem search --jql "<JQL>" [options]
```

**Common options:**

| Flag | Description |
|------|-------------|
| `--jql "..."` | JQL query (required unless using `--filter`) |
| `--filter <ID>` | Use a saved filter by ID instead of JQL |
| `--limit <N>` | Max number of results (default varies) |
| `--paginate` | Fetch all pages of results |
| `--count` | Only return the count of matching issues |
| `--fields "a,b,c"` | Comma-separated fields (default: issuetype, key, assignee, priority, status, summary) |
| `--json` | Output raw JSON |
| `--csv` | Output CSV |
| `--web` | Open search in browser |

**Useful JQL patterns:**

- **My issues updated today:**  
  `assignee = currentUser() AND updated >= startOfDay() ORDER BY updated DESC`
- **Issues I created today:**  
  `reporter = currentUser() AND created >= startOfDay() ORDER BY created DESC`
- **My open issues:**  
  `assignee = currentUser() AND status != Done ORDER BY updated DESC`
- **By project:**  
  `project = TEAM ORDER BY updated DESC`
- **Specific issue keys:**  
  `key in (KEY-1, KEY-2)`

**Examples:**

```bash
# Issues assigned to me updated today (compact CSV)
acli jira workitem search --jql "assignee = currentUser() AND updated >= startOfDay() ORDER BY updated DESC" --limit 50 --csv

# Same query, full JSON for scripting
acli jira workitem search --jql "assignee = currentUser() AND updated >= startOfDay() ORDER BY updated DESC" --limit 50 --json

# Count only
acli jira workitem search --jql "assignee = currentUser() AND status != Done" --count
```

- JQL dates: `startOfDay()`, `endOfDay()` are relative to the Jira server/timezone. No explicit date format needed for "today".

---

## 4. View a single work item

```bash
acli jira workitem view <KEY> [options]
```

**Options:**

| Flag | Description |
|------|-------------|
| `--fields "a,b,c"` | Comma-separated fields; default: key, issuetype, summary, status, assignee, description |
| `--fields "*all"` | All fields |
| `--fields "*navigable"` | All navigable fields |
| `--fields "summary,comment"` | Include comments in output |
| `--json` | Output JSON |
| `--web` | Open issue in browser |

**Examples:**

```bash
acli jira workitem view PP12PB-599
acli jira workitem view PP12PB-599 --fields "key,summary,status,updated,comment" --json
```

- To inspect **comments** or **updated** time, include `comment` and `updated` in `--fields`.

---

## 5. Work item comments

```bash
acli jira workitem comment list <KEY>   # List comments on an issue
acli jira workitem comment create <KEY> --comment "Your text"
acli jira workitem comment update <KEY> <COMMENT_ID> --comment "Updated text"
acli jira workitem comment delete <KEY> <COMMENT_ID>
```

- **List comments:** Use when you need to see who commented and when (e.g. to find "comments I added today"). The search API does not filter by "commented by currentUser()" in standard JQL, so listing comments per issue is the way to attribute them.

---

## 6. Other useful work item commands

- **Transition (change status):**  
  `acli jira workitem transition <KEY> --transition "Done"` (or transition name/id).
- **Assign:**  
  `acli jira workitem assign <KEY> --assignee <user>`.
- **Edit:**  
  `acli jira workitem edit <KEY>` (interactive or with flags; see `--help`).

---

## Reference: quick command map

| Goal | Command |
|------|---------|
| Check auth | `acli auth status` |
| My issues updated today | `acli jira workitem search --jql "assignee = currentUser() AND updated >= startOfDay()" --csv` |
| Issues I created today | `acli jira workitem search --jql "reporter = currentUser() AND created >= startOfDay()"` |
| View one issue (with comments) | `acli jira workitem view <KEY> --fields "key,summary,status,updated,comment"` |
| List comments on issue | `acli jira workitem comment list <KEY>` |
| Projects list | `acli jira project list` |

For **summarizing what the user did in a day** (completed work, status changes, new issues, comments), use **[skill-jira-daily-summary.md](skill-jira-daily-summary.md)**.
