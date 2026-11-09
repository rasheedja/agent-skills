---
name: chrome-devtools-browser-driving
description: "Drive the operator's real Chrome profile through the Chrome DevTools MCP: find pages, screenshot and save evidence, read Jira/CDN images, upload attachments, call a site's API with the browser's session, and test dapps with wallet extensions (MetaMask, Eternl) without ever signing for the operator. Use for manual reproduction on deployed environments and any task that needs the operator's logged-in browser."
---

# Skill: Chrome DevTools browser driving — the operator's real browser, safely

The Chrome DevTools MCP controls the operator's **own** Chrome profile: their logins, their wallet extensions. Treat every click as acting on their behalf. Tools are called from codemode scripts (`tools.mcp__chrome_devtools__<name>`); use `describeTool` for exact arguments.

## 1. Pages and IDs

- `list_pages` first. Page IDs are numbers, and **every call needs `pageId`**.
- IDs change when Chrome restarts or the operator closes windows. "No page found" means re-run `list_pages`; don't guess.
- Reuse an existing tab when one is already on the site, and keep a spare tab for viewing images.
- Calls time out after about 60 s. Keep each script short, and use `wait_for({text: [...], timeout})` rather than sleeps. There are no timers in codemode, so never `await new Promise(...)` on nothing.
- If every call times out right after the MCP bridge restarted, Chrome is probably waiting for the operator to **allow remote debugging** (or a wallet popup is open). Ask them to check; don't retry in a loop.

## 2. Look before and after you act

- Prefer `take_snapshot` (an accessibility tree with `uid`s) for finding buttons, then `click({uid})`. Re-snapshot after anything that changes the page, because uids go stale.
- Use `take_screenshot` for evidence and to see what the operator sees. It returns an image block. Wrap it with `image("data:<mime>;base64,<data>")` to view it, which also saves it to a temp path (`pi-codemode-*.png`). **Copy that file** to a durable folder and `ls` it. The `filePath` option did not reliably write.
- `evaluate_script` returns page values (`location.href`, a fetch result). Its result is text that wraps JSON.
  - Its `args` are element **uids** from a snapshot, not values. To pass a label or a URL, write it into the function source (`JSON.stringify(value)` inside a template string).
  - Inside the page, timers work: a script can poll (`await new Promise(r => setTimeout(r, 300))`) until a row appears or a loading text disappears, within the call's time limit.
- Prove "nothing was sent" with `list_network_requests` before and after an action: compare counts and filter for the API path.

## 3. Wallet extensions: the operator signs, never you

- **Never** approve, sign or send transactions, and never read keys or seed phrases. Your part is getting to the prompt. The operator checks the account and confirms in the extension.
- **Stay off the browser while a wallet prompt is pending.** Calls can hang while an extension popup is open. Tell the operator what to expect ("MetaMask will ask you to connect, then to sign a sign-in message for <host>; no gas"), then wait for "done".
- Sign-in is often **two steps**: connecting, then a separate "Sign in with <wallet>" button. After the operator says "done", screenshot to see which step you're on.
- **Auto sign-in on reload:** a dapp that remembers a wallet (e.g. Eternl via CIP-30) starts its own sign request on every load or reload. If that's the wrong wallet for the test, open the wallet menu and **Disconnect** it before reloading. It's reversible, and say you did it.
- If the operator steps away, prompts expire. Check the page state, then re-trigger the prompt without reloading the page if you can.
- Geofencing or a VPN can block a site ("Access restricted"). Report it; don't try to bypass it.

## 4. Checking a deployment, read-only

To confirm a merged change is live and behaves, without changing anything:

