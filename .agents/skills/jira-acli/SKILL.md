---
name: jira-acli
description: "Use Atlassian CLI for Jira authentication, JQL searches, reading issues, and authorized issue creation or linking."
---

# Skill: Talk to Jira via Atlassian CLI (acli)

This skill covers how to query and inspect Jira Cloud using the Atlassian CLI (`acli`): authentication, searching work items with JQL, viewing issue details, listing comments, creating work items (Epic, Story, Task) with parent, and creating "Blocks" links with the correct direction. It does not cover Confluence or other Atlassian products—only Jira.

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

`--fields` only accepts some fields. `created`, for example, is refused (`✗ Error: field 'created' is not allowed`). Drop the field, or sort with `ORDER BY` instead. For a full-text search, use `text ~ "term"` in the JQL.

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
acli jira workitem view KEY-599
acli jira workitem view KEY-599 --fields "key,summary,status,updated,comment" --json
```

- To inspect **comments** or **updated** time, include `comment` and `updated` in `--fields`.

---

## 5. Work item comments

```bash
acli jira workitem comment list --key <KEY>                      # List comments on an issue
acli jira workitem comment create --key <KEY> --body "Your text"
acli jira workitem comment create --key <KEY> --body-file comment.json   # plain text or ADF JSON
acli jira workitem comment update --help                         # flags for editing a comment
acli jira workitem comment delete --help
```

- **Rich comments:** write ADF JSON (a `{"type":"doc","version":1,"content":[…]}` with `paragraph`, `bulletList`/`listItem`, `rule`, and `text` nodes carrying `marks` such as `strong`, `em` or `link`) to a file, and pass `--body-file`. Build it with a short script rather than by hand. The tool reports `✓ Comment on work item <KEY> has been successfully added`.
- **acli cannot upload attachments** (`attachment` only has `list` and `delete`), and there is no flag to mention a user. For a comment with images or `@mentions`, upload through the operator's logged-in browser, then post wiki markup through the REST API from that page: `!file.png|width=900!` for images, `[~accountid:<id>]` for mentions, `h3.` headings, `*bold*`, `#` numbered lists. `PUT /rest/api/2/issue/<KEY>/comment/<id>` edits a comment. See [chrome-devtools-browser-driving](../chrome-devtools-browser-driving/SKILL.md) §7–8. Find account IDs in `workitem view <KEY> --json` (`fields.reporter.accountId`, `fields.assignee.accountId`).
- **Reading tickets for an agent:** `acli jira workitem view <KEY> --fields summary,status,assignee,reporter,priority,parent,issuelinks,description,comment,attachment --json`. Then flatten the ADF to text with a small script that marks images as `[IMAGE <alt>]`, so you know which screenshots to fetch.

- **List comments:** Use when you need to see who commented and when (e.g. to find "comments I added today"). The search API does not filter by "commented by currentUser()" in standard JQL, so listing comments per issue is the way to attribute them.

### LLM-attribution sign-off (applies to any tool — acli, MCP Atlassian, web UI, etc.)

**Whenever an LLM posts a Jira comment on a user's behalf, the comment must include an explicit sign-off making the LLM authorship clear.** Jira shows the human's name as the comment author (because the API call is authenticated as the user), which can mislead a reader into thinking the human wrote it. A visible footer prevents that confusion and supports clear audit trails.

Append a footer like this to the bottom of every LLM-posted comment:

```markdown
---

_Comment drafted and posted by Claude Code (LLM agent), invoked by <user's display name>._
```

Substitute the actual model name (e.g. "Claude Code", "Claude Sonnet 4.6", etc.) and the invoking user. The horizontal rule above the line is important — it visually separates the sign-off from the comment body.

This rule applies regardless of which Jira interface the LLM uses (CLI, MCP, REST, browser automation). Reason: the human user has asked for this convention because Jira authorship attribution doesn't distinguish "the human typed this" from "the human's agent typed this," and that distinction matters for stakeholder trust and for replying-to-comment etiquette.

---

## 6. Other useful work item commands

- **Transition (change status):**  
  `acli jira workitem transition --key <KEY> --status "Ready for Testing" --yes`. Confirm afterwards with `workitem view <KEY> --fields status --json`. In delivery workflows, move a ticket only **after** the PR merge is confirmed.
