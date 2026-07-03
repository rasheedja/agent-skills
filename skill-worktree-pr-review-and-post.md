# Skill: Reviewing someone else's PR in an isolated worktree and posting LLM-marked review comments

This skill is the end-to-end workflow for reviewing a PR **you did not author** — check it out read-only in a dedicated git worktree, optionally fan out parallel subagent reviewers, spot-check the findings yourself, and (when the user approves) post them as a **single `COMMENT`-type review with inline comments**, each clearly marked as LLM/Claude-generated and categorized.

For **what to evaluate** in a review (correctness, idioms, tests), see **[skill-conducting-code-review.md](skill-conducting-code-review.md)**. For **reply/thread/resolve mechanics** and the agent-attribution principle, see **[skill-gh-pr-review-comments.md](skill-gh-pr-review-comments.md)** and **[skill-performing-reviews.md](skill-performing-reviews.md)**. For the **review→address loop on your own PR**, see **[skill-subagent-review-main-agent-address.md](skill-subagent-review-main-agent-address.md)** (this skill is the opposite direction: you are the reviewer, not the author).

**Prerequisites:** `gh` authenticated (`gh auth status`); `jq`; the target repo cloned locally.

---

## 1. Scope it first

```bash
gh pr view <N> --repo <OWNER/REPO> --json title,body,additions,deletions,changedFiles,baseRefName,headRefName,author,isDraft
gh pr diff <N> --repo <OWNER/REPO> --name-only
```

Use size + surface area to decide effort:

- **Small / single-domain** (a few files, one language/area) → one reviewer (yourself or one subagent).
- **Large / multi-surface** (backend + frontend + infra, or many files) → **fan out parallel subagent reviewers**, one per domain (§3). Fan out per-PR too when reviewing several PRs at once.

Match depth to the ask: "quick look" → light pass; "thorough" / "security review" / audit → larger fan-out and adversarial verification.

---

## 2. Always review in a dedicated worktree — never the main checkout

Isolate the PR so you never disturb the user's working tree, and so subagents can read the full code (not just the diff).

```bash
cd <repo>
git fetch origin pull/<N>/head:pr-<N>
git worktree add /path/to/<repo>-pr-<N> pr-<N>
git merge-base origin/main pr-<N>      # record this SHA — reviewers diff against it
```

- **git only, even if the repo is jj-managed underneath** — do not run `jj` inside review worktrees.
- Use a sibling path (e.g. `../<repo>-pr-<N>`), not a nested one.
- Refresh `origin/main` first (`git fetch origin main`) if it's been a while — the merge-base should reflect current main.
- For multiple PRs, one worktree each (`<repo>-pr-<N>`); their file sets are disjoint by construction, so parallel read-only subagents can't collide.

See **[skill-opus-subagent-workspace-flow.md](skill-opus-subagent-workspace-flow.md)** for the general isolated-workspace pattern and **[skill-jujutsu.md](skill-jujutsu.md)** for jj internals.

---

## 3. Dispatch reviewer subagent(s)

Spawn `general-purpose` subagents (one per domain/PR; run in parallel when independent). Every reviewer prompt MUST include:

- **Hard constraints:** READ-ONLY — do **not** post to GitHub, push, modify files, or run any `gh` write command. Work **only** in its assigned worktree. git only (no `jj`).
- **The exact diff base:** the worktree path + merge-base SHA, e.g. `git -C <worktree> diff <merge-base> HEAD`.
- **The PR's purpose** (from the body/ticket) and a **tailored, prioritized checklist** for this specific change — not a generic one.
- **Read changed files in full plus surrounding code** needed to judge correctness (callers, the wiring, config, sibling conventions).
- **For security / auth / crypto PRs:** demand the reviewer **verify properties by tracing the actual code paths** (and running tests or a tiny harness where feasible), not assert them. Ask it to explicitly list what it **verified as holding** and what it **could not verify** (missing deps, no DB, tooling).
- **Output format:** grouped **BLOCKING / SHOULD-FIX / NIT**, each with `file:line`, what's wrong, and a concrete fix. Skeptical tone; mark plausible-but-unverified concerns as such; note things checked that were fine.

A reviewer may optionally build/typecheck/test if quick, and should report what it skipped (e.g. tests needing a DB) rather than treat infra-only failures as findings.

---

## 4. Spot-check the big claims yourself

Before reporting or posting, **verify the headline findings directly** — don't relay a subagent wholesale:

- Read the actual anchor lines a finding refers to.
- If a reviewer predicts a **test failure** or a **runtime behavior**, reproduce it in the worktree (run the test; add a throwaway spec; trace the path). Delete any temp artifacts and confirm the worktree is clean afterwards.
- **Own and correct** anything that turns out wrong or overstated. A confident "this fails CI" that's actually masked by a test race must be downgraded and explained.

---

## 5. Post findings as ONE `COMMENT` review (only after the user OKs)

Default is to report in chat. **Post to GitHub only when the user asks.** Then create a single review — not scattered comments, not an approval.

**Rules:**

