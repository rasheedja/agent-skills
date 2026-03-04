# Skill: Use gh CLI/API to read PR review comments and reply in threads

This skill covers how to list pull request review comments, inspect a specific comment, and post a reply in the same thread using the GitHub CLI (`gh`) and REST API. It does not cover review strategy or what to write—only the mechanics.

**Prerequisites:** `gh` installed and authenticated (`gh auth status`). Repo access must allow reading and (for replies) writing comments.

---

## 1. Get PR overview and high-level review summary

```bash
gh pr view <PR_NUMBER> --repo <OWNER/REPO> --comments
```

- Shows PR title, body, and a summary of review activity (e.g. “Reviewed changes”, “X comments”).
- Does **not** list individual review comment bodies or thread IDs.

**Example:** `gh pr view 29 --repo realfi-co/dagster-orchestration --comments`

---

## 2. List all review comments on a PR (REST API)

Review comments are comments on lines of the diff. They are not the same as issue comments (general PR comments).

```bash
gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/comments
```

- Returns JSON array of review comment objects.
- Each object includes: `id`, `body`, `user`, `path`, `line`, `commit_id`, `created_at`, `html_url`, `in_reply_to_id` (if it’s a reply).

**Useful jq to find comment IDs and bodies:**

```bash
gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/comments --jq '.[] | {id, body: .body[0:120], user: .user.login, path}'
```

**Example:** `gh api repos/realfi-co/dagster-orchestration/pulls/29/comments`

---

## 3. Get one review comment (e.g. for node_id or full body)

```bash
gh api repos/<OWNER>/<REPO>/pulls/comments/<COMMENT_ID>
```

- `<COMMENT_ID>` is the numeric `id` from step 2 (e.g. `2884959903`).
- Response includes `node_id` (for GraphQL if needed), `body`, `in_reply_to_id`, `path`, `line`, etc.

**Example:** `gh api repos/realfi-co/dagster-orchestration/pulls/comments/2884959903 --jq '.node_id'`

---

## 4. Reply to a review comment (REST API — recommended)

To add a reply in the same thread, create a **new** review comment and set `in_reply_to` to the parent comment’s numeric `id`.

**Endpoint:** `POST repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/comments`

**Body (JSON):**

- `body` (string, required): Markdown text of the reply.
- `in_reply_to` (integer, required): The `id` of the comment you are replying to (from step 2 or 3).

**Using gh with stdin:**

```bash
gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/comments -X POST --input - <<'JSON'
{
  "body": "Your reply text here. **Comment left by Cursor**\n\n...",
  "in_reply_to": <PARENT_COMMENT_ID>
}
JSON
```

- Replace `<PARENT_COMMENT_ID>` with the numeric id (e.g. `2884959903`). No quotes around the number.
- Newlines in the body: use `\n`. Escape internal double quotes in the body as `\"`.

**Example (single-line body for simplicity):**

```bash
gh api repos/realfi-co/dagster-orchestration/pulls/29/comments -X POST -f body="**Comment left by Cursor**\n\nDone. Refactored to use Polars map_elements..." -f in_reply_to=2884959903
```

- For long or multi-line bodies, `--input -` with a heredoc is easier than `-f body=...`.
- **Important:** `in_reply_to` must be a JSON **integer** (no quotes). Using a string (e.g. `-f in_reply_to=2885163581` where the API parses it as string) can cause 422; use a JSON body with numeric `in_reply_to` (e.g. `--input -` and heredoc) to be safe.

**Success:** Response includes the new comment’s `id`, `html_url`, and `in_reply_to_id` equal to the parent. The reply appears in the same thread on the PR.

---

## 5. Resolve a review thread (after replying)

Once you’ve addressed a comment (replied and/or made a code change), **resolve the thread** so it no longer appears as “unresolved” on the PR. Use the GraphQL API; the REST API does not expose thread resolution.

**Get thread IDs and resolution status:**

```bash
gh api graphql -f query='
query {
  repository(owner: "<OWNER>", name: "<REPO>") {
    pullRequest(number: <PR_NUMBER>) {
      reviewThreads(first: 50) {
        nodes {
          id
          isResolved
          comments(first: 1) { nodes { id databaseId } }
        }
      }
    }
  }
}
'
```

