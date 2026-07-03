# Skill: GitHub Copilot PR review loop — request review → address comments → repeat until no new comments

This skill describes the **Copilot-specific loop**: (1) request a review from GitHub Copilot, (2) wait for Copilot to finish and produce comments, (3) address each unresolved comment (one commit per comment, push, reply with commit hash, resolve thread), (4) re-request Copilot, (5) repeat until Copilot produces **no new comments**. Use this when you want to iterate with Copilot until it has nothing left to say.

**Autonomous execution:** When running this loop, **do not wait for human interaction**. After requesting a review, poll until Copilot completes (e.g. every 60–90 seconds, 5–7 minutes typical, timeout e.g. 30 minutes). When the review is in, address all new unresolved comments, then **you must re-request Copilot** and poll for the *next* review. **Keep re-requesting** after each round of fixes until Copilot’s next review has **0 comments** (or says “generated no new comments”), or until all of its comments are reply-only (no code change required). Do not stop after addressing comments without re-requesting; the loop is not done until Copilot has run again and produced zero comments or only reply-only comments.

**Prerequisites:** **[skill-gh-pr-review-comments.md](skill-gh-pr-review-comments.md)** (list comments, reply, resolve threads), **[skill-performing-reviews.md](skill-performing-reviews.md)** (evaluate comments, reply content), **[skill-jujutsu.md](skill-jujutsu.md)** (one commit per comment, push, commit hash). For a single-pass “address any unresolved comments” flow without re-requesting Copilot, use **[skill-pr-review-address-unresolved.md](skill-pr-review-address-unresolved.md)** instead.

---

## 1. Request a review from Copilot

Copilot is a **Bot**, not a User, so the usual reviewer-by-login paths don't work for it:

- ❌ `gh pr edit ... --add-reviewer copilot-pull-request-reviewer` — fails (`Could not resolve user with login 'copilot'`); the underlying GraphQL `requestReviewsByLogin` only accepts users.
- ❌ `POST /repos/{owner}/{repo}/pulls/{pr}/requested_reviewers` with `{"reviewers":["Copilot"]}` — returns 201 but **silently dedups**: no `review_requested` event, `requested_reviewers: []`. Copilot is never notified.

✅ Use the GraphQL `requestReviews` mutation with the `botIds` field:

```bash
# 1. Look up Copilot's bot node id (one-off — same id on all PRs):
gh api graphql -f query='{repository(owner:"<OWNER>",name:"<REPO>"){pullRequest(number:<ANY_PR_WITH_COPILOT_REVIEW>){reviews(first:5){nodes{author{__typename login ... on Bot{id}}}}}}}'
# Look for {"__typename":"Bot","login":"copilot-pull-request-reviewer","id":"BOT_..."}.

# 2. Request the review:
PR_ID=$(gh api graphql -f query='{repository(owner:"<OWNER>",name:"<REPO>"){pullRequest(number:<PR>){id}}}' --jq '.data.repository.pullRequest.id')
gh api graphql -f query='
mutation($prId:ID!, $botIds:[ID!]!){
  requestReviews(input:{pullRequestId:$prId, botIds:$botIds, union:true}){
    pullRequest{ reviewRequests(first:5){ nodes{ requestedReviewer{ ... on Bot{login} } } } }
  }
}' -F prId=$PR_ID -F botIds=<COPILOT_BOT_ID>
```

- A successful call shows `copilot-pull-request-reviewer` in `reviewRequests.nodes`.
- `union: true` keeps any other already-requested reviewers in place.
- This triggers Copilot to run a review on the current PR head.

---

## 2. Wait for Copilot to complete (poll; no human interaction)

- Copilot usually finishes within **5–7 minutes**. **Poll automatically** (e.g. every 60–90 seconds); do not stop and ask the user to check. Use a timeout (e.g. 30 minutes) if Copilot does not submit.

### 2.1 Convergence signal — poll *unresolved review threads*, not `/pulls/N/reviews`

**Use the GraphQL `reviewThreads` connection filtered to `isResolved == false` as the *single* signal that Copilot has new feedback.** A monitor that polls only `/pulls/N/reviews` for new submission timestamps is unreliable and will miss comments — see the trap below.

```bash
# Authoritative "is there feedback I haven't dealt with?" query:
gh api graphql -f query='{repository(owner:"<OWNER>",name:"<REPO>"){pullRequest(number:<PR>){reviewThreads(first:100){nodes{isResolved}}}}}' \
  --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)] | length'
# 0 → no work to do. >0 → new (or still-open) threads to address.
```

**Why not `/pulls/N/reviews`:** that endpoint only lists `PullRequestReview` objects (top-level *submissions*). Copilot frequently leaves individual review comments via the `/pulls/N/comments` path **without** ever wrapping them in a submitted review — so `/reviews` stays frozen at the last formally-submitted review while real, unresolved threads pile up. A monitor anchored on `submitted_at` reports "no new review" while the bot has clearly left feedback. Two distinct sessions burned 30+ min each on this trap before the user had to point at the unresolved comments directly.