- **Assign:**  
  `acli jira workitem assign <KEY> --assignee <user>`.
- **Edit:**  
  `acli jira workitem edit <KEY>` (interactive or with flags; see `--help`).

---

## 7. Create work items and link them

### Create an issue

```bash
acli jira workitem create --project <PROJECT_KEY> --type <Epic|Story|Task|Bug> --summary "Title" [options]
```

**Common options:**

| Flag | Description |
|------|-------------|
| `--project` | Project key (e.g. `KEY`). Required. |
| `--type` | Issue type: `Epic`, `Story`, `Task`, `Bug`, etc. |
| `--summary` | Short title. |
| `--description` | Body text (plain or ADF). |
| `--description-file` | Path to file with description (plain text). |
| `--parent <KEY>` | Parent issue key (e.g. Epic key for Stories, Story key for sub-tasks if the project allows it). |
| `--label` | Labels (comma-separated). |
| `--assignee @me` | Self-assign. |
| `--json` | Output created issue as JSON (e.g. to get `.key`). |

**Examples:**

```bash
# Epic (no parent)
acli jira workitem create --project KEY --type Epic --summary "My Epic" --description-file desc.txt --json

# Story under an Epic
acli jira workitem create --project KEY --type Story --parent KEY-749 --summary "My Story" --description "Details."

# Task under Epic (some projects allow Task only under Epic, not under Story)
acli jira workitem create --project KEY --type Task --parent KEY-749 --summary "My Task"
```

- Use `acli jira project list --limit 100` to find project keys. Not all projects allow Tasks as children of Stories.

### Create "Blocks" links (dependencies)

Use `acli jira workitem link create` to model "A blocks B" (B cannot be done until A is done).

**Direction:** Jira Cloud's "Blocks" link type can be configured so that either the **inward** or the **outward** issue is the blocker. To get the correct display in the UI ("Blocker blocks Blocked"):

- **If your site shows the INWARD issue as the blocker** (e.g. "is blocked by" points to the prerequisite):  
  Use `--out <BLOCKED> --in <BLOCKER>` so that **BLOCKER** blocks **BLOCKED**.

```bash
# BLOCKER blocks BLOCKED (prerequisite first, dependent second)
acli jira workitem link create --out <blocked_key> --in <blocker_key> --type Blocks --yes
```

- **If your site shows the OUTWARD issue as the blocker**, use `--out <BLOCKER> --in <BLOCKED>` instead.

**Examples (inward = blocker):**

```bash
# Task T blocks Story S
acli jira workitem link create --out KEY-750 --in KEY-756 --type Blocks --yes

# Story 1 blocks Story 2
acli jira workitem link create --out KEY-751 --in KEY-750 --type Blocks --yes
```

**Verify:** After creating a link, open both issues in the Jira UI and confirm the "Blocks" / "is blocked by" text matches intent. If it is reversed, delete the link and recreate with `--out` and `--in` swapped.

### List and delete links

```bash
# List links for an issue (see link ID and linked issue)
acli jira workitem link list --key <KEY>
acli jira workitem link list --key <KEY> --json   # outwardIssueKey / inwardIssueKey

# Delete a link by ID (from link list output)
acli jira workitem link delete --id <LINK_ID> --yes
```

- Available link types: `acli jira workitem link type` (e.g. Blocks, Relates to).

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
| Create issue (Epic/Story/Task) | `acli jira workitem create --project <KEY> --type <Type> --summary "..." [--parent <KEY>]` |
| Create Blocks link (inward = blocker) | `acli jira workitem link create --out <blocked> --in <blocker> --type Blocks --yes` |
| List links on issue | `acli jira workitem link list --key <KEY>` |

For **summarizing what the user did in a day** (completed work, status changes, new issues, comments), use **[jira-daily-summary](../jira-daily-summary/SKILL.md)**. For **team daily updates on a board** (by team member), use **[jira-board-team-daily-summary](../jira-board-team-daily-summary/SKILL.md)**. For **in-progress work on a board** (by team member, excluding Done/Dev Ready and optionally Backlog/To Do), use **[jira-board-in-progress-summary](../jira-board-in-progress-summary/SKILL.md)**.