1. **Confirm the deploy, then the build.** Check the deploy workflow for the merge commit succeeded. A tab that was open before the deploy runs the old bundle: reload with `navigate_page({type: "reload", ignoreCache: true})`, then find the entry script (`document.scripts`) and search its text, and the chunks it names, for strings only the change added (new copy, a new API path). A 403 on an old asset name is another sign the tab is stale.
2. **Know which controls write.** Read the code first. Opening a review dialog that previews server-side is usually a read; the confirm button ("Create", "Submit", "Approve") is the write. Go as far as the preview, then Back or Close.
3. **Exercise it through the page.** Filters, tabs, search, paging, deep links (reload one, then Back), redirects from old routes, each kind of detail view. Read rows with `querySelectorAll` rather than screenshots when you need many states; screenshot the ones that matter visually, including a narrower window.
4. **Measure and catch races** with `performance.getEntriesByType("resource")`: each request's start, duration and end. Slow loads show up here, and so does a late response for an old filter landing after a newer one; check what the table shows afterwards.
5. **Prove nothing was written:** `list_network_requests` with `includePreservedRequests`, and list every non-GET. Expect only the app's own background calls (telemetry, cache refreshes) and the previews you opened; name each in the report.
6. **Health:** `list_console_messages` for errors, and any non-2xx API responses. Ignore wallet-extension warnings, but say you saw them.
7. **Report** what works, issues that came with the change, and what was already like that before it (check main's history before blaming the change), plus what you couldn't test (e.g. another role).

## 5. Reproducing a bug on a deployed environment

1. Read the code path first, so you know which step fails and whether submitting writes anything.
2. Get into the reported state: same role, same wallet setup, same page. Note any difference, such as the role you actually got.
3. Act once, recording network requests around the action, and screenshot the before and after.
4. Close dialogs you opened, and leave the page as you found it.

## 6. Images behind a login (Jira, Atlassian media)

- REST attachment URLs (`/rest/api/3/attachment/content/<id>`) download rather than display, and `fetch` from the page fails across origins.
- What works: snapshot the ticket page and pull the `image "<name>" url="https://media-cdn.atlassian.com/...token=..."` URLs. Raise `width`/`height` in the URL, drop the `#fragment`, open it in the spare tab and screenshot it. The tokens expire within minutes, so re-snapshot if needed.
- When the operator sends files instead, find them by newest file in `~/Downloads`. Copy them into a scratch folder, check the type with `file`, and open them with the read tool.

## 7. Uploading files

- `upload_file({pageId, uid, filePaths})` only accepts paths **inside the MCP's workspace roots** (e.g. the current repo). Stage copies in a git-ignored folder there (check with `git check-ignore`), and delete them afterwards.
- It takes **one file per call** unless the input has `multiple`. Re-snapshot to find the upload button's uid before each file.
- Verify server-side afterwards, e.g. `acli jira workitem attachment list --key <KEY>`, or the site's own listing.

## 8. Calling a site's API with the browser's session

When a CLI can't do something but the logged-in browser can (e.g. Jira comments with attachments or mentions), call the site's REST API from inside a page on that origin:

```js
const payload = JSON.stringify({ body });
await tools.mcp__chrome_devtools__evaluate_script({pageId, function: `async () => {
  const r = await fetch("/rest/api/2/issue/KEY-1/comment", {method: "POST", credentials: "include",
    headers: {"Content-Type": "application/json", "X-Atlassian-Token": "no-check", "Accept": "application/json"},
    body: ${JSON.stringify(payload)}});
  const j = await r.json().catch(() => ({}));
  return r.status + " id=" + j.id;
}`});
```

- This publishes as the operator, so only post what they approved, with the agent sign-off their conventions require.
- Check the result (status, id) and then the rendered page. PUT to `/comment/<id>` edits a comment.

## 9. Rendering local HTML

Write HTML or CSS mockups to a scratch folder, `navigate_page` to `file:///…`, set the viewport with `resize_page`, and use `take_screenshot({fullPage: true})`. See [pr-before-after-evidence](../pr-before-after-evidence/SKILL.md) for when hand-made mocks are and aren't acceptable.