- Replace `<OWNER>`, `<REPO>`, `<PR_NUMBER>` (e.g. `realfi-co`, `dagster-orchestration`, `29`).
- Each `id` is the thread’s GraphQL node ID (e.g. `PRRT_kwDO...`). Use it to resolve that thread.
- `isResolved`: `true` = already resolved; `false` = still open. Only unresolved threads need resolving after you reply.

**Resolve one thread:**

```bash
gh api graphql -f query='
mutation {
  resolveReviewThread(input: { threadId: "<THREAD_ID>" }) {
    thread { id isResolved }
  }
}
'
```

- Replace `<THREAD_ID>` with the thread’s `id` from the query above (e.g. `PRRT_kwDOQwtH1M5yHxyB`).
- **Note:** The mutation is `resolveReviewThread`, not `resolvePullRequestReviewThread`.

**Workflow:** After you post a reply to a comment, find that comment’s thread (e.g. match by comment `databaseId` or by path/line from the list), then call `resolveReviewThread` with that thread’s `id`.

---

## 6. Reply via GraphQL (alternative; may have different permissions)

You can reply with the GraphQL mutation `addPullRequestReviewComment` and `inReplyTo` (comment’s `node_id`). The comment’s `node_id` comes from step 3 (e.g. `PRRC_kwDO...`).

```bash
gh api graphql -f query='
mutation {
  addPullRequestReviewComment(input: {
    body: "Your reply text.",
    inReplyTo: "<COMMENT_NODE_ID>"
  }) {
    comment { id body }
  }
}
'
```

- Replace `<COMMENT_NODE_ID>` with the string `node_id` from the comment (e.g. `"PRRC_kwDOQwtH1M6r9P6f"`).
- If you get a permissions error (e.g. “does not have the correct permissions to execute AddPullRequestReviewComment”), use the REST method in step 4 instead; it often works when GraphQL does not.

---

## 7. Add a general PR (issue) comment

To add a comment to the PR that is **not** in a review thread (e.g. a general update):

```bash
gh pr comment <PR_NUMBER> --repo <OWNER/REPO> --body "Your comment text."
```

- This creates an issue comment on the PR, not a review comment. It will not appear as a reply inside a review thread.

---

## Checklist: “Address review comments and reply in thread”

1. **List review comments:**  
   `gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/comments`  
   (optionally with `--jq` to get `id`, `body`, `path`, `user`).

2. **Identify the comment to reply to:**  
   Note its numeric `id` from the list (or from the PR URL: `#discussion_r<ID>`).

3. **Optional — get full comment or node_id:**  
   `gh api repos/<OWNER>/<REPO>/pulls/comments/<COMMENT_ID>`  
   if you need `node_id` or full `body`.

4. **Post the reply:**  
   `gh api repos/<OWNER>/<REPO>/pulls/<PR_NUMBER>/comments -X POST`  
   with JSON body `{"body": "...", "in_reply_to": <PARENT_ID>}`  
   (e.g. via `--input -` and a heredoc, or `-f body=...` and `-f in_reply_to=...`).

5. **Resolve the thread** (optional but recommended):  
   Use §5 to get the thread `id` for the comment you replied to, then call `resolveReviewThread` so the thread is marked resolved.

6. **Confirm:**  
   Response includes `html_url` for the new comment; open it to verify the reply is in the correct thread.

---

## Reference: key REST endpoints

| Action                 | Method | Endpoint                                                                 |
|------------------------|--------|--------------------------------------------------------------------------|
| List PR review comments| GET    | `repos/<OWNER>/<REPO>/pulls/<PR>/comments`                              |
| Get one review comment| GET    | `repos/<OWNER>/<REPO>/pulls/comments/<COMMENT_ID>`                      |
| Create review comment  | POST   | `repos/<OWNER>/<REPO>/pulls/<PR>/comments` with `body` and `in_reply_to` (integer) |
| Resolve review thread  | GraphQL| `resolveReviewThread(input: { threadId: "<THREAD_ID>" })` — get thread IDs via `repository.pullRequest.reviewThreads` |

All REST via: `gh api <ENDPOINT>` (add `-X POST` and body for create). Thread resolution via `gh api graphql`.