**Two more pitfalls:**
- **Pagination cap:** `reviewThreads(first: 50)` silently truncates on long-running review loops (it's easy to accumulate 50+ threads across many rounds, mostly resolved). Use `first: 100` and paginate with `pageInfo.hasNextPage` if you expect more. An undercount looks identical to "all clean."
- **`gh --jq` doesn't take `--arg`:** `gh api ... --jq --arg foo bar '.[]'` is silently malformed — `--jq` only accepts a single jq expression argument and `--arg` is ignored, producing empty output. If you need to inject a shell value, interpolate it into the jq expression with shell quoting, or pipe the raw API response through standalone `jq -n --arg foo bar '...'`.

### 2.2 Optional secondary checks

These are diagnostics, not the convergence signal. Don't drive the loop off them.

```bash
# Latest Copilot submission timestamp (informational; can stay frozen during active rounds):
gh api repos/<OWNER>/<REPO>/pulls/<PR>/reviews --jq '.[] | select(.user.login == "copilot-pull-request-reviewer[bot]") | {id, submitted_at}'

# Latest review body — Copilot sometimes says "generated no new comments" here when it has nothing to add:
gh api "repos/<OWNER>/<REPO>/pulls/<PR>/reviews/<REVIEW_ID>" --jq '.body'
```

---

## 3. Address and resolve each unresolved comment

- Work only on **unresolved** threads (see skill-gh-pr-review-comments.md §5 for the GraphQL query; filter `isResolved === false`).
- For **each** unresolved comment:
  - **If you change code:** One commit per comment — git (default): edit → `git commit -m "fix: ..."` → `git push` → get hash (`git rev-parse HEAD`) → reply in thread (include “Comment left by Cursor”, what you changed, and the **commit hash**) → resolve the thread (GraphQL `resolveReviewThread`). (jj alternative: `jj new <branch> -m "fix: ..."` → edit → `jj bookmark set <branch> -r @` → **`jj new @`** → `jj git push --branch <branch>` → hash via `jj log -r <branch> -T 'commit_id' -n 1`; see skill-jujutsu.md.) See skill-gh-pr-review-comments.md.
  - **If you only reply (no code change):** Reply in thread with your rationale, then resolve the thread.
- When all current unresolved threads are addressed and resolved, continue to §4.
- **If posting a reply returns 422** (e.g. “user_id can only have one pending review per pull request”): your user has a pending review on this PR. Delete or submit that review (see skill-gh-pr-review-comments.md §8), then retry the reply.

---

## 4. Re-request Copilot (required after every round), then poll for the next review

- **You must re-request** after addressing comments. Do not skip this step. Use the same GraphQL `requestReviews` + `botIds` call from §1 — `gh pr edit --add-reviewer` and the REST `requested_reviewers` POST do not work for the Copilot bot (see §1).
- **Poll on the unresolved-thread count from §2.1**, not on `submittedAt`. Record the time when you re-requested; from that point, watch `[.nodes[] | select(.isResolved == false)] | length`:
  - **Goes from 0 → N (any N>0)** within the timeout (typically 5–7 min): there's new feedback. Go to §3, address it, then re-request again here.
  - **Stays at 0 for ≥30 min** after re-request: treat as **converged**. Don't keep waiting on `submittedAt` — Copilot can decline to leave a fresh review submission entirely when there's nothing to add (no "generated no new comments" body, no `submittedAt` bump). The unresolved count being 0 across a long quiet window is the only reliable signal that the loop is done.
- For diagnostics only, you can also peek at the latest review body — if it says **"generated no new comments"**, the loop is done. But don't gate the loop on it: a silent (no review) and a "no new comments" review look the same on the unresolved-count signal, which is what matters.

---

## 5. End-to-end summary

1. Request Copilot review (§1).
2. **Poll the unresolved-thread count** (§2.1) until it goes >0 — that's Copilot's feedback landing. Don't poll `/reviews` `submittedAt` as the convergence signal; it misses individual comments left without a wrapping review submission.
3. Get unresolved threads; for each: address (one commit, push, reply with hash, resolve) or reply-only then resolve (§3).
4. **Re-request Copilot** (§4). You must do this after every round. **Poll the unresolved-thread count again** (§4): if it goes >0, go to step 3; if it stays at 0 for ≥30 min, **done**.
5. **Keep looping** (address → re-request → poll → check) until the unresolved-thread count stays at 0 across a 30-min quiet window after a re-request, or every new comment turns out to be reply-only (no code change).

---

## 6. References

- **List/reply/resolve:** skill-gh-pr-review-comments.md (§2, §4, §5).
- **What to write in replies:** skill-performing-reviews.md (§2, §3).
- **One commit per comment, push, hash:** skill-jujutsu.md.
- **Single-pass “address unresolved” (no Copilot loop):** skill-pr-review-address-unresolved.md.
