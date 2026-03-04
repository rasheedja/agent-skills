# Skill: GitHub Copilot PR review loop — request review → address comments → repeat until no new comments

This skill describes the **Copilot-specific loop**: (1) request a review from GitHub Copilot, (2) wait for Copilot to finish and produce comments, (3) address each unresolved comment (one commit per comment, push, reply with commit hash, resolve thread), (4) re-request Copilot, (5) repeat until Copilot produces **no new comments**. Use this when you want to iterate with Copilot until it has nothing left to say.

**Prerequisites:** **[skill-gh-pr-review-comments.md](skill-gh-pr-review-comments.md)** (list comments, reply, resolve threads), **[skill-performing-reviews.md](skill-performing-reviews.md)** (evaluate comments, reply content), **[skill-jujutsu.md](skill-jujutsu.md)** (one commit per comment, push, commit hash). For a single-pass “address any unresolved comments” flow without re-requesting Copilot, use **[skill-pr-review-address-unresolved.md](skill-pr-review-address-unresolved.md)** instead.

---

## 1. Request a review from Copilot

```bash
gh pr edit <PR_NUMBER> --repo <OWNER/REPO> --add-reviewer copilot-pull-request-reviewer
```

- Use the reviewer login your repo uses (often `copilot-pull-request-reviewer`).
- This triggers Copilot to run a review on the current PR head.

---

## 2. Wait for Copilot to complete

- Copilot usually finishes within **1–2 minutes**. Poll if needed.
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

---

## 4. Re-request Copilot and check for new comments

- **Re-request** Copilot (same command as §1):
  ```bash
  gh pr edit <PR_NUMBER> --repo <OWNER/REPO> --add-reviewer copilot-pull-request-reviewer
  ```
- **Wait** again for the review to complete (§2).
- **Check for new comments:**
  - Fetch the latest Copilot review body. If it says “generated no new comments”, the loop is **done**.
  - Or fetch threads again; if there are no new unresolved threads from Copilot, the loop is **done**.
- If Copilot **did** add new comments (new unresolved threads): go back to §3, address and resolve them, then §4 again.
- If **no new comments**: stop.

---

## 5. End-to-end summary

1. Request Copilot review (§1).
2. Wait for Copilot to finish (§2).
3. Get unresolved threads; for each: address (one commit, push, reply with hash, resolve) or reply-only then resolve (§3).
4. Re-request Copilot (§4); wait; check for new comments.
5. If new comments exist → repeat from step 3. If not → done.

---

## 6. References

- **List/reply/resolve:** skill-gh-pr-review-comments.md (§2, §4, §5).
- **What to write in replies:** skill-performing-reviews.md (§2, §3).
- **One commit per comment, push, hash:** skill-jujutsu.md.
- **Single-pass “address unresolved” (no Copilot loop):** skill-pr-review-address-unresolved.md.