- **Event `COMMENT`** — never `APPROVE`/`REQUEST_CHANGES`. You are the reviewer-of-record, not the approver.
- **Mark every comment as LLM/Claude-generated** and **categorize** it. Put the marker at the **start** so it shows in notifications, e.g. a first bold line: `🤖 **Claude (LLM) review · Should fix** — <one-line>` (categories: `Should fix`, `Nit`, `Note`). The review **summary body** gets the same disclaimer + a category legend. (See skill-performing-reviews.md §3.2 for the attribution principle; here it's a fresh review, not a thread reply.)
- **Inline comments must anchor to a line inside a diff hunk.** The `/reviews` API rejects the whole review if any comment targets a line not in the diff. **Check hunk ranges first**, and put findings on **unchanged** lines into the summary body instead.

  ```bash
  # new-side hunk ranges for a file in the PR
  gh api "/repos/<OWNER/REPO>/pulls/<N>/files?per_page=100" \
    --jq '.[] | select(.filename=="<path>") | .patch' \
    | grep -E '^@@' | sed -E 's/^.*\+([0-9]+)(,([0-9]+))? @@.*/  +\1,\3/'
  ```
  Files with **no `patch`** aren't in the PR — you can't anchor there (→ summary body). New files: every line is anchorable.

- **Build the payload with `jq`, reading each body from a file** so markdown/quotes/newlines escape correctly (never hand-write the JSON). `commit_id` = the PR **head SHA**.

  ```bash
  jq -n --arg commit "<HEAD_SHA>" \
    --rawfile body summary.md --rawfile c1 c1.md --rawfile c2 c2.md \
    '{commit_id:$commit, event:"COMMENT", body:$body, comments:[
       {path:"path/to/a.go", line:78,  side:"RIGHT", body:$c1},
       {path:"path/to/b.ts", line:186, side:"RIGHT", body:$c2}
     ]}' > payload.json

  gh api --method POST /repos/<OWNER/REPO>/pulls/<N>/reviews --input payload.json \
    --jq '{id, state, html_url}'
  ```
  (Multi-line anchors: add `start_line` alongside `line`. `side:"RIGHT"` = the new version of the file.)

- **Verify the inline comments landed** (a review can post with fewer comments than intended if some were dropped):

  ```bash
  RID=<review id from the post>
  gh api "/repos/<OWNER/REPO>/pulls/<N>/comments?per_page=100" \
    --jq ".[] | select(.pull_request_review_id==$RID) | \"\(.path):\(.line)\""
  ```

**Summary body contents:** the LLM disclaimer, the category legend, the verdict, the **security/behavior properties you verified as holding**, and an explicit **"not verified (tooling)"** note. Fold non-anchorable nits (unchanged-line findings) here.

---

## 6. Branch protection & safety

- Posting a review is fine, but **never push to or merge `main`**, never `git push --force` (see the target repo's CLAUDE.md / branch rules).
- If your `gh` account isn't the PR author, the comment is still attributed to your account — the explicit "generated by Claude (LLM)" marker is what makes authorship honest. Keep it on every comment.
- Reviewing/posting is outward-facing: confirm with the user before the first post.

---

## 7. Clean up when asked

```bash
git worktree remove --force /path/to/<repo>-pr-<N>
git branch -D pr-<N>
```

- `--force` is safe for throwaway review worktrees (even ones where you ran `bun install` / downloaded browsers).
- Remove **only your review worktrees** — leave the user's feature (`WTB-*`, `feature/*`) and Cursor/agent worktrees untouched (`git worktree list` to confirm).
- `/tmp` scratch (payload/body files) is harmless to leave.

---

## 8. Quick reference

| Step | Action |
|------|--------|
| Scope | `gh pr view/diff … --name-only`; single reviewer vs parallel fan-out by domain |
| Isolate | `git fetch origin pull/<N>/head:pr-<N>` → `git worktree add ../<repo>-pr-<N> pr-<N>`; record `merge-base`; git-only |
| Review | subagent(s): read-only, diff vs merge-base, tailored checklist, verify-not-assert, BLOCKING/SHOULD-FIX/NIT + `file:line` |
| Spot-check | reproduce headline claims yourself; correct overstatements |
| Post | one `COMMENT` review via `jq` + `POST /pulls/<N>/reviews`; LLM-marked + categorized; anchor to diff hunks; verify landed |
| Never | `APPROVE`/`REQUEST_CHANGES`; push/merge `main`; post without user OK |
| Clean up | `git worktree remove --force` + `git branch -D pr-<N>`; leave the user's own worktrees |

---

## 9. Appendix: reusable reviewer-subagent prompt

```
Review PR <OWNER/REPO>#<N>. READ-ONLY — do NOT post to GitHub, push, modify files, or run any `gh` write command.

Work ONLY in this worktree: <WORKTREE_PATH>  (git only — do NOT run jj).
Diff against merge-base <MERGE_BASE_SHA>:
  git -C <WORKTREE_PATH> diff <MERGE_BASE_SHA> HEAD -- <optional path scope>
Read any AGENTS.md/CLAUDE.md/README in the worktree for conventions first.

PURPOSE: <one-paragraph summary of what the PR does and why>.

Read these files in full + surrounding code needed to judge correctness: <list>.

Scrutinise (priority order): <tailored, specific checklist>.
For security/auth/crypto: VERIFY properties by tracing code paths (run tests / a small
harness if feasible) — do not assert. List what you verified as holding and what you
could NOT verify (deps/DB/tooling).

Optionally build/typecheck/test if quick; report what you skipped (don't treat infra-only
failures as findings).

Return prioritised BLOCKING / SHOULD-FIX / NIT, each with file:line, what's wrong, and a
concrete fix. Be skeptical; mark unverified concerns as such; note things you checked that
were fine.
```
