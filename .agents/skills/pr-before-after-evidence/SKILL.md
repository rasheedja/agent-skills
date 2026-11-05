---
name: pr-before-after-evidence
description: "Produce and publish before/after screenshots and pixel-exact design mockups for PRs and tickets: render the real app from e2e mocks in scratch worktrees, store images on never-merged evidence branches, embed commit-pinned URLs in PR descriptions, and post mockups to Jira. Use when a UI change needs visual proof, or a ticket needs options shown to product/QA."
---

# Skill: PR before/after evidence and real-app design mockups

Reviewers and QA trust pictures of the real app. This skill covers making them reproducibly and publishing them so they never change or rot.

## 1. Render the real app, not a drawing

- **Before/after:** use two scratch worktrees, `origin/main` and the PR head (`git worktree add --detach /private/tmp/ev<N>-before origin/main`, and the same for the PR). Install dependencies in each.
- **Same data both sides:** write one throwaway Playwright spec that reuses the repo's existing e2e mocks (`page.route`) and copy it into both trees. Fields the old code doesn't know are harmless there.
- **Make the change visible:** choose data that shows it, such as non-round numbers for rounding changes, or an active state rather than an empty one.
- **Fix everything else:** viewport (1440×900 *and* a wider one such as 1728×1080 if tables wrap), `deviceScaleFactor: 2`, `locale: "en-US"`, the timezone, and a fixed clock (`page.clock`). Then the only difference is the code.
- **For behaviour fixes, show the failure:** render the old failure and the fixed behaviour under the same scenario. If a test meant to show the bug fails at setup on main, it isn't evidence: confirm it fails *for the bug's own reason*.
- **Real-environment evidence** (a deployed preview with a real wallet) is the strongest "before". Pair it with mocked "after" shots, and say which is which. See [chrome-devtools-browser-driving](../chrome-devtools-browser-driving/SKILL.md).
- Delegate the rendering to an implementor agent with a brief that lists the exact files, data and checks ([herdr-agent-orchestration](../herdr-agent-orchestration/SKILL.md)). Then **open every image yourself** before publishing.

## 2. Design mockups: build the options into the real components

When a ticket needs product to choose between UI options:

- Don't hand-draw the app in HTML and call it a mockup. Invented chrome, such as a made-up sidebar, misleads, and the operator will notice. If you must use quick HTML mocks, label each one "MOCK" and say what's approximate. Take real labels from the source (e.g. the sidebar file), not memory.
- Better: put each option on its own **local** prototype branch in a scratch worktree, using **only existing components, classes and tokens**, and render it with the e2e mocks. Report any CSS added (layout only, existing tokens) and save `git diff` per option, so the real cost of each option is visible.
- Render "today" unchanged as the baseline, and render each option's states: something present, nothing present, secondary views.
- Get the **names** right. A new section called "Waiting for approval" next to an existing "Pending approval" tab recreates the confusion the ticket complained about. Check the product's established terms before inventing new ones, and don't rename existing UI in a mockup unless the operator asks.
- Missing assets (e.g. a wallet logo that isn't on disk) are not a reason to fetch from the internet or draw your own. Use the app's own fallback, and note the difference.

## 3. Publish on a never-merged evidence branch

```bash
git fetch origin
git worktree add -b evidence/<ticket> /private/tmp/ev-<ticket> origin/main   # or reuse the existing evidence/<ticket>
mkdir -p <ticket> && cp <shots>/*.png <ticket>/
git add <ticket> && git commit --no-verify -m "docs(evidence): <ticket> <what> (<how produced>)"
git push origin evidence/<ticket>
git rev-parse HEAD     # the commit to pin
git worktree remove /private/tmp/ev-<ticket>
```

- Embed images with **commit-pinned** URLs, `https://github.com/<org>/<repo>/blob/<sha>/<ticket>/<file>.png?raw=true`, so later pushes can't change them. Use `<img src=… width="420">` in tables for side-by-side shots.
- Verify that each file exists at that commit (`gh api "repos/<o>/<r>/contents/<dir>?ref=<sha>"`). In a private repo, a plain `curl` gets a 404 and the images only render for signed-in readers with access.
- Never merge evidence branches, and don't delete them while a PR description links to them.

## 4. Put it in the PR description

- Add a **Before** section (and **After**, or **Screenshots**) above Verification. For each image, say how it was produced (environment and commit, or e2e mocks), and the mock values when they matter.
- Update the body from a file (`gh pr view N --json body -q .body > body.md`, edit it, then `gh pr edit N --body-file body.md`). Insert sections with a script rather than retyping the body.
- Mention it in the PR's Review section when the evidence changed a finding, e.g. "observed: the guard fails open (shot 15)".

## 5. Post mockups to a ticket

- Attach the images through the browser (acli can't upload attachments; see the browser-driving skill, §6). Then post a comment whose wiki markup embeds them: `!file.png|width=900!`. Jira may still show thumbnails.
- Write the comment for its reader: why the obvious request can't simply be done (with the code facts), the options with their images, and numbered questions. Mention the person asked (`[~accountid:<id>]`, taken from the ticket's reporter field), and only that person unless told otherwise.
- Use follow-up comments for corrections and re-renders so the thread shows what changed. Edit an existing comment only when the operator asks.
- Use file names that can't collide with existing attachments (`<ticket>-v2-<view>.png`).
