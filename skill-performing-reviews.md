# Skill: Performing code reviews and replying to review comments

This skill describes how to evaluate PR review comments critically, decide whether to address them or respond with a rationale, and how to format replies (including identifying the reply as from an agent). For the mechanics of reading comments and posting replies via `gh` CLI/API, use **[skill-gh-pr-review-comments.md](skill-gh-pr-review-comments.md)**. For **addressing unresolved comments** in a single pass (check PR → address and resolve each unresolved thread), use **[skill-pr-review-address-unresolved.md](skill-pr-review-address-unresolved.md)**. For the **GitHub Copilot loop** (request Copilot review → wait for comments → address and resolve → re-request Copilot → repeat until no new comments), use **[skill-pr-review-loop-copilot.md](skill-pr-review-loop-copilot.md)**.

---

## 1. Scope: only unresolved comments

When performing a review pass, **consider only unresolved review comments** (threads that are still open). Resolved threads have already been addressed or acknowledged; skip them so you don’t re-evaluate or duplicate replies. If the API or UI lets you filter by unresolved, use it; otherwise, ignore comments that are part of threads you or someone else has already resolved.

---

## 2. Evaluating comments critically

Review comments are suggestions, not obligations. Evaluate each one before changing code or replying.

### 2.1 Classify the comment

- **Actionable and correct** — The comment identifies a real issue (bug, style violation, missing test, unclear code). Address it: make the change and optionally reply to confirm.
- **Actionable but wrong or incomplete** — The suggestion would hurt the codebase, is based on a misunderstanding, or doesn’t fit the context. Do **not** implement it. Reply explaining why (see §2.2).
- **Non-actionable / noise** — Vague, off-topic, or already fixed. Reply briefly if the author needs a signal, or leave unresolved if that’s acceptable.

### 2.2 Ask yourself

- **Is the premise accurate?** (e.g. “you never use X” — confirm X is actually unused.)
- **Does the suggestion match project norms?** (existing patterns, style, constraints.)
- **What’s the cost/benefit?** (e.g. refactors that add complexity for little gain; scope creep.)
- **Is it out of scope for this PR?** If so, say so and suggest a follow-up ticket or PR.

### 2.3 When you address a comment

- Make the minimal change that satisfies the concern.
- In your reply, state what you changed (or that you addressed it) so the reviewer can verify.

### 2.4 When you don’t address a comment

- Reply in the same thread so the conversation is resolved.
- Be concise and factual: wrong premise, different trade-off, out of scope, or “deferring to follow-up” are all valid.
- Avoid sounding defensive; stick to technical reasons.

---

## 3. Replying to comments

### 3.1 Where to reply

- **In-thread replies** — Use the PR review comment reply flow so your message appears under the original comment. This keeps context and resolution in one place. Use the gh/API steps in **skill-gh-pr-review-comments.md** (list comments, get parent `id`, POST with `in_reply_to`).
- **General PR comment** — Only for broad updates (e.g. “Replied to all three threads”) or when you’re not replying to a specific review comment.

### 3.2 Identifying the reply as from an agent

Include a short, consistent line so readers know the reply was written by an agent (and, if possible, which one).

- **Preferred:** Name the agent, e.g.  
  **`Comment left by Cursor`** or **`Reply by <AgentName>`**  
  Place it at the **start** of the reply (e.g. first line or first bold line) so it’s visible in notifications and collapsed view.
- **If the agent name isn’t available:** Use a generic line such as **`Comment left by agent`** in the same position.
- **Formatting:** One line, bold or otherwise prominent. Example:

  ```text
  **Comment left by Cursor**

  Done. Refactored to use Polars map_elements instead of .to_list()…
  ```

  or

  ```text
  **Comment left by agent**

  We didn’t change this because…
  ```

### 3.3 Reply content by outcome

| Outcome | What to do | What to write (after the “Comment left by…” line) |
|--------|------------|---------------------------------------------------|
| Addressed | Implement the change, then reply. | Briefly state what you changed (file, behavior, or “addressed in latest commit”). |
| Declined (wrong or bad suggestion) | Do not change code. Reply in thread. | Explain why: wrong premise, project convention, trade-off, or scope. Keep it short. |
| Deferred | No change in this PR. | Say you’re not doing it here and suggest a follow-up (ticket, PR, or “we can revisit if…”). |

### 3.4 Tone and length

- Be neutral and professional; avoid “actually” or “obviously.”
- One short paragraph is usually enough. For multiple points, use a list.
- If the comment included a code suggestion you’re not taking, you can quote the relevant part and then give the reason.

---

## 4. End-to-end flow (with gh)

1. **Fetch review comments** — See skill-gh-pr-review-comments.md §2. List comments for the PR and note each comment’s `id` and `body`. **Restrict to unresolved threads** (filter by resolution state if the API or tool supports it).
2. **Evaluate each comment** — Use §2 above: classify, check premise and scope, decide address / decline / defer.
3. **Make code changes** — For comments you’re addressing, apply the minimal change and run tests/lint.
4. **Post in-thread replies** — For each comment you’re replying to (whether you changed code or not), use skill-gh-pr-review-comments.md §4: POST to `repos/…/pulls/<PR>/comments` with `body` and `in_reply_to`. In every reply body, start with **`Comment left by Cursor`** (or **`Comment left by agent`** / **`Reply by <AgentName>`** if the system provides a name).
5. **Resolve the threads** — After replying, resolve each thread you addressed so it no longer shows as “unresolved”. Use skill-gh-pr-review-comments.md §5 (GraphQL: get thread IDs from `reviewThreads`, then `resolveReviewThread`).
6. **Verify** — Open the returned `html_url` (or the PR “Files changed” / “Conversation”) and confirm each reply is in the right thread and threads are resolved.

---

## 5. Summary

- **Only unresolved comments** — Work on open (unresolved) review threads; skip already-resolved ones.
- **Evaluate:** Correct / wrong / out of scope; address only what’s right and in scope.
- **Reply in thread** for every comment you’re responding to; use the gh skill for the API steps.
- **Tag every reply** with a single line such as **`Comment left by Cursor`** or **`Comment left by agent`** (or agent name if available) at the top of the body.
- **Resolve threads** once you’ve replied (and optionally made a code change); see skill-gh-pr-review-comments.md §5.
- **Keep replies short and factual:** what you changed, or why you didn’t, or that you’re deferring.
