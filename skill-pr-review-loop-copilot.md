# Skill: GitHub Copilot PR review loop — request review → address comments → repeat until no new comments

This skill describes the **Copilot-specific loop**: (1) request a review from GitHub Copilot, (2) wait for Copilot to finish and produce comments, (3) address each unresolved comment (one commit per comment, push, reply with commit hash, resolve thread), (4) re-request Copilot, (5) repeat until Copilot produces **no new comments**. Use this when you want to iterate with Copilot until it has nothing left to say.

**Autonomous execution:** When running this loop, **do not wait for human interaction**. After requesting a review, poll until Copilot completes (e.g. every 60–90 seconds, 5–7 minutes typical, timeout e.g. 30 minutes). When the review is in, address all new unresolved comments, then **you must re-request Copilot** and poll for the *next* review. **Keep re-requesting** after each round of fixes until Copilot’s next review has **0 comments** (or says “generated no new comments”), or until all of its comments are reply-only (no code change required). Do not stop after addressing comments without re-requesting; the loop is not done until Copilot has run again and produced zero comments or only reply-only comments.

**Prerequisites:** **[skill-gh-pr-review-comments.md](skill-gh-pr-review-comments.md)** (list comments, reply, resolve threads), **[skill-performing-reviews.md](skill-performing-reviews.md)** (evaluate comments, reply content), **[skill-jujutsu.md](skill-jujutsu.md)** (one commit per comment, push, commit hash). For a single-pass “address any unresolved comments” flow without re-requesting Copilot, use **[skill-pr-review-address-unresolved.md](skill-pr-review-address-unresolved.md)** instead.

---

## 1. Request a review from Copilot

```bash
gh pr edit <PR_NUMBER> --repo <OWNER/REPO> --add-reviewer copilot-pull-request-reviewer
```

- Use the reviewer login your repo uses (often `copilot-pull-request-reviewer`).
- This triggers Copilot to run a review on the current PR head.

---

## 2. Wait for Copilot to complete (poll; no human interaction)

- Copilot usually finishes within **5–7 minutes**. **Poll automatically** (e.g. every 60–90 seconds); do not stop and ask the user to check. Use a timeout (e.g. 30 minutes) if Copilot does not submit.
- To see when the latest review landed:
  ```bash
  gh api repos/<OWNER>/<REPO>/pulls/<PR>/reviews --jq '.[] | select(.user.login == "copilot-pull-request-reviewer[bot]") | {id, submitted_at}'
  ```
- To see if Copilot left **any new comments**: fetch review threads (GraphQL `repository.pullRequest.reviewThreads`) and filter `isResolved === false`, or fetch the **latest review body** — Copilot often says “generated no new comments” when it has nothing to add:
  ```bash
  gh api "repos/<OWNER>/<REPO>/pulls/<PR>/reviews/<REVIEW_ID>" --jq '.body'
  ```

---

## 3. Address and resolve each unresolved comment

- Work only on **unresolved** threads (see skill-gh-pr-review-comments.md §5 for the GraphQL query; filter `isResolved === false`).
- For **each** unresolved comment:
  - **If you change code:** One commit per comment: `jj new <branch_bookmark> -m "fix: ..."` → edit → `jj bookmark set <branch> -r @` → `jj git push --branch <branch>` → get hash (`jj log -r @ -T 'commit_id' -n 1`) → reply in thread (include “Comment left by Cursor”, what you changed, and the **commit hash**) → resolve the thread (GraphQL `resolveReviewThread`). See skill-jujutsu.md and skill-gh-pr-review-comments.md.
  - **If you only reply (no code change):** Reply in thread with your rationale, then resolve the thread.
- When all current unresolved threads are addressed and resolved, continue to §4.
- **If posting a reply returns 422** (e.g. “user_id can only have one pending review per pull request”): your user has a pending review on this PR. Delete or submit that review (see skill-gh-pr-review-comments.md §8), then retry the reply.

---

## 4. Re-request Copilot (required after every round), then poll for the next review

- **You must re-request** after addressing comments. Do not skip this step:
  ```bash
  gh pr edit <PR_NUMBER> --repo <OWNER/REPO> --add-reviewer copilot-pull-request-reviewer
  ```
- **Poll until a *new* Copilot review appears** (typically 5–7 minutes). Record the time when you re-requested; keep polling until the latest Copilot review’s `submittedAt` is **after** that time (or until timeout). Do not stop just because the current unresolved count is 0 — wait for the new review.
- **Then** check that new review:
  - If the review body says **“generated no new comments”** (or 0 comments), the loop is **done**.
  - If all new comments can be addressed with **reply-only** (no code change), reply and resolve each, then the loop is **done**.
  - If any comment **requires a code change**, go back to §3, address and resolve them, then **re-request again** (§4) and poll for the next review. Repeat until Copilot generates a review with 0 comments or all comments are reply-only.

---

## 5. End-to-end summary

1. Request Copilot review (§1).
2. **Poll** until Copilot submits (typically 5–7 min); do not stop early (§2).
3. Get unresolved threads; for each: address (one commit, push, reply with hash, resolve) or reply-only then resolve (§3).
4. **Re-request Copilot** (§4). You must do this after every round. **Poll again** until a *new* Copilot review appears (submitted after the re-request), then check that review.
5. If that new review has **0 comments** (or “generated no new comments”) → **done**. If all comments are reply-only → reply, resolve, **done**. If any comment requires a code change → go to step 3, then step 4 again. **Keep looping** (address → re-request → poll → check) until Copilot generates a review with 0 comments or all reply-only.

---

## 6. References

- **List/reply/resolve:** skill-gh-pr-review-comments.md (§2, §4, §5).
- **What to write in replies:** skill-performing-reviews.md (§2, §3).
- **One commit per comment, push, hash:** skill-jujutsu.md.
- **Single-pass “address unresolved” (no Copilot loop):** skill-pr-review-address-unresolved.md.
