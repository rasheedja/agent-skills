# Skill: Address and resolve unresolved PR review comments (single pass)

This skill describes a **single pass** over a PR: (1) check the PR for **unresolved** review comments (threads), (2) address each (e.g. code change and/or reply), (3) resolve each thread. There is **no** re-requesting a reviewer and no “wait for new comments” loop. Use this when you just want to clear all current unresolved comments (from any reviewer), without iterating with Copilot until it says done.

**Prerequisites:** **[skill-gh-pr-review-comments.md](skill-gh-pr-review-comments.md)** (list comments, reply, resolve threads), **[skill-performing-reviews.md](skill-performing-reviews.md)** (evaluate comments, reply content). Optionally **[skill-jujutsu.md](skill-jujutsu.md)** if you want one commit per comment and to include the commit hash in replies.

---

## 1. Get unresolved review threads

- Use the GraphQL query in skill-gh-pr-review-comments.md §5 to list threads and their resolution status:
  ```text
  repository(owner: "<OWNER>", name: "<REPO>") {
    pullRequest(number: <PR_NUMBER>) {
      reviewThreads(first: 50) {
        nodes {
          id
          isResolved
          comments(first: 3) { nodes { id databaseId author { login } body } }
        }
      }
    }
  }
  ```
- Filter to threads where **`isResolved === false`**. Those are the ones to address.
- From each thread, note the **thread `id`** (for resolving later) and the **first comment’s `databaseId`** (for replying: `in_reply_to`).

---

## 2. Address each unresolved comment

- For **each** unresolved thread, decide whether to **change code** or **reply only** (see skill-performing-reviews.md for how to evaluate).
- **If you change code:**
  - Make the change. You can do one commit per comment (skill-jujutsu.md: `jj new`, edit, `jj bookmark set`, `jj git push`, then use `jj log -r @ -T 'commit_id' -n 1` for the hash).
  - Reply in the thread (skill-gh-pr-review-comments.md §4): POST with `body` and `in_reply_to` (parent comment’s numeric id). Include “Comment left by Cursor” (or agent), what you changed, and optionally the commit hash.
- **If you only reply (no code change):** Reply in the same thread with your rationale (e.g. decline or defer); include “Comment left by Cursor” (or agent).
- **Resolve the thread** (skill-gh-pr-review-comments.md §5): GraphQL `resolveReviewThread(input: { threadId: "<THREAD_ID>" })`.

---

## 3. No loop

- Once all unresolved threads are addressed and resolved, you are **done**. This skill does not re-request any reviewer or wait for new comments.
- For the **Copilot-specific loop** (request review → wait for comments → address and resolve → re-request Copilot → repeat until no new comments), use **[skill-pr-review-loop-copilot.md](skill-pr-review-loop-copilot.md)** instead.

---

## 4. Summary

1. Fetch review threads; keep only unresolved (`isResolved === false`).
2. For each: address (code and/or reply) then resolve the thread.
3. Stop when there are no unresolved threads left.

---

## 5. References

- **List/reply/resolve:** skill-gh-pr-review-comments.md (§2, §4, §5).
- **What to write in replies:** skill-performing-reviews.md (§2, §3).
- **One commit per comment (optional):** skill-jujutsu.md.
- **Copilot loop (request → wait → address → repeat):** skill-pr-review-loop-copilot.md.
